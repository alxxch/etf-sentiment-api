"""Despachador transaccional de herramientas (Tool Dispatcher) para el Asistente Financiero.
Ejecuta de forma determinista y segura las llamadas emitidas por Gemini contra la base
de datos PostgreSQL (SQLAlchemy) y el motor de simulación DCA.
"""
from typing import Any, Dict, Optional
from sqlalchemy.orm import Session

from db.models import EtfHistory, Portfolio, SavingsPlan, User
from db.seed import seed_demo_user
from routers.fintech import _build_portfolio_status
from services.dca_simulator import get_current_asset_price, simulate_dca
from services.rebalance_engine import get_portfolio_rebalance_advice


def normalize_ticker_name(raw_ticker: Optional[str]) -> str:
    """Normaliza menciones coloquiales de activos financieros a tickers estándar."""
    if not raw_ticker:
        return "VWCE.DE"

    clean = raw_ticker.strip().upper()
    if "ORO" in clean or "GOLD" in clean or "8PSG" in clean:
        return "8PSG.DE"
    if "EUNL" in clean or "MSCI WORLD" in clean or "DESARROLLADO" in clean:
        return "EUNL.DE"
    if "VWCE" in clean or "ALL-WORLD" in clean or "MUNDO" in clean or "GLOBAL" in clean:
        return "VWCE.DE"

    # Si ya contiene el sufijo del mercado alemán (.DE) o es un símbolo conocido
    if not clean.endswith(".DE") and clean in ["VWCE", "EUNL", "8PSG"]:
        return f"{clean}.DE"

    return clean if clean.endswith(".DE") else f"{clean}.DE"


def execute_get_portfolio_summary(db: Session, user_id: int = 1) -> Dict[str, Any]:
    """Obtiene el estado completo y métricas de rendimiento de la cartera del usuario Demo."""
    demo_user = db.query(User).filter((User.id == user_id) | (User.username == "demo")).first()
    if not demo_user or not demo_user.portfolio:
        demo_user = seed_demo_user()

    portfolio_data = _build_portfolio_status(demo_user.portfolio, db)

    # Devolver resumen ejecutivo claro y conciso para el LLM
    return {
        "status": "success",
        "portfolio_name": portfolio_data.get("name", "Mi Cartera"),
        "currency": portfolio_data.get("currency", "EUR"),
        "total_invested": portfolio_data.get("total_invested", 0.0),
        "current_value": portfolio_data.get("current_value", 0.0),
        "pnl": portfolio_data.get("pnl", 0.0),
        "roi_pct": portfolio_data.get("roi_pct", 0.0),
        "market_sentiment_score": portfolio_data.get("market_sentiment_score", 58),
        "asset_allocation": [
            {
                "ticker": item["ticker"],
                "asset_class": item["asset_class"],
                "shares": item["shares"],
                "current_price": item["current_price"],
                "current_value": item["current_value"],
                "allocation_pct": item["allocation_pct"],
                "pnl": item["pnl"],
                "roi_pct": item["roi_pct"],
            }
            for item in portfolio_data.get("asset_allocation", [])
        ],
        "active_savings_plan": portfolio_data.get("savings_plan"),
    }


def execute_simulate_dca_plan(args: Dict[str, Any], db: Session) -> Dict[str, Any]:
    """Ejecuta una simulación DCA matemática con los parámetros extraídos por Gemini."""
    monthly_deposit = float(args.get("monthly_deposit", 200.0))
    months = int(args.get("months", 6))
    initial_capital = float(args.get("initial_capital", 0.0))

    raw_equity_pct = args.get("allocation_equity_pct")
    raw_gold_pct = args.get("allocation_gold_pct")

    # Mapeo inteligente si el usuario solo especificó uno de los activos
    if raw_gold_pct is not None and raw_equity_pct is None:
        gold_pct = float(raw_gold_pct)
        equity_pct = max(0.0, 100.0 - gold_pct)
    elif raw_equity_pct is not None and raw_gold_pct is None:
        equity_pct = float(raw_equity_pct)
        gold_pct = max(0.0, 100.0 - equity_pct)
    elif raw_gold_pct is not None and raw_equity_pct is not None:
        equity_pct = float(raw_equity_pct)
        gold_pct = float(raw_gold_pct)
    else:
        equity_pct = 80.0
        gold_pct = 20.0

    simulation = simulate_dca(
        initial_capital=initial_capital,
        monthly_deposit=monthly_deposit,
        months=months,
        allocation_equity_pct=equity_pct,
        allocation_gold_pct=gold_pct,
        equity_ticker="VWCE.DE",
        gold_ticker="8PSG.DE",
        db=db,
    )

    return {
        "status": "success",
        "simulation_parameters": {
            "monthly_deposit": monthly_deposit,
            "months": months,
            "allocation_equity_pct": simulation.get("allocation_equity_pct"),
            "allocation_gold_pct": simulation.get("allocation_gold_pct"),
            "initial_capital": initial_capital,
        },
        "results": {
            "total_invested": simulation.get("total_invested"),
            "final_portfolio_value": simulation.get("current_value"),
            "pnl": simulation.get("pnl"),
            "roi_pct": simulation.get("roi_pct"),
            "equity_shares_accumulated": simulation.get("equity_shares"),
            "gold_shares_accumulated": simulation.get("gold_shares"),
            "current_equity_price": simulation.get("current_equity_price"),
            "current_gold_price": simulation.get("current_gold_price"),
        },
        "simulation": simulation,
        "steps_count": len(simulation.get("steps", [])),
    }


