import os
import time
from typing import Any, Dict, List, Optional
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ai_service import analyze_sentiment
from cleanup_history import cleanup_fallback_records
from db import EtfHistory, get_db, seed_demo_user
from routers.assistant import router as assistant_router
from routers.banking import router as banking_router
from routers.fintech import router as fintech_router
from routers.notifications import router as notifications_router
from scraper import get_ticker_data
from tts_service import generate_speech

app = FastAPI(
    title="Smart Market Sentiment & ETF Dashboard API",
    description="API REST para análisis de sentimiento, cotizaciones en tiempo real, persistencia histórica en PostgreSQL, Asistente Financiero, Open Banking y Sistema de Alertas",
    version="5.0.0",
)

# Configuración de CORS para permitir conexiones desde Flutter (Web, Móvil, Desktop)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusión de routers: Fintech / DCA, Asistente Multimodal, Open Banking y Notificaciones
app.include_router(fintech_router, prefix="/api/v1/fintech", tags=["Fintech & Portfolio"])
app.include_router(assistant_router, prefix="/api/v1/assistant", tags=["Assistant & NLP"])
app.include_router(banking_router, prefix="/api/v1/banking", tags=["Open Banking"])
app.include_router(notifications_router, prefix="/api/v1/notifications", tags=["Notifications & Alerts"])



@app.on_event("startup")
def startup_event() -> None:
    """Evento de inicio: limpia registros planos y asegura que el usuario demo existe."""
    try:
        deleted = cleanup_fallback_records()
        if deleted > 0:
            print(f"[startup] Limpieza inicial: {deleted} registros planos eliminados de etf_history.")
    except Exception as e:
        print(f"[startup] Advertencia durante la limpieza inicial: {e}")

    try:
        seed_demo_user()
    except Exception as e:
        print(f"[startup] Advertencia durante el seeding del usuario Demo: {e}")


# ============================================================================
# CAPA DE PROTECCIÓN: Caché en memoria con Time-To-Live (TTL) de 5 minutos
# Evita sobrepasar límites de cuota (ResourceExhausted / 429) en Gemini y ElevenLabs
# ============================================================================
CACHE_TTL_SECONDS = 300  # 5 minutos
_sentiment_cache: Dict[str, Dict[str, Any]] = {}


class SentimentResponse(BaseModel):
    ticker: str = Field(..., description="Símbolo del ETF / activo financiero", examples=["VWCE.DE"])
    current_price: float = Field(..., description="Precio actual de mercado", examples=[172.86])
    change_percent: float = Field(..., description="Variación porcentual diaria", examples=[0.56])
    currency: str = Field(default="EUR", description="Moneda de cotización", examples=["EUR"])
    sentiment_score: int = Field(
        ...,
        ge=0,
        le=100,
        description="Puntuación de sentimiento entre 0 (muy bajista) y 100 (muy alcista)",
        examples=[52],
    )
    ai_summary: str = Field(
        ...,
        description="Resumen narrativo conciso generado por Gemini",
        examples=["Mercado en consolidación tras recientes ajustes en tecnológicas."],
    )
    news: List[str] = Field(
        default_factory=list,
        description="Lista de los últimos titulares analizados",
    )
    audio_base64: Optional[str] = Field(
        default=None,
        description="Audio narrado (Flash Briefing) codificado en base64 generado por ElevenLabs",
    )
    cached: bool = Field(
        default=False,
        description="Indica si la respuesta proviene de la memoria caché",
    )


class HistoryItemResponse(BaseModel):
    id: Optional[int] = Field(None, description="Identificador único del registro")
    ticker: str = Field(..., description="Símbolo del ETF")
    price: float = Field(..., description="Precio de cotización registrado")
    change_percent: float = Field(..., description="Variación porcentual registrada")
    sentiment_score: int = Field(..., description="Puntuación de sentimiento asignada")
    ai_summary: str = Field(..., description="Resumen narrativo del análisis")
    timestamp: Optional[str] = Field(None, description="Fecha y hora del registro ISO 8601")


@app.get("/", tags=["Health"])
def root() -> Dict[str, Any]:
    """Endpoint raíz de bienvenida y estado del servicio."""
    return {
        "status": "healthy",
        "service": "Smart Market Sentiment API",
        "version": "2.1.0",
        "cache_entries": len(_sentiment_cache),
        "cache_ttl_seconds": CACHE_TTL_SECONDS,
        "docs_url": "/docs",
    }


@app.delete("/api/v1/cache", tags=["Cache"], summary="Limpia la caché en memoria del backend")
def clear_cache() -> Dict[str, str]:
    """Vacía las entradas en caché para forzar nuevas consultas inmediatas."""
    count = len(_sentiment_cache)
    _sentiment_cache.clear()
    return {"message": f"Caché limpiada con éxito ({count} entradas eliminadas)."}


