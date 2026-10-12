"""Suite de pruebas de integración para la Fase 15:
Sistema Proactivo de Alertas y Notificaciones Celery (FastAPI, SQLAlchemy, PostgreSQL, Celery).
Verifica:
1. Esquema OpenAPI y registro de endpoints de notificaciones.
2. Tarea Celery síncrona `check_portfolio_drift_task`: detección de descompensación (> 5%) y generación de alerta DRIFT.
3. Idempotencia de `check_portfolio_drift_task`: no duplica alertas DRIFT no leídas.
4. Tarea Celery síncrona `check_market_opportunities_task`: detección de caídas bruscas (< -3%) y generación de alerta OPPORTUNITY.
5. Idempotencia de `check_market_opportunities_task`: no duplica alertas OPPORTUNITY no leídas.
6. Endpoint REST GET /api/v1/notifications (listado ordenado cronológicamente).
7. Filtro unread_only=true en GET /api/v1/notifications.
8. Endpoint REST PATCH /api/v1/notifications/{id}/read para marcar notificaciones como leídas.
9. Manejo de error 404 al marcar una notificación inexistente.
"""
from datetime import datetime, timezone
import unittest
from fastapi.testclient import TestClient

from db.database import SessionLocal
from db.models import EtfHistory, Notification, NotificationType, Portfolio, Transaction, User
from db.seed import seed_demo_user
from main import app
from tasks import check_market_opportunities_task, check_portfolio_drift_task