def execute_get_market_sentiment(args: Dict[str, Any], db: Session) -> Dict[str, Any]:
    """Consulta la última lectura de sentimiento de mercado y cotización para un ticker."""
    ticker = normalize_ticker_name(args.get("ticker"))

    latest_history = (
        db.query(EtfHistory)
        .filter(EtfHistory.ticker == ticker)
        .order_by(EtfHistory.timestamp.desc())
        .first()
    )

    current_price = get_current_asset_price(ticker, db=db)

    if latest_history:
        sentiment_score = int(latest_history.sentiment_score)
        ai_summary = latest_history.ai_summary
        change_percent = float(latest_history.change_percent)
    else:
        sentiment_score = 62 if ticker == "8PSG.DE" else 58
        ai_summary = f"Mercado estable para {ticker} con sesgo favorable a largo plazo."
        change_percent = 0.45

    return {
        "status": "success",
        "ticker": ticker,
        "current_price": round(current_price, 2),
        "change_percent": round(change_percent, 2),
        "sentiment_score": sentiment_score,
        "sentiment_label": (
            "Alcista / Bullish" if sentiment_score >= 60 else
            ("Bajista / Bearish" if sentiment_score <= 40 else "Neutral")
        ),
        "ai_summary": ai_summary,
    }


def execute_update_savings_plan(args: Dict[str, Any], db: Session, user_id: int = 1) -> Dict[str, Any]:
    """Actualiza y persiste el plan de ahorro del usuario."""
    demo_user = db.query(User).filter((User.id == user_id) | (User.username == "demo")).first()
    if not demo_user or not demo_user.portfolio:
        demo_user = seed_demo_user()

    portfolio = demo_user.portfolio
    plan = db.query(SavingsPlan).filter(SavingsPlan.portfolio_id == portfolio.id).first()

    if not plan:
        plan = SavingsPlan(portfolio_id=portfolio.id)
        db.add(plan)

    if "monthly_deposit" in args and args["monthly_deposit"] is not None:
        plan.monthly_deposit = float(args["monthly_deposit"])

    raw_equity = args.get("allocation_equity_pct")
    raw_gold = args.get("allocation_gold_pct")

    if raw_gold is not None and raw_equity is None:
        plan.allocation_gold_pct = float(raw_gold)
        plan.allocation_equity_pct = max(0.0, 100.0 - float(raw_gold))
    elif raw_equity is not None and raw_gold is None:
        plan.allocation_equity_pct = float(raw_equity)
        plan.allocation_gold_pct = max(0.0, 100.0 - float(raw_equity))
    elif raw_equity is not None and raw_gold is not None:
        plan.allocation_equity_pct = float(raw_equity)
        plan.allocation_gold_pct = float(raw_gold)

    plan.is_active = True
    db.commit()
    db.refresh(plan)

    return {
        "status": "success",
        "message": "Plan de ahorro actualizado correctamente.",
        "savings_plan": plan.to_dict(),
    }


def execute_calculate_portfolio_rebalance(
    args: Dict[str, Any],
    db: Session,
    user_id: int = 1,
) -> Dict[str, Any]:
    """Calcula la directriz de rebalanceo cuantitativo para la cartera del usuario."""
    demo_user = db.query(User).filter((User.id == user_id) | (User.username == "demo")).first()
    if not demo_user or not demo_user.portfolio:
        demo_user = seed_demo_user()

    custom_deposit = args.get("custom_deposit")
    if custom_deposit is not None:
        custom_deposit = float(custom_deposit)

    rebalance_data = get_portfolio_rebalance_advice(
        portfolio_id=demo_user.portfolio.id,
        db=db,
        custom_deposit=custom_deposit,
    )

    return {
        "status": "success",
        "rebalance_data": rebalance_data,
        "summary_message": rebalance_data.get("summary_message", ""),
        "rebalance_status": rebalance_data.get("rebalance_status", "BALANCED"),
        "current_portfolio_value": rebalance_data.get("current_portfolio_value", 0.0),
        "monthly_deposit": rebalance_data.get("monthly_deposit", 200.0),
        "post_rebalance_portfolio_value": rebalance_data.get("post_rebalance_portfolio_value", 0.0),
        "assets": rebalance_data.get("assets", []),
    }


def dispatch_tool_call(
    tool_name: str,
    args: Dict[str, Any],
    db: Session,
    user_id: int = 1,
) -> Dict[str, Any]:
    """Enruta la llamada de herramienta al handler transaccional correspondiente."""
    clean_name = tool_name.strip()

    if clean_name == "get_portfolio_summary":
        return execute_get_portfolio_summary(db=db, user_id=user_id)

    elif clean_name == "simulate_dca_plan":
        return execute_simulate_dca_plan(args=args, db=db)

    elif clean_name == "get_market_sentiment":
        return execute_get_market_sentiment(args=args, db=db)

    elif clean_name == "update_savings_plan":
        return execute_update_savings_plan(args=args, db=db, user_id=user_id)

    elif clean_name == "calculate_portfolio_rebalance":
        return execute_calculate_portfolio_rebalance(args=args, db=db, user_id=user_id)

    else:
        return {
            "status": "error",
            "message": f"Herramienta desconocida o no implementada: '{clean_name}'.",
        }
