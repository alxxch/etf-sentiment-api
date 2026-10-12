"""Suite de pruebas unitarias, matemáticas y de integración para la Fase 14:
Motor de Rebalanceo Inteligente y Alocación Dinámica.
Verifica:
1. Exactitud aritmética del algoritmo cuantitativo puro (calculate_rebalance_plan).
2. Escenarios equilibrados (Drift = 0%).
3. Escenarios moderados con rebalanceo al 100% (FULLY_REBALANCED).
4. Escenarios extremos con déficit insuficiente para una sola cuota (PARTIALLY_REBALANCED).
5. Casos de cartera vacía (0 EUR) y conservación estricta de capital.
6. Endpoint REST GET /api/v1/fintech/rebalance-advice mediante TestClient.
7. Declaración de herramientas Gemini y despacho conversacional (calculate_portfolio_rebalance).
"""
import unittest
from fastapi.testclient import TestClient

from ai_service import process_assistant_message
from db.database import SessionLocal
from db.seed import seed_demo_user
from main import app
from services.ai_tools import get_assistant_tools
from services.rebalance_engine import calculate_rebalance_plan, get_portfolio_rebalance_advice
from services.tool_dispatcher import dispatch_tool_call


class TestRebalancePhase14(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        seed_demo_user()
        cls.db = SessionLocal()

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    # ========================================================================
    # 1. Pruebas Cuantitativas Puras (Exactitud Matemática y Casos Límite)
    # ========================================================================

    def test_01_math_perfectly_balanced_portfolio(self):
        """Cartera exactamente equilibrada (80% RV, 20% Oro).
        El drift debe ser 0% y la cuota debe repartirse exactamente 80/20.
        """
        assets = [
            {"ticker": "VWCE.DE", "asset_class": "EQUITY", "current_value": 800.0},
            {"ticker": "8PSG.DE", "asset_class": "GOLD", "current_value": 200.0},
        ]
        res = calculate_rebalance_plan(
            assets_valuation=assets,
            target_equity_pct=80.0,
            target_gold_pct=20.0,
            monthly_deposit=200.0,
        )

        self.assertEqual(res["rebalance_status"], "BALANCED")
        self.assertEqual(res["current_portfolio_value"], 1000.0)
        self.assertEqual(res["monthly_deposit"], 200.0)
        self.assertEqual(res["post_rebalance_portfolio_value"], 1200.0)

        eq = next(a for a in res["assets"] if a["asset_class"] == "EQUITY")
        gd = next(a for a in res["assets"] if a["asset_class"] == "GOLD")

        # Desviación cero
        self.assertAlmostEqual(eq["drift_pct"], 0.0, places=2)
        self.assertAlmostEqual(gd["drift_pct"], 0.0, places=2)
        self.assertAlmostEqual(eq["drift_amount"], 0.0, places=2)
        self.assertAlmostEqual(gd["drift_amount"], 0.0, places=2)

        # Reparto proporcional
        self.assertEqual(eq["suggested_deposit"], 160.0)
        self.assertEqual(gd["suggested_deposit"], 40.0)
        self.assertEqual(eq["suggested_deposit"] + gd["suggested_deposit"], 200.0)

        # Proyección exacta
        self.assertEqual(eq["projected_allocation_pct"], 80.0)
        self.assertEqual(gd["projected_allocation_pct"], 20.0)
        print("[OK] test_01: Cartera equilibrada validada con exactitud aritmética (80%/20%).")

    def test_02_math_moderate_drift_fully_rebalanced(self):
        """Desviación moderada corregible en una sola cuota (85% RV vs 15% Oro, objetivo 80/20).
        Total cartera: 1000€. Cuota: 200€.
        Post-cartera: 1200€ -> Ideal: RV 960€, Oro 240€.
        Déficit RV: 960 - 850 = 110€.
        Déficit Oro: 240 - 150 = 90€.
        Debe asignar 110€ a RV y 90€ a Oro, logrando 80.0% y 20.0% post-rebalanceo.
        """
        assets = [
            {"ticker": "VWCE.DE", "asset_class": "EQUITY", "current_value": 850.0},
            {"ticker": "8PSG.DE", "asset_class": "GOLD", "current_value": 150.0},
        ]
        res = calculate_rebalance_plan(
            assets_valuation=assets,
            target_equity_pct=80.0,
            target_gold_pct=20.0,
            monthly_deposit=200.0,
        )

        self.assertEqual(res["rebalance_status"], "FULLY_REBALANCED")
        self.assertEqual(res["current_portfolio_value"], 1000.0)

        eq = next(a for a in res["assets"] if a["asset_class"] == "EQUITY")
        gd = next(a for a in res["assets"] if a["asset_class"] == "GOLD")

        # Métricas de desviación previa
        self.assertEqual(eq["drift_pct"], 5.0)  # +5%
        self.assertEqual(gd["drift_pct"], -5.0)  # -5%
        self.assertEqual(eq["drift_amount"], 50.0)  # +50€
        self.assertEqual(gd["drift_amount"], -50.0)  # -50€

        # Aportaciones sugeridas exactas
        self.assertEqual(eq["suggested_deposit"], 110.0)
        self.assertEqual(gd["suggested_deposit"], 90.0)
        self.assertEqual(eq["suggested_deposit"] + gd["suggested_deposit"], 200.0)

        # Proyección exacta al 100%
        self.assertEqual(eq["projected_value"], 960.0)
        self.assertEqual(gd["projected_value"], 240.0)
        self.assertEqual(eq["projected_allocation_pct"], 80.0)
        self.assertEqual(gd["projected_allocation_pct"], 20.0)
        print("[OK] test_02: Desviación moderada corregida al 100% (FULLY_REBALANCED).")

    def test_03_math_extreme_drift_partially_rebalanced(self):
        """ESCENARIO LÍMITE: Desviación tan grande que la cuota no basta para el 100%.
        RV está muy sobreponderado: 1150€ RV y 50€ Oro (Total 1200€).
        Objetivo 80/20. Aportación mensual: 200€.
        Post-cartera: 1400€ -> Ideal RV: 1120€. Pero RV ya tiene 1150€ (> 1120€).
        Déficit RV: 1120 - 1150 = -30€ (< 0).
        Como no se realizan ventas forzadas, la aportación a RV debe ser 0.00€
        y el 100% de la cuota (200.00€) debe destinarse al activo rezagado (Oro).
        """
        assets = [
            {"ticker": "VWCE.DE", "asset_class": "EQUITY", "current_value": 1150.0},
            {"ticker": "8PSG.DE", "asset_class": "GOLD", "current_value": 50.0},
        ]
        res = calculate_rebalance_plan(
            assets_valuation=assets,
            target_equity_pct=80.0,
            target_gold_pct=20.0,
            monthly_deposit=200.0,
        )

        self.assertEqual(res["rebalance_status"], "PARTIALLY_REBALANCED")
        self.assertEqual(res["current_portfolio_value"], 1200.0)

        eq = next(a for a in res["assets"] if a["asset_class"] == "EQUITY")
        gd = next(a for a in res["assets"] if a["asset_class"] == "GOLD")

        # RV sobreponderado significativamente
        self.assertGreater(eq["drift_pct"], 10.0)
        self.assertLess(gd["drift_pct"], -10.0)

        # Asignación de emergencia: 100% al rezagado, 0% al sobreponderado
        self.assertEqual(eq["suggested_deposit"], 0.0)
        self.assertEqual(gd["suggested_deposit"], 200.0)
        self.assertEqual(eq["suggested_deposit"] + gd["suggested_deposit"], 200.0)

        # Verificación de convergencia: el drift se reduce lo máximo posible
        self.assertEqual(eq["projected_value"], 1150.0)
        self.assertEqual(gd["projected_value"], 250.0)
        self.assertLess(eq["projected_allocation_pct"], eq["current_allocation_pct"])
        self.assertGreater(gd["projected_allocation_pct"], gd["current_allocation_pct"])
        print("[OK] test_03: Escenario límite verificado: 100% del flujo al activo rezagado sin ventas.")

    def test_04_math_empty_portfolio(self):
        """Cartera vacía (0€): la aportación mensual debe repartirse según los porcentajes objetivo."""
        assets = []
        res = calculate_rebalance_plan(
            assets_valuation=assets,
            target_equity_pct=70.0,
            target_gold_pct=30.0,
            monthly_deposit=300.0,
        )

        self.assertEqual(res["rebalance_status"], "BALANCED")
        self.assertEqual(res["current_portfolio_value"], 0.0)
        self.assertEqual(res["post_rebalance_portfolio_value"], 300.0)

        eq = next(a for a in res["assets"] if a["asset_class"] == "EQUITY")
        gd = next(a for a in res["assets"] if a["asset_class"] == "GOLD")

        self.assertEqual(eq["suggested_deposit"], 210.0)  # 70% de 300
        self.assertEqual(gd["suggested_deposit"], 90.0)   # 30% de 300
        self.assertEqual(eq["suggested_deposit"] + gd["suggested_deposit"], 300.0)
        print("[OK] test_04: Cartera inicial vacía reparte la cuota según el objetivo del plan.")

    # ========================================================================
    # 2. Pruebas de Integración REST (FastAPI TestClient)
    # ========================================================================

    def test_05_rest_endpoint_rebalance_advice(self):
        """Verifica el endpoint GET /api/v1/fintech/rebalance-advice."""
        response = self.client.get("/api/v1/fintech/rebalance-advice")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        # Validar estructura y tipos
        self.assertIn("portfolio_id", data)
        self.assertIn("user_id", data)
        self.assertIn("current_portfolio_value", data)
        self.assertIn("monthly_deposit", data)
        self.assertIn("post_rebalance_portfolio_value", data)
        self.assertIn("rebalance_status", data)
        self.assertIn("summary_message", data)
        self.assertIn("assets", data)

        self.assertGreater(data["current_portfolio_value"], 0.0)
        self.assertGreater(data["monthly_deposit"], 0.0)
        self.assertEqual(len(data["assets"]), 2)

        total_suggested = sum(a["suggested_deposit"] for a in data["assets"])
        self.assertAlmostEqual(total_suggested, data["monthly_deposit"], places=2)

        # Probar con aportación personalizada (custom_deposit)
        custom_resp = self.client.get("/api/v1/fintech/rebalance-advice?custom_deposit=500.0")
        self.assertEqual(custom_resp.status_code, 200)
        custom_data = custom_resp.json()
        self.assertEqual(custom_data["monthly_deposit"], 500.0)
        self.assertAlmostEqual(
            sum(a["suggested_deposit"] for a in custom_data["assets"]),
            500.0,
            places=2,
        )
        print("[OK] test_05: Endpoint REST GET /rebalance-advice validado correctamente.")

    # ========================================================================
    # 3. Integración Conversacional (AI Tools & Tool Dispatcher)
    # ========================================================================

    def test_06_conversational_tool_declaration_and_dispatcher(self):
        """Verifica la declaración de la herramienta en ai_tools y su ejecución en tool_dispatcher."""
        tools = get_assistant_tools()
        names = {fd.name for fd in tools.function_declarations}
        self.assertIn("calculate_portfolio_rebalance", names)

        # Ejecución directa vía tool_dispatcher
        tool_result = dispatch_tool_call(
            tool_name="calculate_portfolio_rebalance",
            args={"custom_deposit": 250.0},
            db=self.db,
            user_id=1,
        )
        self.assertEqual(tool_result["status"], "success")
        self.assertIn("rebalance_data", tool_result)
        self.assertIn("summary_message", tool_result)
        self.assertEqual(tool_result["monthly_deposit"], 250.0)

        # Simulación de consulta conversacional de rebalanceo
        nlp_res = process_assistant_message(
            user_prompt="¿Cómo debo repartir mi dinero este mes para rebalancear?",
            db=self.db,
            user_id=1,
        )
        self.assertEqual(nlp_res["action_executed"], "calculate_portfolio_rebalance")
        self.assertIn("text_response", nlp_res)
        self.assertGreater(len(nlp_res["text_response"]), 20)
        print("[OK] test_06: Integración conversacional NLP y Function Calling validada.")


if __name__ == "__main__":
    unittest.main()