class TestNotificationsPhase15(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.demo_user = seed_demo_user()
        cls.db = SessionLocal()

        # Asegurar que el usuario tiene un portfolio para los tests
        user = cls.db.query(User).filter((User.username == "demo") | (User.id == 1)).first()
        cls.user_id = user.id if user else 1

        portfolio = cls.db.query(Portfolio).filter(Portfolio.user_id == cls.user_id).first()
        if not portfolio:
            portfolio = Portfolio(
                user_id=cls.user_id,
                name="Cartera Test Alertas",
                currency="EUR",
                initial_balance=0.0,
            )
            cls.db.add(portfolio)
            cls.db.commit()
            cls.db.refresh(portfolio)
        cls.portfolio_id = portfolio.id

        # Insertar transacciones de prueba para forzar un drift crítico (>5%)
        # Por ejemplo: 95% Renta Variable vs 5% Oro (objetivo 80/20)
        # 10 acciones VWCE a 100€ (1000€) vs 1 acción 8PSG a 50€ (50€)
        cls.db.query(Transaction).filter(
            Transaction.portfolio_id == cls.portfolio_id,
            Transaction.external_tx_id.like("TEST-DRIFT-%")
        ).delete(synchronize_session=False)

        t1 = Transaction(
            portfolio_id=cls.portfolio_id,
            ticker="VWCE.DE",
            asset_class="EQUITY",
            shares=10.0,
            price_per_share=100.0,
            amount_invested=1000.0,
            external_tx_id="TEST-DRIFT-TX-1",
        )
        t2 = Transaction(
            portfolio_id=cls.portfolio_id,
            ticker="8PSG.DE",
            asset_class="GOLD",
            shares=1.0,
            price_per_share=50.0,
            amount_invested=50.0,
            external_tx_id="TEST-DRIFT-TX-2",
        )
        cls.db.add(t1)
        cls.db.add(t2)

        # Insertar registro histórico para test de oportunidades
        cls.db.query(EtfHistory).filter(EtfHistory.ticker == "DROP_TEST.DE").delete(synchronize_session=False)
        drop_record = EtfHistory(
            ticker="DROP_TEST.DE",
            price=92.50,
            change_percent=-4.85,  # Caída severa > 3%
            sentiment_score=35,
            ai_summary="Fuerte ajuste bajista de mercado",
        )
        cls.db.add(drop_record)

        # Limpiar notificaciones previas de tests
        cls.db.query(Notification).filter(Notification.user_id == cls.user_id).delete(synchronize_session=False)
        cls.db.commit()

    @classmethod
    def tearDownClass(cls):
        # Limpieza de registros creados en las pruebas
        cls.db.query(Transaction).filter(
            Transaction.external_tx_id.like("TEST-DRIFT-%")
        ).delete(synchronize_session=False)
        cls.db.query(EtfHistory).filter(EtfHistory.ticker == "DROP_TEST.DE").delete(synchronize_session=False)
        cls.db.query(Notification).filter(Notification.user_id == cls.user_id).delete(synchronize_session=False)
        cls.db.commit()
        cls.db.close()

    def test_01_openapi_schema_notifications(self):
        """Verifica que los endpoints de notificaciones están expuestos en OpenAPI."""
        response = self.client.get("/openapi.json")
        self.assertEqual(response.status_code, 200)
        paths = response.json().get("paths", {})
        self.assertIn("/api/v1/notifications", paths)
        self.assertIn("/api/v1/notifications/{id}/read", paths)
        print("[OK] test_01: Endpoints de notificaciones expuestos en OpenAPI.")

    def test_02_celery_task_check_portfolio_drift_synchronous(self):
        """Ejecuta síncronamente check_portfolio_drift_task y valida la creación de alerta DRIFT."""
        result = check_portfolio_drift_task(drift_threshold_pct=5.0, db=self.db)
        self.assertEqual(result["status"], "completed")
        self.assertGreaterEqual(result["notifications_created"], 1)

        # Comprobar en base de datos
        drift_notif = (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.type == NotificationType.DRIFT,
                Notification.is_read.is_(False),
            )
            .first()
        )
        self.assertIsNotNone(drift_notif)
        self.assertIn("Desviación", drift_notif.title)
        self.assertIn("VWCE.DE", drift_notif.message)
        print(f"[OK] test_02: check_portfolio_drift_task generó alerta DRIFT id={drift_notif.id}.")

    def test_03_celery_task_drift_idempotency(self):
        """Verifica que invocar check_portfolio_drift_task de nuevo no duplica alertas no leídas."""
        result = check_portfolio_drift_task(drift_threshold_pct=5.0, db=self.db)
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["notifications_created"], 0, "No debe duplicar alerta si ya existe una no leída.")

        unread_count = (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.type == NotificationType.DRIFT,
                Notification.is_read.is_(False),
            )
            .count()
        )
        self.assertEqual(unread_count, 1)
        print("[OK] test_03: Idempotencia en check_portfolio_drift_task verificada (0 duplicados).")

    def test_04_celery_task_market_opportunities_synchronous(self):
        """Ejecuta check_market_opportunities_task detectando caída > 3% e inserta OPPORTUNITY."""
        result = check_market_opportunities_task(
            drop_threshold_pct=-3.0,
            tickers=["DROP_TEST.DE"],
            db=self.db,
        )
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["opportunities_found"], 1)
        self.assertGreaterEqual(result["notifications_created"], 1)

        opp_notif = (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.type == NotificationType.OPPORTUNITY,
                Notification.is_read.is_(False),
            )
            .first()
        )
        self.assertIsNotNone(opp_notif)
        self.assertIn("DROP_TEST.DE", opp_notif.title)
        self.assertIn("-4.85%", opp_notif.message)
        print(f"[OK] test_04: check_market_opportunities_task generó alerta OPPORTUNITY id={opp_notif.id}.")

    def test_05_celery_task_market_opportunities_idempotency(self):
        """Verifica que invocar check_market_opportunities_task de nuevo no duplica la alerta."""
        result = check_market_opportunities_task(
            drop_threshold_pct=-3.0,
            tickers=["DROP_TEST.DE"],
            db=self.db,
        )
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["notifications_created"], 0)
        print("[OK] test_05: Idempotencia en check_market_opportunities_task verificada.")

    def test_06_http_get_notifications_list(self):
        """Verifica GET /api/v1/notifications devolviendo la lista ordenada cronológicamente."""
        response = self.client.get(f"/api/v1/notifications?user_id={self.user_id}")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIsInstance(data, list)
        self.assertGreaterEqual(len(data), 2)

        types_found = {item["type"] for item in data}
        self.assertIn("DRIFT", types_found)
        self.assertIn("OPPORTUNITY", types_found)

        # Validar campos de NotificationResponse
        first = data[0]
        self.assertIn("id", first)
        self.assertIn("user_id", first)
        self.assertIn("title", first)
        self.assertIn("message", first)
        self.assertIn("type", first)
        self.assertIn("is_read", first)
        self.assertIn("timestamp", first)

        # Validar orden cronológico descendente
        timestamps = [item["timestamp"] for item in data]
        self.assertEqual(timestamps, sorted(timestamps, reverse=True))
        print(f"[OK] test_06: GET /api/v1/notifications retornó {len(data)} alertas ordenadas cronológicamente.")

    def test_07_http_get_notifications_unread_only(self):
        """Verifica el filtro `unread_only=true` en GET /api/v1/notifications."""
        response = self.client.get(f"/api/v1/notifications?user_id={self.user_id}&unread_only=true")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        for item in data:
            self.assertFalse(item["is_read"])
        print(f"[OK] test_07: GET /api/v1/notifications con unread_only=true validado ({len(data)} no leídas).")

    def test_08_http_patch_mark_as_read(self):
        """Verifica PATCH /api/v1/notifications/{id}/read actualizando is_read a True."""
        # Obtener primera notificación no leída
        unread_notif = (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.is_read.is_(False),
            )
            .first()
        )
        self.assertIsNotNone(unread_notif)
        notif_id = unread_notif.id

        response = self.client.patch(f"/api/v1/notifications/{notif_id}/read")
        self.assertEqual(response.status_code, 200)
        updated = response.json()
        self.assertEqual(updated["id"], notif_id)
        self.assertTrue(updated["is_read"])

        # Verificar en base de datos
        self.db.expire_all()
        refreshed = self.db.query(Notification).filter(Notification.id == notif_id).first()
        self.assertTrue(refreshed.is_read)
        print(f"[OK] test_08: PATCH /api/v1/notifications/{notif_id}/read marcó correctamente is_read=True.")

    def test_09_http_patch_not_found(self):
        """Verifica error 404 al marcar una notificación inexistente."""
        response = self.client.patch("/api/v1/notifications/999999/read")
        self.assertEqual(response.status_code, 404)
        self.assertIn("no encontrada", response.json().get("detail", ""))
        print("[OK] test_09: PATCH con ID inexistente devolvió 404 Not Found como se esperaba.")


if __name__ == "__main__":
    unittest.main()
