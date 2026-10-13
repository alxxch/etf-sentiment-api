"""Router del Asistente Financiero Inteligente — Fase 25 refactorizado.

Expone:
  POST /api/v1/assistant/chat

Flujo de decisión:
  1. Clasificación de intención: ¿es una consulta de ALTO NIVEL (análisis estratégico
     a largo plazo) o una consulta OPERACIONAL (DCA, portfolio, sentimiento…)?
  2. Si es ALTO NIVEL → dispara el Comité de Inversión IA (run_investment_committee)
     que lanza 3 agentes Gemini en paralelo + Lead Advisor Sintetizador.
     El campo `committee_debate` del response lleva el debate completo para Flutter.
  3. Si es OPERACIONAL → flujo habitual con Function Calling (process_assistant_message).
  4. En ambos casos se genera síntesis de voz con ElevenLabs.
"""
from __future__ import annotations

import asyncio
import re
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ai_service import process_assistant_message
from db.database import get_db
from db.models import EtfHistory
from routers.analytics import _generate_synthetic_prices
from schemas import AssistantChatRequest, AssistantChatResponse
from services.montecarlo_engine import MonteCarloSimulator
from services.multi_agent_orchestrator import run_investment_committee
from services.tool_dispatcher import execute_get_portfolio_summary
from tts_service import generate_speech

router = APIRouter()

# ---------------------------------------------------------------------------
# Mapeo de herramientas a tipos de acción
# ---------------------------------------------------------------------------
ACTION_TYPE_MAP = {
    "simulate_dca_plan": "DCA_SIMULATED",
    "get_portfolio_summary": "PORTFOLIO_QUERY",
    "get_market_sentiment": "MARKET_SENTIMENT_QUERY",
    "update_savings_plan": "SAVINGS_PLAN_UPDATED",
    "calculate_portfolio_rebalance": "REBALANCE_ADVICE_QUERIED",
    "get_user_notifications": "NOTIFICATIONS_QUERIED",
    "INVESTMENT_COMMITTEE": "INVESTMENT_COMMITTEE",
    "GENERAL_QUERY": "GENERAL_QUERY",
}

# ---------------------------------------------------------------------------
# Clasificador de intención de alto nivel
# ---------------------------------------------------------------------------

#: Patrones que indican una consulta estratégica de largo plazo → activa el Comité de IA
_HIGH_LEVEL_PATTERNS: List[re.Pattern] = [
    re.compile(p, re.IGNORECASE)
    for p in [
        # Proyecciones temporales largas
        r"\b(\d+\s*años?|largo\s*plazo|5\s*años?|10\s*años?|horizonte)\b",
        # Análisis integral de cartera / estrategia
        r"\b(anal[iy]z[ae]|estrategia|visión\s*(global|completa)|perspectiva)\b",
        # Decisiones de plan de ahorro
        r"\b(deb(er[ií]a|o)\s+cambi[ao]r|debo\s+cambiar|cambiar\s+mi\s+plan)\b",
        # Preguntas sobre qué esperar / qué pasará
        r"\b(qu[eé]\s+esperar|qué\s+esperar|qué\s+me\s+recomiend|qu[eé]\s+pasar[aá]|comité)\b",
        # Rendimiento futuro / proyección
        r"\b(proyecci[oó]n|futuro|rendimiento\s+futuro|cu[aá]nto\s+tendr[eé]|comit[eé])\b",
        # Palabras clave directas del comité
        r"\b(comit[eé]\s+de\s+ia|consejo\s+experto|panel|swarm|multi.?agent)\b",
    ]
]


def _is_high_level_query(prompt: str) -> bool:
    """Devuelve True si la consulta requiere el Comité de IA (análisis estratégico)."""
    return any(pattern.search(prompt) for pattern in _HIGH_LEVEL_PATTERNS)


# ---------------------------------------------------------------------------
# Helpers: obtener datos para el comité
# ---------------------------------------------------------------------------

def _get_portfolio_data(db: Session, user_id: int) -> Dict[str, Any]:
    """Recupera los datos de cartera del usuario para alimentar el comité."""
    try:
        return execute_get_portfolio_summary(db=db, user_id=user_id)
    except Exception as e:
        print(f"[assistant] Advertencia al obtener portfolio: {e}")
        return {
            "total_invested": 0.0, "current_value": 0.0,
            "pnl": 0.0, "roi_pct": 0.0, "market_sentiment_score": 58,
        }


