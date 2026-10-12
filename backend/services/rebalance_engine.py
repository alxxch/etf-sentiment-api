"""Motor Cuantitativo de Rebalanceo Inteligente y Alocación Dinámica (Phase 14).
Calcula la desviación de la cartera (Portfolio Drift) en porcentaje y en euros
frente a los objetivos definidos en el Plan de Ahorro (SavingsPlan), y genera
una directriz matemática óptima para la próxima aportación mensual (DCA) que
corrige la desviación sin requerir ventas de activos con fricción fiscal.
"""
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from db.models import Portfolio, SavingsPlan, Transaction
from services.dca_simulator import get_current_asset_price


def calculate_rebalance_plan(
    assets_valuation: List[Dict[str, Any]],
    target_equity_pct: float = 80.0,
    target_gold_pct: float = 20.0,
    monthly_deposit: float = 200.0,
    equity_ticker: str = "VWCE.DE",
    gold_ticker: str = "8PSG.DE",
) -> Dict[str, Any]:
    """Algoritmo cuantitativo puro para el cálculo de desviación de cartera y rebalanceo.

    Args:
        assets_valuation: Lista de diccionarios con keys:
            'ticker', 'asset_class' ('EQUITY' o 'GOLD'), 'current_value'.
        target_equity_pct: % objetivo para renta variable (ej: 80.0).
        target_gold_pct: % objetivo para oro físico (ej: 20.0).
        monthly_deposit: Monto de la aportación mensual disponible en EUR (C).
        equity_ticker: Ticker por defecto para renta variable ('VWCE.DE').
        gold_ticker: Ticker por defecto para oro ('8PSG.DE').

    Returns:
        Diccionario estructurado con métricas de desviación actual, directriz de compra
        sugerida para la aportación y proyección post-rebalanceo.
    """
    deposit = max(0.0, float(monthly_deposit))

    # 1. Normalizar porcentajes objetivo para que sumen 100%
    target_sum = target_equity_pct + target_gold_pct
    if target_sum <= 0:
        target_equity_pct = 80.0
        target_gold_pct = 20.0
        target_sum = 100.0
    norm_target_equity = (target_equity_pct / target_sum) * 100.0
    norm_target_gold = (target_gold_pct / target_sum) * 100.0

    # 2. Extraer valor actual por clase de activo
    equity_val = 0.0
    gold_val = 0.0

    for asset in assets_valuation:
        a_class = str(asset.get("asset_class", "")).upper()
        ticker = str(asset.get("ticker", "")).upper()
        val = max(0.0, float(asset.get("current_value", 0.0)))

        if a_class == "GOLD" or "PSG" in ticker or "GOLD" in ticker:
            gold_val += val
        else:
            equity_val += val

    current_portfolio_value = equity_val + gold_val

    # 3. Calcular asignación porcentual y desviaciones actuales
    if current_portfolio_value > 0:
        current_equity_pct = (equity_val / current_portfolio_value) * 100.0
        current_gold_pct = (gold_val / current_portfolio_value) * 100.0
    else:
        current_equity_pct = 0.0
        current_gold_pct = 0.0

    # Desviación porcentual (Portfolio Drift %): Actual - Objetivo
    drift_equity_pct = current_equity_pct - norm_target_equity
    drift_gold_pct = current_gold_pct - norm_target_gold

    # Valores ideales actuales en euros
    ideal_equity_val = current_portfolio_value * (norm_target_equity / 100.0)
    ideal_gold_val = current_portfolio_value * (norm_target_gold / 100.0)

    # Desviación absoluta en euros: Actual - Ideal
    drift_equity_amount = equity_val - ideal_equity_val
    drift_gold_amount = gold_val - ideal_gold_val

    # 4. Cálculo de la aportación sugerida para corregir la desviación
    # Valor total proyectado tras la aportación: V' = V + C
    post_portfolio_value = current_portfolio_value + deposit

    if post_portfolio_value == 0:
        # Cartera vacía y sin aportación
        return {
            "current_portfolio_value": 0.0,
            "monthly_deposit": 0.0,
            "post_rebalance_portfolio_value": 0.0,
            "rebalance_status": "BALANCED",
            "summary_message": "Cartera vacía sin aportación programada.",
            "assets": [],
        }

    # Valores ideales en la cartera post-aportación
    post_ideal_equity = post_portfolio_value * (norm_target_equity / 100.0)
    post_ideal_gold = post_portfolio_value * (norm_target_gold / 100.0)

    # Déficit o necesidad de capital de cada activo para alcanzar su objetivo ideal:
    # D_i = post_ideal_i - V_i
    # Nótese que D_equity + D_gold = post_portfolio_value - current_portfolio_value = deposit
    deficit_equity = post_ideal_equity - equity_val
    deficit_gold = post_ideal_gold - gold_val

    # 5. Algoritmo de asignación no negativa de flujo de caja (sin ventas forzadas)
    if current_portfolio_value == 0:
        # Cartera nueva: se divide estrictamente según los porcentajes objetivo
        suggested_equity = deposit * (norm_target_equity / 100.0)
        suggested_gold = deposit - suggested_equity
        rebalance_status = "BALANCED"
    elif deficit_equity >= 0 and deficit_gold >= 0:
        # La aportación es suficiente para alcanzar la paridad perfecta en ambos activos
        suggested_equity = deficit_equity
        suggested_gold = deficit_gold
        if abs(drift_equity_pct) < 0.5 and abs(drift_gold_pct) < 0.5:
            rebalance_status = "BALANCED"
        else:
            rebalance_status = "FULLY_REBALANCED"
    elif deficit_equity < 0:
        # Renta Variable está tan sobreponderada que ni con 0€ adicionales se balancea al 100%.
        # Se destina el 100% del flujo al activo rezagado (Oro).
        suggested_equity = 0.0
        suggested_gold = deposit
        rebalance_status = "PARTIALLY_REBALANCED"
    else:
        # Oro está tan sobreponderado que ni con 0€ adicionales se balancea al 100%.
        # Se destina el 100% del flujo al activo rezagado (Renta Variable).
        suggested_equity = deposit
        suggested_gold = 0.0
        rebalance_status = "PARTIALLY_REBALANCED"

    # Redondeos exactos a 2 decimales asegurando conservación de suma
    suggested_equity = round(suggested_equity, 2)
    suggested_gold = round(deposit - suggested_equity, 2)

    # 6. Proyección post-rebalanceo
    proj_equity_val = round(equity_val + suggested_equity, 2)
    proj_gold_val = round(gold_val + suggested_gold, 2)
    proj_total_val = round(proj_equity_val + proj_gold_val, 2)

    if proj_total_val > 0:
        proj_equity_pct = round((proj_equity_val / proj_total_val) * 100.0, 2)
        proj_gold_pct = round((proj_gold_val / proj_total_val) * 100.0, 2)
    else:
        proj_equity_pct = 0.0
        proj_gold_pct = 0.0

    suggested_equity_pct = round((suggested_equity / deposit * 100.0), 1) if deposit > 0 else 0.0
    suggested_gold_pct = round((suggested_gold / deposit * 100.0), 1) if deposit > 0 else 0.0

    # 7. Redacción del mensaje de directriz cuantitativa
    if rebalance_status == "BALANCED":
        summary_message = (
            f"Tu cartera se encuentra equilibrada (desviación menor al 0.5%). "
            f"Se sugiere mantener la aportación habitual de {deposit:.2f}€ repartida al "
            f"{norm_target_equity:.0f}% en Renta Variable ({suggested_equity:.2f}€) y "
            f"{norm_target_gold:.0f}% en Oro ({suggested_gold:.2f}€)."
        )
    elif rebalance_status == "FULLY_REBALANCED":
        lagging_asset = "Oro físico" if drift_gold_pct < 0 else "Renta Variable"
        summary_message = (
            f"Desviación detectada: Renta Variable {drift_equity_pct:+.1f}% | Oro {drift_gold_pct:+.1f}%. "
            f"Tu aportación de {deposit:.2f}€ permite corregir el 100% de la desviación destinando "
            f"{suggested_equity:.2f}€ ({suggested_equity_pct:.0f}%) a Renta Variable y "
            f"{suggested_gold:.2f}€ ({suggested_gold_pct:.0f}%) a {lagging_asset}."
        )
    else:
        # PARTIALLY_REBALANCED
        overweight_asset = "Renta Variable" if drift_equity_pct > 0 else "Oro físico"
        underweight_asset = "Oro físico" if drift_gold_pct < 0 else "Renta Variable"
        summary_message = (
            f"Desviación significativa detectada: {overweight_asset} se encuentra sobreponderado "
            f"({max(drift_equity_pct, drift_gold_pct):+.1f}%). "
            f"Para acelerar la corrección hacia tu objetivo sin generar ventas forzadas, "
            f"se aconseja destinar el 100% de la aportación de este mes ({deposit:.2f}€) a {underweight_asset}."
        )

    assets_result = [
        {
            "ticker": equity_ticker,
            "asset_class": "EQUITY",
            "current_value": round(equity_val, 2),
            "current_allocation_pct": round(current_equity_pct, 2),
            "target_allocation_pct": round(norm_target_equity, 2),
            "drift_pct": round(drift_equity_pct, 2),
            "drift_amount": round(drift_equity_amount, 2),
            "suggested_deposit": suggested_equity,
            "suggested_deposit_pct": suggested_equity_pct,
            "projected_value": proj_equity_val,
            "projected_allocation_pct": proj_equity_pct,
        },
        {
            "ticker": gold_ticker,
            "asset_class": "GOLD",
            "current_value": round(gold_val, 2),
            "current_allocation_pct": round(current_gold_pct, 2),
            "target_allocation_pct": round(norm_target_gold, 2),
            "drift_pct": round(drift_gold_pct, 2),
            "drift_amount": round(drift_gold_amount, 2),
            "suggested_deposit": suggested_gold,
            "suggested_deposit_pct": suggested_gold_pct,
            "projected_value": proj_gold_val,
            "projected_allocation_pct": proj_gold_pct,
        },
    ]

    return {
        "current_portfolio_value": round(current_portfolio_value, 2),
        "monthly_deposit": round(deposit, 2),
        "post_rebalance_portfolio_value": round(proj_total_val, 2),
        "rebalance_status": rebalance_status,
        "summary_message": summary_message,
        "assets": assets_result,
    }


