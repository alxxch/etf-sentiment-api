"""Suite de pruebas de integración para la Fase 13:
Pasarela de Open Banking & Conectividad con Brokers (FastAPI, SQLAlchemy, PostgreSQL/SQLite).
Verifica:
1. Esquemas OpenAPI / Swagger para Open Banking.
2. Vinculación de cuentas de brokers externos (POST /api/v1/banking/link-account).
3. Consulta de brokers conectados por usuario (GET /api/v1/banking/accounts).
4. Sincronización bajo demanda e inyección de transacciones (POST /api/v1/banking/sync/{account_id}).
5. Idempotencia estricta mediante external_tx_id (re-sincronizaciones no duplican operaciones ni saldo).
6. Manejo de errores (cuentas inexistentes 404 y brokers no soportados 400).
"""
import unittest
from datetime import datetime
from fastapi.testclient import TestClient

from db.database import SessionLocal
from db.models import BrokerAccount, Portfolio, SyncStatus, Transaction, User
from db.seed import seed_demo_user
from main import app
from services.broker_service import TradeRepublicAdapter, get_broker_adapter


class TestBankingPhase13(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        # Asegurar que el usuario Demo existe para las pruebas
        seed_demo_user()
        cls.db = SessionLocal()

    @classmethod
    def tearDownClass(cls):
        # Limpiar datos de prueba creados en la suite
        cls.db.query(BrokerAccount).filter(
            BrokerAccount.account_reference.like("TR-TEST-%")
        ).delete(synchronize_session=False)
        cls.db.query(Transaction).filter(
            Transaction.external_tx_id.like("TR-TX-%")
        ).delete(synchronize_session=False)
        cls.db.commit()
        cls.db.close()

    def test_01_openapi_schema_banking_endpoints(self):
        """Verifica que los endpoints de Open Banking están registrados en OpenAPI."""
        response = self.client.get("/openapi.json")
        self.assertEqual(response.status_code, 200)
        paths = response.json().get("paths", {})
        self.assertIn("/api/v1/banking/link-account", paths)
        self.assertIn("/api/v1/banking/sync/{account_id}", paths)
        self.assertIn("/api/v1/banking/accounts", paths)
        print("[OK] test_01: Endpoints de Open Banking verificados en el esquema OpenAPI.")

    def test_02_adapter_pattern_trade_republic(self):
        """Valida directamente la implementación del TradeRepublicAdapter."""
        adapter = get_broker_adapter("Trade Republic")
        self.assertIsInstance(adapter, TradeRepublicAdapter)

        # Balance estructurado
        balance = adapter.get_portfolio_balance("TR-TEST-001")
        self.assertIn("cash_balance", balance)
        self.assertIn("total_value", balance)
        self.assertEqual(balance["currency"], "EUR")

        # Transacciones unificadas
        txs = adapter.get_transactions("TR-TEST-001")
        self.assertIsInstance(txs, list)
        self.assertGreater(len(txs), 0)
        for tx in txs:
            self.assertIn("external_tx_id", tx)
            self.assertIn("ticker", tx)
            self.assertIn("asset_class", tx)
            self.assertIn("shares", tx)
            self.assertIn("price_per_share", tx)
            self.assertIn("amount_invested", tx)
            self.assertIn("broker_fee", tx)
            self.assertIn("currency", tx)
        print(f"[OK] test_02: TradeRepublicAdapter funcional ({len(txs)} transacciones mock unificadas).")

    def test_03_link_broker_account(self):
        """Verifica el endpoint POST /api/v1/banking/link-account."""
        demo_user = self.db.query(User).filter(User.username == "demo").first()
        self.assertIsNotNone(demo_user)

        payload = {
            "broker_name": "Trade Republic",
            "account_reference": "TR-TEST-LINK-99",
            "user_id": demo_user.id,
        }
        response = self.client.post("/api/v1/banking/link-account", json=payload)
        self.assertEqual(response.status_code, 201)
        data = response.json()

        self.assertIn("id", data)
        self.assertEqual(data["broker_name"], "Trade Republic")
        self.assertEqual(data["account_reference"], "TR-TEST-LINK-99")
        self.assertEqual(data["sync_status"], "PENDING")
        self.assertIsNone(data["last_synced_at"])
        print(f"[OK] test_03: Broker vinculado con éxito (ID: {data['id']}).")

    def test_04_get_broker_accounts(self):
        """Verifica el endpoint GET /api/v1/banking/accounts."""
        demo_user = self.db.query(User).filter(User.username == "demo").first()
        response = self.client.get(f"/api/v1/banking/accounts?user_id={demo_user.id}")
        self.assertEqual(response.status_code, 200)
        accounts = response.json()

        self.assertIsInstance(accounts, list)
        self.assertGreaterEqual(len(accounts), 1)
        found = any(acc["account_reference"] == "TR-TEST-LINK-99" for acc in accounts)
        self.assertTrue(found)
        print(f"[OK] test_04: Listado de cuentas recuperado ({len(accounts)} brokers asociados).")

    def test_05_sync_idempotency_workflow(self):
        """PRUEBA CRÍTICA DE IDEMPOTENCIA:
        1. Vincula una cuenta de Trade Republic.
        2. Ejecuta la primera sincronización: debe insertar las transacciones del mock.
        3. Ejecuta una segunda sincronización idéntica: debe omitir todas las transacciones
           gracias al external_tx_id y NO duplicar registros ni balance.
        """
        demo_user = self.db.query(User).filter(User.username == "demo").first()
        
        # 1. Vincular cuenta para el test de sincronización
        link_resp = self.client.post(
            "/api/v1/banking/link-account",
            json={
                "broker_name": "Trade Republic",
                "account_reference": "TR-TEST-IDEMPOTENCY-01",
                "user_id": demo_user.id,
            },
        )
        self.assertEqual(link_resp.status_code, 201)
        account_id = link_resp.json()["id"]

        # Asegurar estado limpio de transacciones con los IDs del mock antes de iniciar
        mock_tx_ids = ["TR-TX-1001", "TR-TX-1002", "TR-TX-1003"]
        self.db.query(Transaction).filter(Transaction.external_tx_id.in_(mock_tx_ids)).delete(
            synchronize_session=False
        )
        self.db.commit()

        count_before = (
            self.db.query(Transaction)
            .filter(Transaction.external_tx_id.in_(mock_tx_ids))
            .count()
        )
        self.assertEqual(count_before, 0)

        # 2. PRIMERA SINCRONIZACIÓN: Inserción inicial
        sync_resp_1 = self.client.post(f"/api/v1/banking/sync/{account_id}")
        self.assertEqual(sync_resp_1.status_code, 200)
        data_1 = sync_resp_1.json()

        self.assertEqual(data_1["account_id"], account_id)
        self.assertEqual(data_1["sync_status"], "SYNCED")
        self.assertEqual(data_1["synced_transactions"], 3)
        self.assertEqual(data_1["skipped_transactions"], 0)
        self.assertIsNotNone(data_1["last_synced_at"])

        count_after_first = (
            self.db.query(Transaction)
            .filter(Transaction.external_tx_id.in_(mock_tx_ids))
            .count()
        )
        self.assertEqual(count_after_first, 3)

        # Verificar que los campos extendidos se guardaron correctamente
        tx_saved = (
            self.db.query(Transaction)
            .filter(Transaction.external_tx_id == "TR-TX-1001")
            .first()
        )
        self.assertIsNotNone(tx_saved)
        self.assertEqual(tx_saved.currency, "EUR")
        self.assertEqual(tx_saved.broker_fee, 1.0)
        self.assertEqual(tx_saved.ticker, "VWCE.DE")

        print("[OK] test_05 (Paso 1): Primera sincronización insertó 3 transacciones con éxito.")

        # 3. SEGUNDA SINCRONIZACIÓN (IDEMPOTENCIA): Mismo payload/mock
        sync_resp_2 = self.client.post(f"/api/v1/banking/sync/{account_id}")
        self.assertEqual(sync_resp_2.status_code, 200)
        data_2 = sync_resp_2.json()

        self.assertEqual(data_2["sync_status"], "SYNCED")
        self.assertEqual(data_2["synced_transactions"], 0, "No debe insertar nuevas transacciones")
        self.assertEqual(data_2["skipped_transactions"], 3, "Debe omitir las 3 transacciones ya existentes")

        # Validar en la BD que el recuento no aumentó
        count_after_second = (
            self.db.query(Transaction)
            .filter(Transaction.external_tx_id.in_(mock_tx_ids))
            .count()
        )
        self.assertEqual(
            count_after_second,
            3,
            "El número total de transacciones en la BD debe permanecer exactamente igual",
        )

        print("[OK] test_05 (Paso 2): Idempotencia validada. Cero transacciones duplicadas tras re-sincronizar.")

    def test_06_sync_errors_and_edge_cases(self):
        """Verifica el manejo de errores: cuenta no encontrada y broker desconocido."""
        # Cuenta inexistente
        resp_404 = self.client.post("/api/v1/banking/sync/999999")
        self.assertEqual(resp_404.status_code, 404)

        # Broker no soportado
        demo_user = self.db.query(User).filter(User.username == "demo").first()
        link_unsupported = self.client.post(
            "/api/v1/banking/link-account",
            json={
                "broker_name": "Unsupported Broker XYZ",
                "account_reference": "TR-TEST-UNSUPPORTED",
                "user_id": demo_user.id,
            },
        )
        self.assertEqual(link_unsupported.status_code, 201)
        bad_acc_id = link_unsupported.json()["id"]

        resp_bad = self.client.post(f"/api/v1/banking/sync/{bad_acc_id}")
        self.assertEqual(resp_bad.status_code, 400)

        # Verificar que el status quedó en ERROR
        acc_db = self.db.query(BrokerAccount).filter(BrokerAccount.id == bad_acc_id).first()
        self.assertEqual(acc_db.sync_status, SyncStatus.ERROR)
        print("[OK] test_06: Manejo de errores (404 y 400 con estado ERROR) verificado.")


if __name__ == "__main__":
    unittest.main()
