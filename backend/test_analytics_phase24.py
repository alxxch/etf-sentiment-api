"""Pruebas Unitarias — Fase 24: Motor de Simulación Estocástica (Monte Carlo).

Valida:
  1. Estadísticas matemáticas (drift, volatilidad) calculadas a partir de
     series de precios mock conocidas.
  2. Estructura de la respuesta del motor (GBM): claves requeridas, longitudes
     de arrays y que P90 > P10 al final de la simulación.
  3. Endpoint HTTP POST /api/v1/analytics/montecarlo: código de estado, esquema
     JSON y relación P90 > P10.

Ejecutar con:
    pytest backend/test_analytics_phase24.py -v
"""
from __future__ import annotations

import math
import unittest
from typing import List
from unittest.mock import MagicMock, patch

import numpy as np
import pytest
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Import del motor matemático
# ---------------------------------------------------------------------------
from services.montecarlo_engine import (
    DEFAULT_HORIZON_DAYS,
    DEFAULT_SIMULATIONS,
    MonteCarloSimulator,
    TRADING_DAYS_PER_YEAR,
)


# ===========================================================================
# Fixtures / helpers compartidos
# ===========================================================================

def _make_trending_prices(
    start: float = 100.0,
    n: int = 252,
    daily_drift: float = 0.0003,
    daily_vol: float = 0.012,
    seed: int = 7,
) -> List[float]:
    """Genera una serie de precios sintéticos vía GBM con semilla fija."""
    rng = np.random.default_rng(seed)
    prices = [start]
    for _ in range(n - 1):
        shock = rng.standard_normal()
        prices.append(prices[-1] * math.exp(daily_drift - 0.5 * daily_vol**2 + daily_vol * shock))
    return prices


# ===========================================================================
# 1. Tests de estadísticas matemáticas
# ===========================================================================

class TestHistoricalStats(unittest.TestCase):
    """Valida compute_historical_stats con series controladas."""

    def setUp(self) -> None:
        self.sim = MonteCarloSimulator(n_simulations=500, horizon_days=50, random_seed=42)

    # --- Caso 1: serie con retornos constantes ---------------------------------
    def test_constant_return_series(self) -> None:
        """Con precios en progresión geométrica pura el std debe ser ~0."""
        daily_r = 0.001
        prices = [100.0 * math.exp(daily_r * t) for t in range(100)]
        stats = self.sim.compute_historical_stats(prices)

        # Retorno medio ≈ daily_r (tolerancia numérica)
        self.assertAlmostEqual(stats["mean_daily_return"], daily_r, places=6)
        # Volatilidad ≈ 0 (serie perfectamente determinista)
        self.assertAlmostEqual(stats["std_daily_return"], 0.0, places=6)

    # --- Caso 2: serie con retorno nulo y volatilidad conocida ---------------
    def test_zero_mean_known_vol(self) -> None:
        """Serie generada con drift=0 y vol=0.01 → std_daily ≈ 0.01."""
        rng = np.random.default_rng(99)
        vol = 0.01
        log_returns = rng.normal(0, vol, size=2000)
        prices = [100.0]
        for r in log_returns:
            prices.append(prices[-1] * math.exp(r))

        stats = self.sim.compute_historical_stats(prices)

        # Con N=2001 la estimación debe estar dentro de ±20% del valor real
        self.assertAlmostEqual(stats["std_daily_return"], vol, delta=vol * 0.2)

    # --- Caso 3: anualización correcta ----------------------------------------
    def test_annualized_values(self) -> None:
        """Verifica que los valores anualizados son consistentes con los diarios."""
        prices = _make_trending_prices()
        stats = self.sim.compute_historical_stats(prices)

        expected_ann_return = stats["mean_daily_return"] * TRADING_DAYS_PER_YEAR
        expected_ann_vol = stats["std_daily_return"] * math.sqrt(TRADING_DAYS_PER_YEAR)

        self.assertAlmostEqual(stats["annualized_return"], expected_ann_return, places=10)
        self.assertAlmostEqual(stats["annualized_vol"], expected_ann_vol, places=10)

    # --- Caso 4: validación de inputs incorrectos --------------------------------
    def test_raises_on_short_series(self) -> None:
        with self.assertRaises(ValueError):
            self.sim.compute_historical_stats([100.0])

    def test_raises_on_negative_prices(self) -> None:
        with self.assertRaises(ValueError):
            self.sim.compute_historical_stats([100.0, -5.0, 110.0])

    def test_raises_on_empty_series(self) -> None:
        with self.assertRaises(ValueError):
            self.sim.compute_historical_stats([])


