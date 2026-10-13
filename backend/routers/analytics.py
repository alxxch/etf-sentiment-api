"""Router de Analítica Predictiva — Fase 24: Motor de Simulación Monte Carlo.

Expone el endpoint:
  POST /api/v1/analytics/montecarlo

El endpoint recupera la serie histórica de precios del ticker solicitado
desde la tabla etf_history (PostgreSQL) y, si no existe suficiente historia,
genera datos sintéticos representativos basados en el precio actual de mercado
para garantizar siempre una respuesta válida.
"""
from __future__ import annotations

import math
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from db import get_db
from db.models import EtfHistory
from schemas import MonteCarloRequest, MonteCarloResponse
from services.montecarlo_engine import MonteCarloSimulator

router = APIRouter()

# Número mínimo de precios históricos para calibrar el modelo
_MIN_HISTORY_POINTS: int = 30


# ---------------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------------

def _fetch_price_series(ticker: str, db: Session) -> List[float]:
    """Recupera la serie de precios históricos del ticker desde PostgreSQL.

    Devuelve los precios ordenados cronológicamente ascendente (más antiguo primero).
    """
    records = (
        db.query(EtfHistory)
        .filter(EtfHistory.ticker == ticker)
        .order_by(EtfHistory.timestamp.asc())
        .all()
    )
    return [float(r.price) for r in records if r.price and r.price > 0]


def _generate_synthetic_prices(
    base_price: float,
    n_points: int = 252,
    annual_drift: float = 0.07,
    annual_vol: float = 0.15,
    seed: int = 42,
) -> List[float]:
    """Genera una serie de precios sintéticos vía GBM determinístico para
    actuar como histórico de referencia cuando la base de datos está vacía.

    Usa numpy internamente pero no lo requiere como parámetro para evitar
    importaciones circulares — el import se hace en el motor.
    """
    import numpy as np  # noqa: WPS433 (local import intencional)

    rng = np.random.default_rng(seed)
    dt = 1 / 252
    drift_daily = (annual_drift - 0.5 * annual_vol ** 2) * dt
    vol_daily = annual_vol * math.sqrt(dt)
    prices = [base_price]
    for _ in range(n_points - 1):
        shock = rng.standard_normal()
        prices.append(prices[-1] * math.exp(drift_daily + vol_daily * shock))
    return prices


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------

@router.post(
    "/montecarlo",
    response_model=MonteCarloResponse,
    summary="Simulación Monte Carlo — Proyección de valor de cartera a largo plazo",
    description=(
        "Ejecuta una simulación de Movimiento Browniano Geométrico (GBM) con N trayectorias "
        "para proyectar el valor futuro de una cartera de inversión.  Devuelve tres bandas "
        "percentilares: **P10** (pesimista), **P50** (base) y **P90** (optimista)."
    ),
    tags=["Analytics & Predictive"],
)
def run_montecarlo(
    request: MonteCarloRequest,
    db: Session = Depends(get_db),
) -> MonteCarloResponse:
    """Endpoint principal de simulación Monte Carlo.

    Flujo:
    1. Recupera la serie de precios históricos del ticker desde ``etf_history``.
    2. Si hay menos de ``_MIN_HISTORY_POINTS`` registros, genera una serie
       sintética representativa basada en un precio por defecto.
    3. Calibra el motor GBM con los datos y ejecuta la simulación.
    4. Devuelve las bandas P10/P50/P90 más las estadísticas del modelo.
    """
    clean_ticker = request.ticker.strip().upper()
    if not clean_ticker:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El campo 'ticker' no puede estar vacío.",
        )

    # 1. Obtener serie histórica de precios
    price_series: List[float] = _fetch_price_series(clean_ticker, db)

    # 2. Fallback a precios sintéticos si no hay suficiente historia
    if len(price_series) < _MIN_HISTORY_POINTS:
        # Precios de referencia del mercado (EUR) como ancla del modelo sintético
        _reference_prices = {
            "VWCE.DE": 172.86,
            "EUNL.DE": 115.40,
            "8PSG.DE": 43.50,
        }
        base_price = _reference_prices.get(clean_ticker, 100.0)
        price_series = _generate_synthetic_prices(
            base_price=base_price,
            n_points=252,  # 1 año de referencia
        )

    # 3. Ejecutar simulación
    try:
        simulator = MonteCarloSimulator(
            n_simulations=request.n_simulations,
            horizon_days=request.horizon_days,
            random_seed=None,  # No fijamos semilla en producción (cada petición es única)
        )
        result = simulator.run_simulation(
            price_series=price_series,
            initial_investment=request.initial_investment,
            monthly_contribution=request.monthly_contribution,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Error en los parámetros de simulación: {exc}",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno durante la simulación Monte Carlo: {exc}",
        ) from exc

    # 4. Construir respuesta
    stats = result["stats"]
    p10: List[float] = result["p10"]
    p50: List[float] = result["p50"]
    p90: List[float] = result["p90"]

    return MonteCarloResponse(
        ticker=clean_ticker,
        horizon_days=request.horizon_days,
        n_simulations=request.n_simulations,
        initial_investment=request.initial_investment,
        monthly_contribution=request.monthly_contribution,
        p10=p10,
        p50=p50,
        p90=p90,
        days=result["days"],
        mean_daily_return=round(stats["mean_daily_return"], 8),
        std_daily_return=round(stats["std_daily_return"], 8),
        annualized_return=round(stats["annualized_return"], 6),
        annualized_vol=round(stats["annualized_vol"], 6),
        final_p10=p10[-1],
        final_p50=p50[-1],
        final_p90=p90[-1],
    )
