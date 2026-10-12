import logging
import time
from typing import Any, Dict, List, Optional
from ai_service import GeminiRateLimitException, analyze_sentiment
from celery_app import celery_app
from db import EtfHistory, Notification, NotificationType, SessionLocal, User
from scraper import get_ticker_data
from services.rebalance_engine import get_portfolio_rebalance_advice

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


@celery_app.task(
    name="tasks.check_portfolio_drift_task",
    max_retries=2,
)
def check_portfolio_drift_task(
    drift_threshold_pct: float = 5.0,
    db: Optional[Any] = None,
) -> Dict[str, Any]:
    """Tarea Celery periódica (Fase 15): analiza el Portfolio Drift de cada usuario
    usando el motor cuantitativo de rebalanceo (rebalance_engine.py).
    Si la desviación porcentual (|drift_pct|) de algún activo supera el umbral crítico
    (por defecto > 5.0%), inserta un registro en Notification de tipo DRIFT.
    """
    close_db_on_exit = False
    if db is None:
        db = SessionLocal()
        close_db_on_exit = True

    notifications_created = 0
    users_checked = 0
    details: List[Dict[str, Any]] = []

    try:
        users = db.query(User).all()
        for user in users:
            users_checked += 1
            if not user.portfolio:
                continue

            try:
                advice = get_portfolio_rebalance_advice(portfolio_id=user.portfolio.id, db=db)
                assets = advice.get("assets", [])
                critical_assets = [
                    a for a in assets
                    if abs(float(a.get("drift_pct", 0.0))) >= drift_threshold_pct
                ]

                if critical_assets:
                    # Evitar duplicar alertas DRIFT no leídas para este usuario
                    existing_unread = (
                        db.query(Notification)
                        .filter(
                            Notification.user_id == user.id,
                            Notification.type == NotificationType.DRIFT,
                            Notification.is_read == False,
                        )
                        .first()
                    )

                    if not existing_unread:
                        drift_desc = ", ".join([
                            f"{a.get('ticker')} ({a.get('drift_pct', 0.0):+.1f}%)"
                            for a in critical_assets
                        ])
                        notif = Notification(
                            user_id=user.id,
                            title="Desviación de Cartera Detectada",
                            message=(
                                f"Se ha detectado una descompensación superior al {drift_threshold_pct}% en tu cartera: "
                                f"{drift_desc}. Se recomienda rebalancear con tu próxima aportación mensual."
                            ),
                            type=NotificationType.DRIFT,
                            is_read=False,
                        )
                        db.add(notif)
                        db.commit()
                        db.refresh(notif)
                        notifications_created += 1
                        details.append({
                            "user_id": user.id,
                            "notification_id": notif.id,
                            "critical_assets": [a.get("ticker") for a in critical_assets],
                        })
            except Exception as user_err:
                logger.error(f"[Celery] Error evaluando drift para user_id {user.id}: {user_err}")
                db.rollback()

        logger.info(
            f"[Celery] check_portfolio_drift_task completado: {users_checked} usuarios revisados, "
            f"{notifications_created} notificaciones creadas."
        )
        return {
            "status": "completed",
            "users_checked": users_checked,
            "notifications_created": notifications_created,
            "details": details,
        }
    finally:
        if close_db_on_exit:
            db.close()


@celery_app.task(
    name="tasks.check_market_opportunities_task",
    max_retries=2,
)
def check_market_opportunities_task(
    drop_threshold_pct: float = -3.0,
    tickers: Optional[List[str]] = None,
    db: Optional[Any] = None,
) -> Dict[str, Any]:
    """Tarea Celery periódica (Fase 15): detecta caídas bruscas en ETFs rastreados
    (ej: caída >= 3% respecto a la jornada anterior, drop_threshold_pct <= -3.0%).
    Genera un registro en Notification de tipo OPPORTUNITY sugiriendo aprovechar la rebaja.
    """
    close_db_on_exit = False
    if db is None:
        db = SessionLocal()
        close_db_on_exit = True

    target_list = tickers or TARGET_ETFS
    notifications_created = 0
    opportunities_found: List[Dict[str, Any]] = []

    try:
        users = db.query(User).all()
        if not users:
            return {
                "status": "completed",
                "opportunities_found": 0,
                "notifications_created": 0,
            }

        for ticker in target_list:
            change_percent = None
            current_price = None

            # 1. Intentar obtener cotización live
            try:
                market_data = get_ticker_data(ticker)
                # Si get_ticker_data no encuentra datos del activo, devuelve 0.0
                if market_data.get("current_price", 0.0) > 0:
                    change_percent = market_data.get("change_percent")
                    current_price = market_data.get("current_price")
            except Exception as e:
                logger.warning(f"[Celery] No se pudo obtener cotización live para {ticker}: {e}")

            # 2. Si no hay datos live válidos, consultar último registro en etf_history
            if change_percent is None or current_price is None or current_price == 0.0:
                last_hist = (
                    db.query(EtfHistory)
                    .filter(EtfHistory.ticker == ticker)
                    .order_by(EtfHistory.timestamp.desc())
                    .first()
                )
                if last_hist:
                    change_percent = last_hist.change_percent
                    current_price = last_hist.price

            # 3. Evaluar si la caída supera el umbral (ej: <= -3.0%)
            threshold = -abs(drop_threshold_pct)
            if change_percent is not None and change_percent <= threshold:
                opportunities_found.append({
                    "ticker": ticker,
                    "change_percent": change_percent,
                    "current_price": current_price,
                })

                price_str = f"{current_price:.2f}€" if current_price is not None else "precio de mercado"
                msg_text = (
                    f"El ETF {ticker} ha registrado una caída de {change_percent:+.2f}% "
                    f"(precio actual: {price_str}). Es una excelente oportunidad para acumular "
                    f"posiciones a precio rebajado en tu próxima aportación DCA."
                )

                for user in users:
                    # Evitar duplicar alertas OPPORTUNITY no leídas del mismo ticker
                    existing = (
                        db.query(Notification)
                        .filter(
                            Notification.user_id == user.id,
                            Notification.type == NotificationType.OPPORTUNITY,
                            Notification.title.like(f"%{ticker}%"),
                            Notification.is_read == False,
                        )
                        .first()
                    )
                    if not existing:
                        notif = Notification(
                            user_id=user.id,
                            title=f"Oportunidad de Compra: {ticker}",
                            message=msg_text,
                            type=NotificationType.OPPORTUNITY,
                            is_read=False,
                        )
                        db.add(notif)
                        db.commit()
                        db.refresh(notif)
                        notifications_created += 1

        logger.info(
            f"[Celery] check_market_opportunities_task completado: "
            f"{len(opportunities_found)} oportunidades encontradas, {notifications_created} notificaciones creadas."
        )
        return {
            "status": "completed",
            "opportunities_found": len(opportunities_found),
            "notifications_created": notifications_created,
            "details": opportunities_found,
        }
    finally:
        if close_db_on_exit:
            db.close()

