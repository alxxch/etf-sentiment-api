import logging
import time
from typing import Any, Dict, List
from ai_service import GeminiRateLimitException, analyze_sentiment
from celery_app import celery_app
from db import EtfHistory, SessionLocal
from scraper import get_ticker_data

logger = logging.getLogger(__name__)

# Lista de ETFs objetivo para el análisis diario de mercado
TARGET_ETFS = ["VWCE.DE", "EUNL.DE", "8PSG.DE"]

# Tiempo de espera (en segundos) entre tickers para evitar saturar el Rate Limit
DELAY_BETWEEN_TICKERS_SECONDS = 25


@celery_app.task(
    name="tasks.analyze_daily_market",
    bind=True,
    max_retries=3,
)
def analyze_daily_market(self) -> Dict[str, Any]:
    """Tarea programada de Celery para cierre de mercado con control de flujo y Exponential Backoff.
    Itera sobre los ETFs con pausas de 25s entre tickers. Si se recibe un error 429
    (ResourceExhausted / Rate Limit), eleva un self.retry con espera exponencial (60s, 120s, 240s)
    en lugar de guardar puntuaciones artificiales.
    """
    logger.info(
        f"[Celery] Iniciando analyze_daily_market (intento {self.request.retries + 1}/{self.max_retries + 1}) "
        f"para ETFs: {TARGET_ETFS}"
    )
    results: List[Dict[str, Any]] = []
    db = SessionLocal()

    try:
        for idx, ticker in enumerate(TARGET_ETFS):
            # Control de flujo: dar respiro a la API entre consultas consecutivas
            if idx > 0:
                logger.info(
                    f"[Celery] Aplicando control de flujo: esperando {DELAY_BETWEEN_TICKERS_SECONDS}s "
                    f"antes de procesar {ticker}..."
                )
                time.sleep(DELAY_BETWEEN_TICKERS_SECONDS)

            logger.info(f"[Celery] Procesando ticker: {ticker}")
            try:
                # 1. Extracción de cotización y titulares
                market_data = get_ticker_data(ticker)

                # 2. Análisis con raise_on_quota=True para detectar cuota 429
                sentiment_result = analyze_sentiment(
                    market_data.get("news", []),
                    raise_on_quota=True,
                )
                ai_summary = sentiment_result.get("ai_summary", "")

                # 3. Persistencia en la tabla etf_history (solo datos reales)
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
                    f"[Celery] {ticker} guardado con éxito (ID: {history_record.id}, "
                    f"Precio: {history_record.price}, Score: {history_record.sentiment_score})"
                )
                results.append({
                    "ticker": ticker,
                    "status": "success",
                    "id": history_record.id,
                    "price": history_record.price,
                    "sentiment_score": history_record.sentiment_score,
                })

            except GeminiRateLimitException as quota_err:
                db.rollback()
                countdown_seconds = (2 ** self.request.retries) * 60
                logger.warning(
                    f"[Celery] Cuota agotada (429) procesando {ticker}. "
                    f"Reintentando en {countdown_seconds}s (intento {self.request.retries + 1}/{self.max_retries}). "
                    f"Detalle: {quota_err}"
                )
                # Reintento exponencial sin guardar valores artificiales en la base de datos
                raise self.retry(exc=quota_err, countdown=countdown_seconds)

            except Exception as item_err:
                db.rollback()
                logger.error(f"[Celery] Error procesando ticker {ticker}: {item_err}", exc_info=True)
                results.append({
                    "ticker": ticker,
                    "status": "error",
                    "error": str(item_err),
                })

        logger.info(f"[Celery] analyze_daily_market finalizado con {len(results)} activos procesados.")
        return {
            "status": "completed",
            "processed_count": len(results),
            "details": results,
        }

    finally:
        db.close()