@app.delete(
    "/api/v1/history/cleanup",
    tags=["History"],
    summary="Elimina registros históricos planos generados por caídas temporales de cuota",
)
def cleanup_history() -> Dict[str, Any]:
    """Elimina de PostgreSQL los registros que contengan avisos de cuota saturada."""
    deleted = cleanup_fallback_records()
    return {
        "status": "success",
        "deleted_count": deleted,
        "message": f"Se eliminaron {deleted} registros artificiales de la base de datos.",
    }


@app.get(
    "/api/v1/history/{ticker}",
    response_model=List[HistoryItemResponse],
    tags=["History"],
    summary="Obtiene el histórico de cotizaciones y sentimiento registrado en PostgreSQL",
)
def get_ticker_history(
    ticker: str,
    limit: int = 50,
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """Consulta la tabla etf_history para devolver las mediciones históricas ordenadas
    cronológicamente descendente para un ticker.
    """
    clean_ticker = ticker.strip().upper()
    records = (
        db.query(EtfHistory)
        .filter(EtfHistory.ticker == clean_ticker)
        .order_by(EtfHistory.timestamp.desc())
        .limit(limit)
        .all()
    )
    return [r.to_dict() for r in records]


@app.get(
    "/api/v1/sentiment/{ticker}",
    response_model=SentimentResponse,
    tags=["Sentiment"],
    summary="Obtiene cotización, análisis de sentimiento y narración TTS de un ETF",
)
def get_sentiment(
    ticker: str,
    force_refresh: bool = False,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Orquesta la extracción de datos de mercado (yfinance), el análisis de
    sentimiento con IA (Google GenAI) y la narración de audio (ElevenLabs).
    Persiste en PostgreSQL solo cuando el análisis es legítimo (evita ensuciar la BD ante 429).
    """
    clean_ticker = ticker.strip().upper()
    if not clean_ticker:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar un símbolo de ticker válido.",
        )

    now = time.time()

    # 1. Comprobar caché en memoria si no se fuerza la recarga
    if not force_refresh and clean_ticker in _sentiment_cache:
        cached_entry = _sentiment_cache[clean_ticker]
        age = now - cached_entry.get("timestamp", 0)
        if age < CACHE_TTL_SECONDS:
            print(
                f"[cache] HIT para {clean_ticker} (edad: {int(age)}s / TTL: {CACHE_TTL_SECONDS}s). "
                f"Retornando respuesta en memoria sin consultar Gemini."
            )
            data = dict(cached_entry["payload"])
            data["cached"] = True
            return data
        else:
            print(f"[cache] EXPIRED para {clean_ticker} (edad: {int(age)}s). Renovando datos.")

    try:
        # 2. Extracción de cotización y noticias mediante scraper.py
        market_data = get_ticker_data(clean_ticker)

        # 3. Análisis de sentimiento de los titulares mediante ai_service.py
        sentiment_result = analyze_sentiment(market_data.get("news", []))
        ai_summary = sentiment_result.get("ai_summary", "")

        # 4. Generación de síntesis de voz (Flash Briefing) con ElevenLabs
        audio_base64 = generate_speech(ai_summary) if ai_summary else None

        # 5. Persistencia en Base de Datos PostgreSQL (solo si NO es aviso de cuota saturada)
        is_quota_fallback = (
            "Límite temporal de peticiones" in ai_summary
            or "GEMINI_API_KEY no configurada" in ai_summary
            or "RESOURCE_EXHAUSTED" in ai_summary
        )

        if not is_quota_fallback:
            try:
                history_record = EtfHistory(
                    ticker=market_data["ticker"],
                    price=market_data["current_price"],
                    change_percent=market_data["change_percent"],
                    sentiment_score=sentiment_result["sentiment_score"],
                    ai_summary=ai_summary,
                )
                db.add(history_record)
                db.commit()
                db.refresh(history_record)
                print(f"[db] Registro histórico real guardado en PostgreSQL (ID: {history_record.id}) para {clean_ticker}")
            except Exception as db_err:
                db.rollback()
                print(f"[db] Advertencia al persistir registro en PostgreSQL para {clean_ticker}: {db_err}")
        else:
            print(f"[db] Omitiendo guardado en base de datos para {clean_ticker}: respuesta temporal por saturación de cuota.")

        # 6. Respuesta unificada
        response_payload = {
            "ticker": market_data["ticker"],
            "current_price": market_data["current_price"],
            "change_percent": market_data["change_percent"],
            "currency": market_data["currency"],
            "sentiment_score": sentiment_result["sentiment_score"],
            "ai_summary": ai_summary,
            "news": market_data.get("news", []),
            "audio_base64": audio_base64,
            "cached": False,
        }

        # 7. Almacenar en caché en memoria
        _sentiment_cache[clean_ticker] = {
            "timestamp": now,
            "payload": response_payload,
        }

        return response_payload

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error procesando el análisis para '{clean_ticker}': {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