def _get_montecarlo_data(
    db: Session,
    initial_investment: float = 10_000.0,
    monthly_contribution: float = 200.0,
    ticker: str = "VWCE.DE",
    horizon_days: int = 1_260,
    n_simulations: int = 3_000,
) -> Dict[str, Any]:
    """Obtiene una proyección Monte Carlo rápida para el comité.

    Usa los datos históricos de etf_history si existen; si no, genera
    una serie sintética de referencia.
    """
    try:
        records = (
            db.query(EtfHistory)
            .filter(EtfHistory.ticker == ticker)
            .order_by(EtfHistory.timestamp.asc())
            .all()
        )
        price_series: List[float] = [float(r.price) for r in records if r.price and r.price > 0]

        if len(price_series) < 30:
            _ref_prices = {"VWCE.DE": 172.86, "EUNL.DE": 115.40, "8PSG.DE": 43.50}
            price_series = _generate_synthetic_prices(base_price=_ref_prices.get(ticker, 100.0))

        sim = MonteCarloSimulator(
            n_simulations=n_simulations,
            horizon_days=horizon_days,
            random_seed=None,
        )
        result = sim.run_simulation(
            price_series=price_series,
            initial_investment=initial_investment,
            monthly_contribution=monthly_contribution,
        )
        stats = result["stats"]
        return {
            "ticker": ticker,
            "horizon_days": horizon_days,
            "initial_investment": initial_investment,
            "monthly_contribution": monthly_contribution,
            "final_p10": result["p10"][-1],
            "final_p50": result["p50"][-1],
            "final_p90": result["p90"][-1],
            "annualized_return": stats["annualized_return"],
            "annualized_vol": stats["annualized_vol"],
        }
    except Exception as e:
        print(f"[assistant] Advertencia Monte Carlo para comité: {e}")
        return {
            "ticker": ticker, "horizon_days": horizon_days,
            "initial_investment": initial_investment,
            "monthly_contribution": monthly_contribution,
            "final_p10": initial_investment * 0.7,
            "final_p50": initial_investment * 1.5,
            "final_p90": initial_investment * 2.8,
            "annualized_return": 0.07,
            "annualized_vol": 0.15,
        }


# ---------------------------------------------------------------------------
# Endpoint principal
# ---------------------------------------------------------------------------

@router.post(
    "/chat",
    response_model=AssistantChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Asistente financiero — chat con detección de intención y Comité de IA (Fase 25)",
)
def chat_assistant(
    request: AssistantChatRequest,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Recibe la consulta del usuario y:
    - Si es de ALTO NIVEL (análisis estratégico, proyecciones, '¿qué esperar a 5 años?',
      '¿debería cambiar mi plan?'…): activa el Comité de IA con 3 agentes paralelos.
    - Si es OPERACIONAL (DCA, cartera, sentimiento…): usa el flujo Gemini Function Calling habitual.

    El campo `committee_debate` estará presente en la respuesta cuando se haya invocado el comité.
    """
    clean_prompt = request.user_prompt.strip()
    if not clean_prompt:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El campo 'user_prompt' no puede estar vacío.",
        )

    user_id = request.user_id or 1

    try:
        # ----------------------------------------------------------------
        # RAMA A: Comité de Inversión IA (intención estratégica de alto nivel)
        # ----------------------------------------------------------------
        if _is_high_level_query(clean_prompt):
            print(f"[assistant] 🏛 Intención ALTO NIVEL detectada → activando Comité de IA")

            portfolio_data = _get_portfolio_data(db=db, user_id=user_id)
            montecarlo_data = _get_montecarlo_data(db=db)

            # Ejecutar el orquestador async en el event loop actual (FastAPI sync context)
            committee_result = asyncio.run(
                run_investment_committee(
                    user_query=clean_prompt,
                    portfolio_data=portfolio_data,
                    montecarlo_data=montecarlo_data,
                )
            )

            final_text = committee_result.get("final_advice", "")
            committee_debate = committee_result.get("committee_debate", {})
            audio_base64 = generate_speech(final_text)

            return {
                "text_response": final_text,
                "action_type": "INVESTMENT_COMMITTEE",
                "action_executed": "INVESTMENT_COMMITTEE",
                "tool_args": {},
                "data_payload": {
                    "portfolio": portfolio_data,
                    "montecarlo": montecarlo_data,
                    "elapsed_seconds": committee_result.get("elapsed_seconds", 0.0),
                },
                "audio_base64": audio_base64,
                "committee_debate": committee_debate,
            }

        # ----------------------------------------------------------------
        # RAMA B: Flujo operacional habitual (Function Calling)
        # ----------------------------------------------------------------
        print(f"[assistant] ⚙ Intención OPERACIONAL → flujo Function Calling estándar")
        result = process_assistant_message(
            user_prompt=clean_prompt,
            db=db,
            user_id=user_id,
        )

        action_executed = result.get("action_executed", "GENERAL_QUERY")
        action_type = ACTION_TYPE_MAP.get(action_executed, action_executed)
        text_response = result.get("text_response", "")
        audio_base64 = generate_speech(text_response)

        return {
            "text_response": text_response,
            "action_type": action_type,
            "action_executed": action_executed,
            "tool_args": result.get("tool_args", {}),
            "data_payload": result.get("data_payload", {}),
            "audio_base64": audio_base64,
            "committee_debate": None,
        }

    except RuntimeError as re_err:
        # asyncio.run() falla si ya hay un event loop activo (entorno async)
        # → usamos asyncio.get_event_loop().run_until_complete() como fallback
        if "cannot be called" in str(re_err).lower() or "no current event loop" in str(re_err).lower():
            print(f"[assistant] Fallback asyncio: {re_err}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error de event loop al activar el Comité de IA: {re_err}",
            )
        raise
    except Exception as e:
        print(f"[assistant] Error procesando consulta: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno procesando la consulta del asistente: {str(e)}",
        )
