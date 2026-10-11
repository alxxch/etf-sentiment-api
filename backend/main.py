import os
import time
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ai_service import analyze_sentiment
from scraper import get_ticker_data
from tts_service import generate_speech

app = FastAPI(
    title="Smart Market Sentiment & ETF Dashboard API",
    description="API REST para análisis de sentimiento y cotizaciones de ETFs en tiempo real con Gemini y ElevenLabs TTS",
    version="1.5.1",
)

# Configuración de CORS para permitir conexiones desde Flutter (Web, Móvil, Desktop)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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


@app.get("/", tags=["Health"])
def root() -> Dict[str, Any]:
    """Endpoint raíz de bienvenida y estado del servicio."""
    return {
        "status": "healthy",
        "service": "Smart Market Sentiment API",
        "version": "1.5.1",
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


@app.get(
    "/api/v1/sentiment/{ticker}",
    response_model=SentimentResponse,
    tags=["Sentiment"],
    summary="Obtiene cotización, análisis de sentimiento y narración TTS de un ETF",
)
def get_sentiment(ticker: str, force_refresh: bool = False) -> Dict[str, Any]:
    """Orquesta la extracción de datos de mercado (yfinance), el análisis de

    sentimiento con IA (Gemini) y la narración de audio (ElevenLabs).
    Implementa protección de caché en memoria de 5 minutos para evitar agotar cuotas.
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

        # 5. Respuesta unificada
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

        # 6. Almacenar en caché en memoria
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
