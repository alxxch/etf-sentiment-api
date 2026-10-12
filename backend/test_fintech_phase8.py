"""Suite de pruebas de integración para la Fase 8:
Endpoints REST de Fintech, valoración de Portfolio y simulación DCA con cruce de sentimiento.
"""
import sys
import unittest
from fastapi.testclient import TestClient

from main import app
from db.database import SessionLocal
from db.models import User, Portfolio, SavingsPlan, Transaction


class TestFintechPhase8(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_01_health_and_docs(self):
        """Verifica que la app y la documentación OpenAPI / Swagger están operativas."""
        response = self.client.get("/openapi.json")
        self.assertEqual(response.status_code, 200)
        schema = response.json()
        self.assertIn("/api/v1/fintech/portfolio", schema["paths"])
        self.assertIn("/api/v1/fintech/simulate-dca", schema["paths"])
        self.assertIn("/api/v1/fintech/savings-plan", schema["paths"])
        print("[OK] Endpoint paths verificados en OpenAPI schema.")

    def test_02_get_demo_portfolio(self):
        """Verifica el endpoint GET /api/v1/fintech/portfolio."""
        response = self.client.get("/api/v1/fintech/portfolio")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        # Validar estructura y datos principales
        self.assertIn("user_name", data)
        self.assertIn("total_invested", data)
        self.assertIn("current_value", data)
        self.assertIn("pnl", data)
        self.assertIn("roi_pct", data)
        self.assertIn("market_sentiment_score", data)
        self.assertIn("asset_allocation", data)
        self.assertIn("savings_plan", data)
        self.assertIn("transactions", data)

        # Validar métricas financieras
        self.assertGreater(data["total_invested"], 0.0)
        self.assertGreater(data["current_value"], 0.0)
        self.assertIsInstance(data["market_sentiment_score"], int)
        self.assertGreaterEqual(data["market_sentiment_score"], 0)
        self.assertLessEqual(data["market_sentiment_score"], 100)

        # Validar asignación de activos (Renta Variable vs Oro)
        self.assertGreaterEqual(len(data["asset_allocation"]), 1)
        for asset in data["asset_allocation"]:
            self.assertIn("ticker", asset)
            self.assertIn("shares", asset)
            self.assertIn("current_price", asset)
            self.assertIn("current_value", asset)
            self.assertIn("allocation_pct", asset)
            self.assertIn("break_even_price", asset)
            self.assertIn("pnl", asset)
            self.assertIn("roi_pct", asset)

        # Validar plan de ahorro activo
        self.assertIsNotNone(data["savings_plan"])
        self.assertGreater(data["savings_plan"]["monthly_deposit"], 0)

        # Validar transacciones
        self.assertGreater(len(data["transactions"]), 0)
        print(f"[OK] GET /portfolio respondio con exito: Total Invertido={data['total_invested']} EUR, Valor Actual={data['current_value']} EUR, PnL={data['pnl']} EUR (ROI {data['roi_pct']}%), Sentiment={data['market_sentiment_score']}.")

    def test_03_simulate_dca_standard(self):
        """Verifica el endpoint POST /api/v1/fintech/simulate-dca con parámetros estándar."""
        payload = {
            "initial_capital": 0.0,
            "monthly_deposit": 200.0,
            "months": 6,
            "allocation_equity_pct": 80.0,
            "allocation_gold_pct": 20.0,
        }
        response = self.client.post("/api/v1/fintech/simulate-dca", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()

        self.assertEqual(data["total_invested"], 1200.0)
        self.assertGreater(data["current_value"], 0.0)
        self.assertIn("pnl", data)
        self.assertIn("roi_pct", data)
        self.assertIn("equity_shares", data)
        self.assertIn("gold_shares", data)
        self.assertIn("steps", data)
        self.assertEqual(len(data["steps"]), 6)

        # Verificar cada paso temporal y su cruce con sentimiento
        for step in data["steps"]:
            self.assertIn("month_index", step)
            self.assertIn("date", step)
            self.assertIn("cumulative_invested", step)
            self.assertIn("portfolio_value", step)
            self.assertIn("pnl", step)
            self.assertIn("roi_pct", step)
            self.assertIn("market_sentiment_score", step)
            self.assertGreaterEqual(step["market_sentiment_score"], 0)
            self.assertLessEqual(step["market_sentiment_score"], 100)

        last_step = data["steps"][-1]
        self.assertEqual(last_step["cumulative_invested"], 1200.0)
        print(f"[OK] POST /simulate-dca (6 meses) respondio con exito: 6 pasos temporales calculados, PnL={data['pnl']} EUR.")

    def test_04_simulate_dca_with_initial_capital(self):
        """Verifica la simulación con aportación de capital inicial."""
        payload = {
            "initial_capital": 1000.0,
            "monthly_deposit": 300.0,
            "months": 12,
            "allocation_equity_pct": 70.0,
            "allocation_gold_pct": 30.0,
        }
        response = self.client.post("/api/v1/fintech/simulate-dca", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()

        # 1000 inicial + (12 * 300) = 4600 invertido
        expected_total = 1000.0 + (12 * 300.0)
        self.assertEqual(data["total_invested"], expected_total)
        self.assertEqual(len(data["steps"]), 12)
        self.assertEqual(data["steps"][0]["cumulative_invested"], 1300.0)  # 1000 inicial + 300 mes 1
        self.assertEqual(data["steps"][-1]["cumulative_invested"], expected_total)
        print(f"[OK] POST /simulate-dca con capital inicial (1000 EUR + 12x300 EUR = 4600 EUR) validado con exito.")

    def test_05_savings_plan_lifecycle(self):
        """Verifica la consulta y actualización del plan de ahorro."""
        # 1. Consulta inicial
        get_res = self.client.get("/api/v1/fintech/savings-plan")
        self.assertEqual(get_res.status_code, 200)
        initial_plan = get_res.json()
        self.assertIn("monthly_deposit", initial_plan)

        # 2. Actualización del plan
        update_payload = {
            "monthly_deposit": 350.0,
            "frequency": "monthly",
            "allocation_equity_pct": 85.0,
            "allocation_gold_pct": 15.0,
            "is_active": True,
        }
        post_res = self.client.post("/api/v1/fintech/savings-plan", json=update_payload)
        self.assertEqual(post_res.status_code, 200)
        updated_plan = post_res.json()
        self.assertEqual(updated_plan["monthly_deposit"], 350.0)
        self.assertEqual(updated_plan["allocation_equity_pct"], 85.0)
        self.assertEqual(updated_plan["allocation_gold_pct"], 15.0)

        # 3. Restaurar a valores estándar por defecto (200 EUR, 80/20)
        restore_payload = {
            "monthly_deposit": 200.0,
            "frequency": "monthly",
            "allocation_equity_pct": 80.0,
            "allocation_gold_pct": 20.0,
            "is_active": True,
        }
        self.client.post("/api/v1/fintech/savings-plan", json=restore_payload)
        print("[OK] Ciclo de vida de SavingsPlan (GET y POST) verificado con exito.")

    def test_06_validation_errors(self):
        """Verifica que entradas inválidas devuelvan errores 422 o 400."""
        # Meses negativos
        res = self.client.post("/api/v1/fintech/simulate-dca", json={"months": 0})
        self.assertEqual(res.status_code, 422)

        # Depósito menor a 10
        res = self.client.post("/api/v1/fintech/simulate-dca", json={"monthly_deposit": 5.0})
        self.assertEqual(res.status_code, 422)

        # Capital inicial negativo
        res = self.client.post("/api/v1/fintech/simulate-dca", json={"initial_capital": -100.0})
        self.assertEqual(res.status_code, 422)
        print("[OK] Manejo de validaciones Pydantic verificado correctamente.")


if __name__ == "__main__":
    unittest.main()
