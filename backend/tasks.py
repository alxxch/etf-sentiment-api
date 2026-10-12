import logging
from typing import Any, Dict, List
from ai_service import analyze_sentiment
from celery_app import celery_app
from db import EtfHistory, SessionLocal
from scraper import get_ticker_data

logger = logging.getLogger(__name__)

# Lista de ETFs objetivo para el análisis diario de mercado
TARGET_ETFS = ["VWCE.DE", "EUNL.DE", "8PSG.DE"]


@celery_app.task(name="tasks.analyze_daily_market", bind=True)
def analyze_daily_market(self) -> Dict[str, Any]:
    """Tarea programada de Celery para cierre de mercado.
    Itera sobre los ETFs principales, ejecuta el scraper de mercado,
    analiza el sentimiento con Gemini y persiste el resultado en PostgreSQL (etf_history).
    """
    logger.info(f"[Celery] Iniciando analyze_daily_market para ETFs: {TARGET_ETFS}")
    results: List[Dict[str, Any]] = []
    db = SessionLocal()

    try:
        for ticker in TARGET_ETFS:
            logger.info(f"[Celery] Procesando ticker: {ticker}")
            try:
                # 1. Extracción de cotización y titulares
                market_data = get_ticker_data(ticker)

                # 2. Análisis de sentimiento de mercado mediante IA
                sentiment_result = analyze_sentiment(market_data.get("news", []))
                ai_summary = sentiment_result.get("ai_summary", "")

                # 3. Persistencia en la tabla etf_history
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

                logger.info(
                    f"[Celery] {ticker} guardado exitosamente con ID {history_record.id} "
                    f"(Precio: {history_record.price}, Score: {history_record.sentiment_score})"
                )
                results.append({
                    "ticker": ticker,
                    "status": "success",
                    "id": history_record.id,
                    "price": history_record.price,
                    "sentiment_score": history_record.sentiment_score,
                })

            except Exception as item_err:
                db.rollback()
                logger.error(f"[Celery] Error procesando ticker {ticker}: {item_err}", exc_info=True)
                results.append({
                    "ticker": ticker,
                    "status": "error",
                    "error": str(item_err),
                })

        logger.info(f"[Celery] analyze_daily_market finalizado. Total procesados: {len(results)}")
        return {
            "status": "completed",
            "processed_count": len(results),
            "details": results,
        }

    finally:
        db.close()