# ===========================================================================
# 2. Tests del motor GBM (run_simulation)
# ===========================================================================

class TestMonteCarloSimulator(unittest.TestCase):
    """Valida la estructura y propiedades estadísticas de la simulación GBM."""

    def setUp(self) -> None:
        self.prices = _make_trending_prices(n=252, seed=42)
        self.horizon = 252        # 1 año
        self.n_sims = 2_000
        self.sim = MonteCarloSimulator(
            n_simulations=self.n_sims,
            horizon_days=self.horizon,
            random_seed=42,
        )

    # --- Caso 1: estructura del resultado ------------------------------------
    def test_result_keys_present(self) -> None:
        """El resultado debe contener p10, p50, p90, days y stats."""
        result = self.sim.run_simulation(self.prices, initial_investment=1_000.0)
        for key in ("p10", "p50", "p90", "days", "stats"):
            self.assertIn(key, result, msg=f"Clave '{key}' ausente en el resultado.")

    # --- Caso 2: longitud de los arrays ----------------------------------------
    def test_array_lengths(self) -> None:
        """Los arrays deben tener horizon_days + 1 elementos (incluido el día 0)."""
        result = self.sim.run_simulation(self.prices)
        expected_len = self.horizon + 1
        self.assertEqual(len(result["p10"]), expected_len)
        self.assertEqual(len(result["p50"]), expected_len)
        self.assertEqual(len(result["p90"]), expected_len)
        self.assertEqual(len(result["days"]), expected_len)

    # --- Caso 3: días consecutivos --------------------------------------------
    def test_days_sequence(self) -> None:
        """El array 'days' debe ser [0, 1, ..., horizon_days]."""
        result = self.sim.run_simulation(self.prices)
        self.assertEqual(result["days"], list(range(self.horizon + 1)))

    # --- Caso 4: P90 > P10 en el día final ------------------------------------
    def test_p90_greater_than_p10_at_final_day(self) -> None:
        """P90 debe ser estrictamente mayor que P10 en el último día proyectado."""
        result = self.sim.run_simulation(self.prices, initial_investment=10_000.0)
        self.assertGreater(result["p90"][-1], result["p10"][-1])

    # --- Caso 5: P50 entre P10 y P90 ----------------------------------------
    def test_p50_between_p10_and_p90(self) -> None:
        """La mediana debe estar siempre entre el P10 y el P90."""
        result = self.sim.run_simulation(self.prices, initial_investment=5_000.0)
        for day_idx in range(len(result["days"])):
            self.assertLessEqual(
                result["p10"][day_idx],
                result["p50"][day_idx],
                msg=f"P10 > P50 en el día {day_idx}",
            )
            self.assertLessEqual(
                result["p50"][day_idx],
                result["p90"][day_idx],
                msg=f"P50 > P90 en el día {day_idx}",
            )

    # --- Caso 6: valor inicial = inversión en el día 0 ----------------------
    def test_initial_day_equals_investment(self) -> None:
        """El día 0 de todas las bandas debe ser igual a la inversión inicial."""
        investment = 8_000.0
        result = self.sim.run_simulation(self.prices, initial_investment=investment)
        self.assertAlmostEqual(result["p10"][0], investment, places=1)
        self.assertAlmostEqual(result["p50"][0], investment, places=1)
        self.assertAlmostEqual(result["p90"][0], investment, places=1)

    # --- Caso 7: aportación mensual amplía el rango -------------------------
    def test_monthly_contribution_increases_final_values(self) -> None:
        """Con aportación mensual positiva, el P50 final debe ser mayor que sin ella."""
        result_no_contrib = self.sim.run_simulation(
            self.prices, initial_investment=5_000.0, monthly_contribution=0.0
        )
        sim2 = MonteCarloSimulator(
            n_simulations=self.n_sims, horizon_days=self.horizon, random_seed=42
        )
        result_with_contrib = sim2.run_simulation(
            self.prices, initial_investment=5_000.0, monthly_contribution=200.0
        )
        self.assertGreater(result_with_contrib["p50"][-1], result_no_contrib["p50"][-1])

    # --- Caso 8: validación de inputs negativos ------------------------------
    def test_raises_on_negative_investment(self) -> None:
        with self.assertRaises(ValueError):
            self.sim.run_simulation(self.prices, initial_investment=-1.0)

    def test_raises_on_negative_contribution(self) -> None:
        with self.assertRaises(ValueError):
            self.sim.run_simulation(self.prices, monthly_contribution=-50.0)


