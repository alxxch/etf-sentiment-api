import os
from typing import Any, Dict, List
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ai_service import analyze_sentiment
from scraper import get_ticker_data

app = FastAPI(
    title="Smart Market Sentiment & ETF Dashboard API",
    description="API REST para análisis de sentimiento y cotizaciones de ETFs en tiempo real con Gemini",
    version="1.0.0",
)

# Configuración de CORS para permitir conexiones desde Flutter (Web, Móvil, Desktop)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


@app.get("/", tags=["Health"])
def root() -> Dict[str, str]:
    """Endpoint raíz de bienvenida y estado del servicio."""
    return {
        "status": "healthy",
        "service": "Smart Market Sentiment API",
        "version": "1.0.0",
        "docs_url": "/docs",
    }


@app.get(
    "/api/v1/sentiment/{ticker}",
    response_model=SentimentResponse,
    tags=["Sentiment"],
    summary="Obtiene cotización y análisis de sentimiento de un ETF",
)
def get_sentiment(ticker: str) -> Dict[str, Any]:
    """Orquesta la extracción de datos de mercado (yfinance) y el análisis de

    sentimiento con IA (Gemini) para un ticker dado.
    """
    clean_ticker = ticker.strip().upper()
    if not clean_ticker:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar un símbolo de ticker válido.",
        )

    try:
        # 1. Extracción de cotización y noticias mediante scraper.py
        market_data = get_ticker_data(clean_ticker)

        # 2. Análisis de sentimiento de los titulares mediante ai_service.py
        sentiment_result = analyze_sentiment(market_data.get("news", []))

        # 3. Respuesta unificada
        return {
            "ticker": market_data["ticker"],
            "current_price": market_data["current_price"],
            "change_percent": market_data["change_percent"],
            "currency": market_data["currency"],
            "sentiment_score": sentiment_result["sentiment_score"],
            "ai_summary": sentiment_result["ai_summary"],
            "news": market_data.get("news", []),
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error procesando el análisis para '{clean_ticker}': {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
