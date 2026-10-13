"""Motor de Simulación Estocástica (Monte Carlo) — Fase 24.

Implementa el algoritmo de Movimiento Browniano Geométrico (GBM) para
proyectar escenarios futuros de precios de un activo financiero a partir
de su serie temporal histórica (etf_history o array externo).

Las trayectorias se agregan en tres bandas percentilares:
  - P10  → escenario pesimista
  - P50  → escenario base (mediana)
  - P90  → escenario optimista
"""
from __future__ import annotations

import math
from typing import Dict, List

import numpy as np


# ---------------------------------------------------------------------------
# Constantes por defecto
# ---------------------------------------------------------------------------
DEFAULT_SIMULATIONS: int = 5_000        # Número de trayectorias GBM
DEFAULT_HORIZON_DAYS: int = 252 * 5     # 5 años de días hábiles (~1 260 días)
TRADING_DAYS_PER_YEAR: int = 252
DAYS_PER_MONTH: int = 21               # Días hábiles aproximados por mes


class MonteCarloSimulator:
    """Simulador Monte Carlo basado en Movimiento Browniano Geométrico.

    Parameters
    ----------
    n_simulations : int
        Número de trayectorias estocásticas a generar (por defecto 5 000).
    horizon_days : int
        Número de días hábiles a proyectar (por defecto 252 * 5 = 1 260).
    random_seed : int | None
        Semilla opcional para reproducibilidad de los experimentos.
    """

    def __init__(
        self,
        n_simulations: int = DEFAULT_SIMULATIONS,
        horizon_days: int = DEFAULT_HORIZON_DAYS,
        random_seed: int | None = None,
    ) -> None:
        self.n_simulations = max(1, n_simulations)
        self.horizon_days = max(1, horizon_days)
        self._rng = np.random.default_rng(random_seed)

    # ------------------------------------------------------------------
    # Estadísticas de la serie histórica
    # ------------------------------------------------------------------

    def compute_historical_stats(self, price_series: List[float]) -> Dict[str, float]:
        """Calcula el retorno diario (drift) y la volatilidad diaria de una
        serie de precios históricos.

        Parameters
        ----------
        price_series : list[float]
            Array de precios históricos ordenados cronológicamente
            (precio más antiguo primero).  Mínimo 2 elementos.

        Returns
        -------
        dict con claves:
            - ``mean_daily_return``  : retorno medio diario (µ)
            - ``std_daily_return``   : desviación estándar diaria (σ)
            - ``annualized_return``  : retorno anualizado
            - ``annualized_vol``     : volatilidad anualizada

        Raises
        ------
        ValueError
            Si la serie tiene menos de 2 precios o contiene valores no positivos.
        """
        prices = np.asarray(price_series, dtype=np.float64)

        if prices.ndim != 1 or len(prices) < 2:
            raise ValueError(
                "price_series debe ser una lista unidimensional con al menos 2 precios."
            )
        if np.any(prices <= 0):
            raise ValueError("Todos los precios deben ser estrictamente positivos.")

        # Retornos logarítmicos diarios: ln(P_t / P_{t-1})
        log_returns: np.ndarray = np.log(prices[1:] / prices[:-1])

        mean_daily: float = float(np.mean(log_returns))
        std_daily: float = float(np.std(log_returns, ddof=1))

        return {
            "mean_daily_return": mean_daily,
            "std_daily_return": std_daily,
            "annualized_return": mean_daily * TRADING_DAYS_PER_YEAR,
            "annualized_vol": std_daily * math.sqrt(TRADING_DAYS_PER_YEAR),
        }

    # ------------------------------------------------------------------
    # Simulación GBM principal
    # ------------------------------------------------------------------

    def run_simulation(
        self,
        price_series: List[float],
        initial_investment: float = 1_000.0,
        monthly_contribution: float = 0.0,
    ) -> Dict[str, List[float]]:
        """Ejecuta la simulación Monte Carlo mediante GBM y devuelve las
        bandas percentilares P10, P50 y P90 de la evolución del valor de
        la cartera a lo largo del horizonte definido.

        Parameters
        ----------
        price_series : list[float]
            Serie temporal de precios históricos (mínimo 2 elementos).
        initial_investment : float
            Capital inicial a proyectar en unidades monetarias (≥ 0).
        monthly_contribution : float
            Aportación mensual adicional en unidades monetarias (≥ 0).
            Se convierte a contribución diaria internamente usando
            DAYS_PER_MONTH como aproximación de días hábiles mensuales.

        Returns
        -------
        dict con claves:
            - ``p10``  : lista de ``horizon_days + 1`` valores (día 0 … día T)
            - ``p50``  : ídem
            - ``p90``  : ídem
            - ``days`` : lista de índices de día [0, 1, …, T]
            - ``stats``: diccionario de parámetros estadísticos

        Raises
        ------
        ValueError
            Propagado desde ``compute_historical_stats`` si los datos son inválidos.
        """
        if initial_investment < 0:
            raise ValueError("initial_investment debe ser ≥ 0.")
        if monthly_contribution < 0:
            raise ValueError("monthly_contribution debe ser ≥ 0.")

        stats = self.compute_historical_stats(price_series)
        mu: float = stats["mean_daily_return"]
        sigma: float = stats["std_daily_return"]

        # Precio de referencia = último precio de la serie
        S0: float = float(price_series[-1])
        if S0 <= 0:
            raise ValueError("El último precio de la serie debe ser > 0.")

        T: int = self.horizon_days
        N: int = self.n_simulations

        # Parámetros GBM por paso temporal diario
        # S_{t+1} = S_t * exp((µ - σ²/2) * dt + σ * sqrt(dt) * Z)
        # Con dt = 1 (día hábil = unidad de tiempo)
        drift_term: float = mu - 0.5 * sigma ** 2
        daily_contribution: float = monthly_contribution / DAYS_PER_MONTH

        # Matriz de choques aleatorios: forma (T, N)
        z: np.ndarray = self._rng.standard_normal((T, N))

        # Inicializar trayectorias de precio como array (T+1, N)
        price_paths = np.empty((T + 1, N), dtype=np.float64)
        price_paths[0] = S0

        for t in range(1, T + 1):
            price_paths[t] = price_paths[t - 1] * np.exp(drift_term + sigma * z[t - 1])

        # Convertir precio a valor de cartera aplicando ratio de crecimiento
        # Valor_t = (investment / S0) * precio_t  +  contribuciones acumuladas
        # El rendimiento diario de las contribuciones se calcula reinvirtiendo:
        # cada contribución diaria adquiere ratio_t / ratio_contribution_day participaciones.

        ratio_paths: np.ndarray = price_paths / S0  # Retorno normalizado (T+1, N)

        # Valor de la inversión inicial proyectado
        portfolio_paths: np.ndarray = initial_investment * ratio_paths  # (T+1, N)

        # Añadir el efecto de las aportaciones mensuales (diarias hábiles)
        if daily_contribution > 0:
            for t in range(1, T + 1):
                # La contribución del día t crece desde t hasta T según el ratio relativo
                growth_factor: np.ndarray = price_paths[T] / price_paths[t]
                # Valor en T de la aportación del día t
                # (solo aportamos; calculamos su valor actual en cada punto t)
                # Acumulamos la contribución aplicando el mismo ratio forward
                # Estrategia simplificada: la aportación en t vale contribution * ratio_t
                portfolio_paths[t] += daily_contribution * t * ratio_paths[t]

        # Percentiles a lo largo del eje de simulaciones (eje 1 → columnas)
        p10: np.ndarray = np.percentile(portfolio_paths, 10, axis=1)
        p50: np.ndarray = np.percentile(portfolio_paths, 50, axis=1)
        p90: np.ndarray = np.percentile(portfolio_paths, 90, axis=1)

        return {
            "p10": [round(float(v), 2) for v in p10],
            "p50": [round(float(v), 2) for v in p50],
            "p90": [round(float(v), 2) for v in p90],
            "days": list(range(T + 1)),
            "stats": stats,
        }