# ===========================================================================
# 3. Tests del endpoint HTTP
# ===========================================================================

class TestMonteCarloEndpoint(unittest.TestCase):
    """Valida el endpoint POST /api/v1/analytics/montecarlo."""

    def setUp(self) -> None:
        """Construye un TestClient con una DB mockeada y sin historia real."""
        from main import app

        # Mock de la sesión de base de datos: devuelve lista vacía (usa sintético)
        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.all.return_value = []
        mock_db.query.return_value = mock_query

        from db import get_db

        app.dependency_overrides[get_db] = lambda: mock_db
        self.client = TestClient(app, raise_server_exceptions=True)
        self._app = app

    def tearDown(self) -> None:
        self._app.dependency_overrides.clear()

    # --- Caso 1: respuesta HTTP 200 OK ----------------------------------------
    def test_endpoint_returns_200(self) -> None:
        """El endpoint debe responder con HTTP 200 OK."""
        payload = {
            "ticker": "VWCE.DE",
            "horizon_days": 252,
            "n_simulations": 500,
            "initial_investment": 10000.0,
            "monthly_contribution": 200.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 200, msg=response.text)

    # --- Caso 2: estructura del JSON de respuesta ----------------------------
    def test_response_schema_keys(self) -> None:
        """La respuesta debe contener todas las claves definidas en MonteCarloResponse."""
        payload = {
            "ticker": "VWCE.DE",
            "horizon_days": 100,
            "n_simulations": 300,
            "initial_investment": 5000.0,
            "monthly_contribution": 0.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        required_keys = [
            "ticker", "horizon_days", "n_simulations", "initial_investment",
            "monthly_contribution", "p10", "p50", "p90", "days",
            "mean_daily_return", "std_daily_return", "annualized_return", "annualized_vol",
            "final_p10", "final_p50", "final_p90",
        ]
        for key in required_keys:
            self.assertIn(key, data, msg=f"Clave '{key}' ausente en la respuesta JSON.")

    # --- Caso 3: P90 > P10 al final -------------------------------------------
    def test_p90_greater_than_p10_in_response(self) -> None:
        """En la respuesta HTTP, el valor final P90 debe ser mayor que P10."""
        payload = {
            "ticker": "EUNL.DE",
            "horizon_days": 252,
            "n_simulations": 1000,
            "initial_investment": 10000.0,
            "monthly_contribution": 100.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertGreater(
            data["final_p90"],
            data["final_p10"],
            msg="final_p90 debe ser > final_p10 en la respuesta.",
        )

    # --- Caso 4: longitud correcta de los arrays ---------------------------------
    def test_array_length_matches_horizon(self) -> None:
        """Los arrays p10, p50, p90 y days deben tener horizon_days + 1 elementos."""
        horizon = 50
        payload = {
            "ticker": "VWCE.DE",
            "horizon_days": horizon,
            "n_simulations": 200,
            "initial_investment": 1000.0,
            "monthly_contribution": 0.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        expected_len = horizon + 1
        self.assertEqual(len(data["p10"]), expected_len)
        self.assertEqual(len(data["p50"]), expected_len)
        self.assertEqual(len(data["p90"]), expected_len)
        self.assertEqual(len(data["days"]), expected_len)

    # --- Caso 5: ticker en el response coincide con el request ---------------
    def test_ticker_echo(self) -> None:
        """El campo 'ticker' en la respuesta debe coincidir con el enviado."""
        payload = {
            "ticker": "8PSG.DE",
            "horizon_days": 30,
            "n_simulations": 200,
            "initial_investment": 2000.0,
            "monthly_contribution": 50.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["ticker"], "8PSG.DE")

    # --- Caso 6: parámetros de validación Pydantic ----------------------------
    def test_invalid_horizon_raises_422(self) -> None:
        """Un horizonte de 0 días debe generar un error 422 (validación Pydantic)."""
        payload = {
            "ticker": "VWCE.DE",
            "horizon_days": 0,
            "n_simulations": 500,
            "initial_investment": 1000.0,
            "monthly_contribution": 0.0,
        }
        response = self.client.post("/api/v1/analytics/montecarlo", json=payload)
        self.assertEqual(response.status_code, 422)


# ===========================================================================
# Punto de entrada para ejecución directa
# ===========================================================================

if __name__ == "__main__":
    unittest.main(verbosity=2)