def get_portfolio_rebalance_advice(
    portfolio_id: int,
    db: Session,
    custom_deposit: Optional[float] = None,
) -> Dict[str, Any]:
    """Obtiene los datos del portfolio y plan de ahorro desde la BD,
    calcula la valoración de mercado actual y ejecuta el algoritmo de rebalanceo.
    """
    portfolio = db.query(Portfolio).filter(Portfolio.id == portfolio_id).first()
    if not portfolio:
        raise ValueError(f"Cartera con ID {portfolio_id} no encontrada.")

    # 1. Agrupar transacciones para calcular participaciones actuales
    holdings: Dict[str, Dict[str, Any]] = {}
    for tx in portfolio.transactions:
        ticker = tx.ticker.upper()
        if ticker not in holdings:
            holdings[ticker] = {
                "ticker": ticker,
                "asset_class": tx.asset_class or ("GOLD" if "PSG" in ticker else "EQUITY"),
                "shares": 0.0,
            }
        holdings[ticker]["shares"] += tx.shares

    # 2. Valorar cada posición con cotizaciones de mercado
    assets_valuation: List[Dict[str, Any]] = []
    equity_ticker = "VWCE.DE"
    gold_ticker = "8PSG.DE"

    for ticker, data in holdings.items():
        shares = data["shares"]
        if shares <= 0:
            continue
        price = get_current_asset_price(ticker, db=db)
        val = shares * price
        asset_class = data["asset_class"]

        if asset_class == "EQUITY":
            equity_ticker = ticker
        elif asset_class == "GOLD":
            gold_ticker = ticker

        assets_valuation.append({
            "ticker": ticker,
            "asset_class": asset_class,
            "current_value": val,
        })

    # 3. Extraer configuración del plan de ahorro activo
    savings_plan = portfolio.savings_plan
    if savings_plan and savings_plan.is_active:
        default_deposit = float(savings_plan.monthly_deposit)
        target_equity = float(savings_plan.allocation_equity_pct)
        target_gold = float(savings_plan.allocation_gold_pct)
    else:
        default_deposit = 200.0
        target_equity = 80.0
        target_gold = 20.0

    deposit_to_use = custom_deposit if custom_deposit is not None else default_deposit

    # 4. Calcular el plan de rebalanceo cuantitativo
    rebalance_result = calculate_rebalance_plan(
        assets_valuation=assets_valuation,
        target_equity_pct=target_equity,
        target_gold_pct=target_gold,
        monthly_deposit=deposit_to_use,
        equity_ticker=equity_ticker,
        gold_ticker=gold_ticker,
    )

    rebalance_result["portfolio_id"] = portfolio.id
    rebalance_result["user_id"] = portfolio.user_id

    return rebalance_result
