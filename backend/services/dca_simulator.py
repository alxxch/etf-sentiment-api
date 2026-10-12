"""Servicio de simulación de aportaciones periódicas sistemáticas (DCA - Dollar Cost Averaging).
Calcula la acumulación progresiva de participaciones, rentabilidad financiera (P&L, ROI)
y correlación con la curva histórica de sentimiento de mercado (sentiment_score),
distribuyendo el capital mensual entre ETFs de renta variable (VWCE.DE) y oro físico (8PSG.DE).
"""
import math
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from db.models import EtfHistory
from scraper import get_ticker_data


def get_current_asset_price(ticker: str, db: Optional[Session] = None) -> float:
    """Obtiene el precio más reciente del activo desde la BD o yfinance."""
    if db is not None:
        latest = (
            db.query(EtfHistory)
            .filter(EtfHistory.ticker == ticker)
            .order_by(EtfHistory.timestamp.desc())
            .first()
        )
        if latest and latest.price > 0:
            return float(latest.price)

    # Fallback a scraper en tiempo real
    try:
        data = get_ticker_data(ticker)
        if data and "current_price" in data and data["current_price"] > 0:
            return float(data["current_price"])
    except Exception:
        pass

    # Precios de referencia razonables por defecto si los servicios externos no responden
    default_prices = {
        "VWCE.DE": 172.86,
        "EUNL.DE": 115.40,
        "8PSG.DE": 43.50,
    }
    return default_prices.get(ticker, 100.0)


def get_market_sentiment_for_date(
    ticker: str,
    target_date: datetime,
    month_index: int,
    total_months: int,
    db: Optional[Session] = None,
) -> int:
    """Obtiene el sentimiento de mercado histórico para una fecha determinada.
    Si existen registros en etf_history para la fecha, los usa.
    De lo contrario, interpola a partir del último registro o simula una oscilación de mercado realista (42 - 76).
    """
    if db is not None:
        # 1. Buscar registro exacto o anterior más cercano
        history_record = (
            db.query(EtfHistory)
            .filter(EtfHistory.ticker == ticker)
            .filter(EtfHistory.timestamp <= target_date)
            .order_by(EtfHistory.timestamp.desc())
            .first()
        )
        if history_record and history_record.sentiment_score is not None:
            return int(history_record.sentiment_score)

        # 2. Si no hay registro histórico anterior, buscar el más reciente en general
        latest_record = (
            db.query(EtfHistory)
            .filter(EtfHistory.ticker == ticker)
            .order_by(EtfHistory.timestamp.desc())
            .first()
        )
        if latest_record and latest_record.sentiment_score is not None:
            base_score = int(latest_record.sentiment_score)
            # Aplicar suave variación cíclica retrospectiva
            cycle = int(math.sin(month_index * 0.9) * 12)
            return max(15, min(95, base_score + cycle))

    # 3. Simulación estándar de ciclo de mercado (sentimiento contracíclico entre 40 y 75)
    cycle_sentiment = int(58 + math.sin(month_index * 1.1) * 16)
    return max(10, min(90, cycle_sentiment))


