"""Router de Fintech y Simulador de Portfolio.
Endpoints para gestión de carteras, planes de ahorro sistemáticos (DCA),
valoración liquidativa y simulación retrospectiva con cruce de sentimiento de mercado.
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import EtfHistory, Portfolio, SavingsPlan, Transaction, User
from db.seed import seed_demo_user
from schemas import (
    AssetAllocationItem,
    DcaSimulationRequest,
    DcaSimulationResult,
    PortfolioStatusResponse,
    SavingsPlanCreate,
    SavingsPlanResponse,
    TransactionResponse,
)
from services.dca_simulator import get_current_asset_price, simulate_dca

router = APIRouter()


def _ensure_demo_transactions(portfolio: Portfolio, db: Session) -> None:
    """Si la cartera demo no posee transacciones, inyecta 3 meses de compras DCA
    para que la interfaz de usuario muestre datos financieros reales y desglose multiactivo.
    """
    if len(portfolio.transactions) > 0:
        return

    now = datetime.now(timezone.utc)
    # Precios de ejecución históricos simulados (hace 3 meses, 2 meses y 1 mes)
    historical_samples = [
        {"days_ago": 90, "vwce_price": 165.20, "gold_price": 41.80},
        {"days_ago": 60, "vwce_price": 168.40, "gold_price": 42.30},
        {"days_ago": 30, "vwce_price": 171.10, "gold_price": 42.90},
    ]

    monthly_equity_amount = 160.0  # 80% de 200 EUR
    monthly_gold_amount = 40.0    # 20% de 200 EUR

    for sample in historical_samples:
        tx_date = now - timedelta(days=sample["days_ago"])
        vwce_shares = round(monthly_equity_amount / sample["vwce_price"], 4)
        gold_shares = round(monthly_gold_amount / sample["gold_price"], 4)

        # Transacción Renta Variable (VWCE.DE)
        tx_equity = Transaction(
            portfolio_id=portfolio.id,
            ticker="VWCE.DE",
            asset_class="EQUITY",
            shares=vwce_shares,
            price_per_share=sample["vwce_price"],
            amount_invested=monthly_equity_amount,
            fee=0.0,
            is_automated=True,
            timestamp=tx_date,
        )
        db.add(tx_equity)

        # Transacción Oro Físico (8PSG.DE)
        tx_gold = Transaction(
            portfolio_id=portfolio.id,
            ticker="8PSG.DE",
            asset_class="GOLD",
            shares=gold_shares,
            price_per_share=sample["gold_price"],
            amount_invested=monthly_gold_amount,
            fee=0.0,
            is_automated=True,
            timestamp=tx_date,
        )
        db.add(tx_gold)

    try:
        db.commit()
        db.refresh(portfolio)
    except Exception as e:
        db.rollback()
        print(f"[fintech] Advertencia al generar transacciones demo: {e}")


def _build_portfolio_status(portfolio: Portfolio, db: Session) -> Dict[str, Any]:
    """Calcula la valoración liquidativa consolidada, P&L, ROI, alocación multiactivo
    y cruce con el sentimiento de mercado actual.
    """
    _ensure_demo_transactions(portfolio, db)

    # Agrupar transacciones por ticker
    holdings_map: Dict[str, Dict[str, Any]] = {}
    total_invested = 0.0

    for tx in portfolio.transactions:
        ticker = tx.ticker.upper()
        if ticker not in holdings_map:
            holdings_map[ticker] = {
                "ticker": ticker,
                "asset_class": tx.asset_class or ("GOLD" if "PSG" in ticker else "EQUITY"),
                "shares": 0.0,
                "amount_invested": 0.0,
            }
        holdings_map[ticker]["shares"] += tx.shares
        holdings_map[ticker]["amount_invested"] += tx.amount_invested
        total_invested += tx.amount_invested

    # Calcular valoración actual y métricas por activo
    asset_allocation: List[Dict[str, Any]] = []
    current_portfolio_value = 0.0

    for ticker, h_data in holdings_map.items():
        shares = round(h_data["shares"], 4)
        invested = round(h_data["amount_invested"], 2)
        break_even_price = round(invested / shares, 2) if shares > 0 else 0.0
        current_price = get_current_asset_price(ticker, db=db)
        asset_value = round(shares * current_price, 2)
        asset_pnl = round(asset_value - invested, 2)
        asset_roi = round((asset_pnl / invested * 100.0), 2) if invested > 0 else 0.0

        current_portfolio_value += asset_value
        asset_allocation.append({
            "ticker": ticker,
            "asset_class": h_data["asset_class"],
            "shares": shares,
            "current_price": round(current_price, 2),
            "current_value": asset_value,
            "allocation_pct": 0.0,  # Se computa tras obtener la suma total
            "break_even_price": break_even_price,
            "pnl": asset_pnl,
            "roi_pct": asset_roi,
        })

    current_portfolio_value = round(current_portfolio_value, 2)
    total_invested = round(total_invested, 2)

    # Calcular % de asignación real en cartera
    for item in asset_allocation:
        if current_portfolio_value > 0:
            item["allocation_pct"] = round((item["current_value"] / current_portfolio_value * 100.0), 1)
        else:
            item["allocation_pct"] = 0.0

    pnl_total = round(current_portfolio_value - total_invested, 2)
    roi_total = round((pnl_total / total_invested * 100.0), 2) if total_invested > 0 else 0.0

    # Obtener el sentimiento de mercado más reciente para el activo insignia (VWCE.DE)
    latest_sentiment = (
        db.query(EtfHistory)
        .filter(EtfHistory.ticker == "VWCE.DE")
        .order_by(EtfHistory.timestamp.desc())
        .first()
    )
    if not latest_sentiment:
        latest_sentiment = db.query(EtfHistory).order_by(EtfHistory.timestamp.desc()).first()

    market_sentiment_score = int(latest_sentiment.sentiment_score) if latest_sentiment else 58

    return {
        "id": portfolio.id,
        "user_id": portfolio.user_id,
        "user_email": portfolio.user.email if portfolio.user else "demo@example.com",
        "user_name": portfolio.user.username if portfolio.user else "Demo User",
        "name": portfolio.name,
        "currency": portfolio.currency,
        "initial_balance": portfolio.initial_balance,
        "total_invested": total_invested,
        "current_value": current_portfolio_value,
        "pnl": pnl_total,
        "roi_pct": roi_total,
        "market_sentiment_score": market_sentiment_score,
        "asset_allocation": asset_allocation,
        "savings_plan": portfolio.savings_plan.to_dict() if portfolio.savings_plan else None,
        "transactions": [tx.to_dict() for tx in portfolio.transactions],
    }


@router.get(
    "/portfolio",
    response_model=PortfolioStatusResponse,
    summary="Obtiene el estado actual y valoración de la cartera del usuario Demo",
)
def get_demo_portfolio(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Devuelve la cartera consolidada del usuario Demo (User ID 1 o 'demo'),
    incluyendo su plan de ahorro activo (DCA), histórico de transacciones,
    distribución porcentual multiactivo y métricas de P&L / ROI.
    """
    demo_user = db.query(User).filter((User.username == "demo") | (User.id == 1)).first()
    if not demo_user:
        demo_user = seed_demo_user()

    if not demo_user or not demo_user.portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró una cartera configurada para el usuario Demo.",
        )

    return _build_portfolio_status(demo_user.portfolio, db)


@router.get(
    "/portfolio/{portfolio_id}",
    response_model=PortfolioStatusResponse,
    summary="Obtiene el estado de una cartera por su identificador único",
)
def get_portfolio_by_id(
    portfolio_id: int,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Consulta una cartera específica por su ID y genera su valoración liquidativa."""
    portfolio = db.query(Portfolio).filter(Portfolio.id == portfolio_id).first()
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cartera con ID {portfolio_id} no encontrada.",
        )
    return _build_portfolio_status(portfolio, db)


@router.post(
    "/simulate-dca",
    response_model=DcaSimulationResult,
    summary="Simulación temporal de crecimiento de capital DCA cruzado con sentimiento",
)
def simulate_dca_endpoint(
    request: DcaSimulationRequest,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Ejecuta una simulación DCA matemática retrospectiva.
    Calcula:
    - Crecimiento del capital acumulado vs valor real de mercado.
    - Curva de rentabilidad P&L y ROI.
    - Serie temporal enriquecida con market_sentiment_score para graficar en Flutter (fl_chart).
    """
    try:
        result = simulate_dca(
            initial_capital=request.initial_capital,
            monthly_deposit=request.monthly_deposit,
            months=request.months,
            allocation_equity_pct=request.allocation_equity_pct,
            allocation_gold_pct=request.allocation_gold_pct,
            equity_ticker="VWCE.DE",
            gold_ticker="8PSG.DE",
            db=db,
        )
        return result
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al ejecutar la simulación DCA: {str(e)}",
        )


@router.get(
    "/savings-plan",
    response_model=SavingsPlanResponse,
    summary="Obtiene la configuración del plan de ahorro DCA del usuario Demo",
)
def get_demo_savings_plan(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Consulta el plan de ahorro activo asociado a la cartera del usuario Demo."""
    demo_user = db.query(User).filter((User.username == "demo") | (User.id == 1)).first()
    if not demo_user or not demo_user.portfolio or not demo_user.portfolio.savings_plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un plan de ahorro configurado.",
        )
    return demo_user.portfolio.savings_plan.to_dict()


@router.post(
    "/savings-plan",
    response_model=SavingsPlanResponse,
    summary="Crea o actualiza la configuración del plan de ahorro DCA",
)
def update_savings_plan(
    plan_in: SavingsPlanCreate,
    portfolio_id: Optional[int] = Query(None, description="ID de la cartera a modificar"),
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Crea o actualiza el plan de ahorro DCA periódico (mensualidad y reparto porcentual)."""
    target_portfolio_id = portfolio_id
    if target_portfolio_id is None:
        demo_user = db.query(User).filter((User.username == "demo") | (User.id == 1)).first()
        if not demo_user or not demo_user.portfolio:
            demo_user = seed_demo_user()
        target_portfolio_id = demo_user.portfolio.id

    plan = db.query(SavingsPlan).filter(SavingsPlan.portfolio_id == target_portfolio_id).first()
    if plan:
        plan.monthly_deposit = plan_in.monthly_deposit
        plan.frequency = plan_in.frequency
        plan.allocation_equity_pct = plan_in.allocation_equity_pct
        plan.allocation_gold_pct = plan_in.allocation_gold_pct
        plan.is_active = plan_in.is_active
    else:
        plan = SavingsPlan(
            portfolio_id=target_portfolio_id,
            monthly_deposit=plan_in.monthly_deposit,
            frequency=plan_in.frequency,
            allocation_equity_pct=plan_in.allocation_equity_pct,
            allocation_gold_pct=plan_in.allocation_gold_pct,
            is_active=plan_in.is_active,
        )
        db.add(plan)

    db.commit()
    db.refresh(plan)
    return plan.to_dict()