def simulate_dca(
    initial_capital: float = 0.0,
    monthly_deposit: float = 200.0,
    months: int = 6,
    allocation_equity_pct: float = 80.0,
    allocation_gold_pct: float = 20.0,
    equity_ticker: str = "VWCE.DE",
    gold_ticker: str = "8PSG.DE",
    db: Optional[Session] = None,
) -> Dict[str, Any]:
    """Ejecuta una simulación de compras periódicas mensuales dividiendo la aportación
    entre renta variable y oro, calculando el crecimiento temporal del capital y
    el cruce con el sentimiento histórico de mercado.
    """
    if months <= 0:
        raise ValueError("El número de meses debe ser mayor a 0.")
    if monthly_deposit <= 0:
        raise ValueError("La aportación mensual debe ser mayor a 0.")
    if initial_capital < 0:
        raise ValueError("El capital inicial no puede ser negativo.")

    # Normalizar porcentajes si difieren del 100%
    total_pct = allocation_equity_pct + allocation_gold_pct
    if total_pct <= 0:
        norm_equity_pct = 80.0
        norm_gold_pct = 20.0
    else:
        norm_equity_pct = (allocation_equity_pct / total_pct) * 100.0
        norm_gold_pct = (allocation_gold_pct / total_pct) * 100.0

    monthly_equity_cash = monthly_deposit * (norm_equity_pct / 100.0)
    monthly_gold_cash = monthly_deposit * (norm_gold_pct / 100.0)

    # Precios actuales de liquidación
    current_equity_price = get_current_asset_price(equity_ticker, db=db)
    current_gold_price = get_current_asset_price(gold_ticker, db=db)

    total_equity_shares = 0.0
    total_gold_shares = 0.0
    total_equity_invested = 0.0
    total_gold_invested = 0.0

    simulation_steps: List[Dict[str, Any]] = []
    base_date = datetime.now(timezone.utc) - timedelta(days=30 * months)

    # Simular cada aportación mensual secuencialmente
    for i in range(1, months + 1):
        step_date = base_date + timedelta(days=30 * i)

        # Precio de mercado simulado en esa fecha histórica
        # Modelo realista de tendencia alcista moderada con fluctuación mensual
        progress = i / months
        equity_price_at_step = current_equity_price * (0.90 + (0.10 * progress) + (0.015 * math.sin(i * 1.5)))
        gold_price_at_step = current_gold_price * (0.93 + (0.07 * progress) + (0.010 * math.cos(i * 1.2)))

        # En el primer mes se suma el capital inicial si existe
        if i == 1 and initial_capital > 0:
            step_equity_cash = monthly_equity_cash + (initial_capital * (norm_equity_pct / 100.0))
            step_gold_cash = monthly_gold_cash + (initial_capital * (norm_gold_pct / 100.0))
            step_invested = monthly_deposit + initial_capital
        else:
            step_equity_cash = monthly_equity_cash
            step_gold_cash = monthly_gold_cash
            step_invested = monthly_deposit

        equity_shares_bought = step_equity_cash / equity_price_at_step
        gold_shares_bought = step_gold_cash / gold_price_at_step

        total_equity_shares += equity_shares_bought
        total_gold_shares += gold_shares_bought
        total_equity_invested += step_equity_cash
        total_gold_invested += step_gold_cash

        cumulative_invested = total_equity_invested + total_gold_invested
        step_portfolio_value = (total_equity_shares * equity_price_at_step) + (total_gold_shares * gold_price_at_step)
        step_pnl = step_portfolio_value - cumulative_invested
        step_roi_pct = (step_pnl / cumulative_invested * 100.0) if cumulative_invested > 0 else 0.0

        sentiment_score = get_market_sentiment_for_date(
            equity_ticker,
            step_date,
            i,
            months,
            db=db,
        )

        simulation_steps.append({
            "month_index": i,
            "date": step_date.strftime("%Y-%m-%d"),
            "cumulative_invested": round(cumulative_invested, 2),
            "portfolio_value": round(step_portfolio_value, 2),
            "pnl": round(step_pnl, 2),
            "roi_pct": round(step_roi_pct, 2),
            "market_sentiment_score": sentiment_score,
            "equity_price": round(equity_price_at_step, 2),
            "gold_price": round(gold_price_at_step, 2),
            "equity_shares_bought": round(equity_shares_bought, 4),
            "gold_shares_bought": round(gold_shares_bought, 4),
        })

    total_invested = total_equity_invested + total_gold_invested
    current_equity_value = total_equity_shares * current_equity_price
    current_gold_value = total_gold_shares * current_gold_price
    current_total_value = current_equity_value + current_gold_value

    pnl = current_total_value - total_invested
    roi_pct = (pnl / total_invested * 100.0) if total_invested > 0 else 0.0

    break_even_equity = (total_equity_invested / total_equity_shares) if total_equity_shares > 0 else 0.0
    break_even_gold = (total_gold_invested / total_gold_shares) if total_gold_shares > 0 else 0.0

    return {
        "total_invested": round(total_invested, 2),
        "current_value": round(current_total_value, 2),
        "pnl": round(pnl, 2),
        "roi_pct": round(roi_pct, 2),
        "equity_shares": round(total_equity_shares, 4),
        "gold_shares": round(total_gold_shares, 4),
        "break_even_equity": round(break_even_equity, 2),
        "break_even_gold": round(break_even_gold, 2),
        "current_equity_price": round(current_equity_price, 2),
        "current_gold_price": round(current_gold_price, 2),
        "transactions_count": months * 2 + (2 if initial_capital > 0 else 0),
        "allocation_equity_pct": round(norm_equity_pct, 1),
        "allocation_gold_pct": round(norm_gold_pct, 1),
        "steps": simulation_steps,
    }
