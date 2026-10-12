"""Suite de pruebas unitarias y de integración para la Fase 11:
NLP y Function Calling con Google Gemini 2.5 y FastAPI.
"""
import sys
import unittest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
from google.genai import types

from ai_service import process_assistant_message
from db.database import SessionLocal
from main import app
from services.ai_tools import get_assistant_tools
from services.tool_dispatcher import dispatch_tool_call, normalize_ticker_name


class TestAssistantPhase11(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.db = SessionLocal()

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    # ========================================================================
    # 1. Pruebas de Esquemas de Herramientas (ai_tools.py)
    # ========================================================================

    def test_01_tool_declarations_schema(self):
        """Valida que las 4 herramientas requeridas estén correctamente declaradas."""
        tools = get_assistant_tools()
        self.assertIsInstance(tools, types.Tool)
        self.assertIsNotNone(tools.function_declarations)
        self.assertGreaterEqual(len(tools.function_declarations), 4)

        declared_names = {fd.name for fd in tools.function_declarations}
        expected_names = {
            "get_portfolio_summary",
            "simulate_dca_plan",
            "get_market_sentiment",
            "update_savings_plan",
        }
        self.assertTrue(expected_names.issubset(declared_names))

        # Validar parámetros requeridos en simulate_dca_plan
        dca_decl = next(fd for fd in tools.function_declarations if fd.name == "simulate_dca_plan")
        schema = dca_decl.parameters_json_schema
        self.assertEqual(schema["type"], "object")
        self.assertIn("monthly_deposit", schema["properties"])
        self.assertIn("allocation_equity_pct", schema["properties"])
        self.assertIn("allocation_gold_pct", schema["properties"])
        self.assertIn("monthly_deposit", schema["required"])
        print("[OK] test_01: Esquemas de herramientas Gemini validados con éxito.")

    def test_02_normalize_ticker_name(self):
        """Verifica el mapeo inteligente de tickers coloquiales."""
        self.assertEqual(normalize_ticker_name("oro"), "8PSG.DE")
        self.assertEqual(normalize_ticker_name("oro físico"), "8PSG.DE")
        self.assertEqual(normalize_ticker_name("gold"), "8PSG.DE")
        self.assertEqual(normalize_ticker_name("mundo"), "VWCE.DE")
        self.assertEqual(normalize_ticker_name("all-world"), "VWCE.DE")
        self.assertEqual(normalize_ticker_name("VWCE.DE"), "VWCE.DE")
        print("[OK] test_02: Normalización de entidades financieras validada.")

    # ========================================================================
    # 2. Pruebas del Despachador Transaccional (tool_dispatcher.py)
    # ========================================================================

    def test_03_dispatcher_get_portfolio_summary(self):
        """Verifica que get_portfolio_summary retorne métricas reales de la cartera."""
        result = dispatch_tool_call("get_portfolio_summary", {}, db=self.db)
        self.assertEqual(result["status"], "success")
        self.assertIn("current_value", result)
        self.assertIn("total_invested", result)
        self.assertIn("pnl", result)
        self.assertIn("roi_pct", result)
        self.assertIn("asset_allocation", result)
        self.assertGreaterEqual(len(result["asset_allocation"]), 2)
        print(f"[OK] test_03: Portfolio summary obtenido (Valor: {result['current_value']}€, ROI: {result['roi_pct']}%).")

    def test_04_dispatcher_simulate_dca_gold(self):
        """Verifica simulación DCA asignando 100% al oro físico."""
        args = {
            "monthly_deposit": 100.0,
            "months": 6,
            "allocation_gold_pct": 100.0,
            "allocation_equity_pct": 0.0,
        }
        result = dispatch_tool_call("simulate_dca_plan", args, db=self.db)
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["simulation_parameters"]["monthly_deposit"], 100.0)
        self.assertEqual(result["simulation_parameters"]["allocation_gold_pct"], 100.0)
        self.assertEqual(result["simulation_parameters"]["allocation_equity_pct"], 0.0)
        self.assertGreater(result["results"]["final_portfolio_value"], 0)
        self.assertGreater(result["results"]["gold_shares_accumulated"], 0)
        print(f"[OK] test_04: Simulación DCA oro (100€/mes x 6 meses = {result['results']['final_portfolio_value']}€ final).")

    def test_05_dispatcher_get_market_sentiment(self):
        """Verifica la consulta de sentimiento de mercado y cotización."""
        result = dispatch_tool_call("get_market_sentiment", {"ticker": "8PSG.DE"}, db=self.db)
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["ticker"], "8PSG.DE")
        self.assertIn("sentiment_score", result)
        self.assertIn("current_price", result)
        self.assertTrue(0 <= result["sentiment_score"] <= 100)
        print(f"[OK] test_05: Sentimiento de mercado para 8PSG.DE: {result['sentiment_score']}/100.")

    def test_06_dispatcher_update_savings_plan(self):
        """Verifica la actualización persistente del plan de ahorro."""
        args = {
            "monthly_deposit": 250.0,
            "allocation_equity_pct": 70.0,
            "allocation_gold_pct": 30.0,
        }
        result = dispatch_tool_call("update_savings_plan", args, db=self.db)
        self.assertEqual(result["status"], "success")
        plan = result["savings_plan"]
        self.assertEqual(plan["monthly_deposit"], 250.0)
        self.assertEqual(plan["allocation_equity_pct"], 70.0)
        self.assertEqual(plan["allocation_gold_pct"], 30.0)
        print("[OK] test_06: Plan de ahorro actualizado y persistido en DB.")

    # ========================================================================
    # 3. Pruebas de NLP y Mocking de Function Calling (ai_service.py)
    # ========================================================================

    def test_07_gemini_function_calling_mock_gold_simulation(self):
        """Simula una llamada a Gemini donde el LLM emite un function_call
        extrayendo parámetros de 'aporta 100 euros al oro'.
        """
        mock_fc = MagicMock()
        mock_fc.name = "simulate_dca_plan"
        mock_fc.args = {
            "monthly_deposit": 100.0,
            "allocation_gold_pct": 100.0,
            "allocation_equity_pct": 0.0,
            "months": 6,
        }

        # Respuesta Turno 1 (solicitud de Tool)
        mock_resp1 = MagicMock()
        mock_resp1.function_calls = [mock_fc]
        mock_candidate = MagicMock()
        mock_candidate.content = types.Content(
            role="model",
            parts=[types.Part.from_function_call(name=mock_fc.name, args=mock_fc.args)],
        )
        mock_resp1.candidates = [mock_candidate]

        # Respuesta Turno 2 (síntesis textual final)
        mock_resp2 = MagicMock()
        mock_resp2.function_calls = None
        mock_resp2.text = (
            "He calculado la simulación de 100€ mensuales destinados íntegramente al oro físico durante 6 meses. "
            "El capital final acumulado sería de 604.20€ con un ROI positivo de +0.70%."
        )

        with patch("ai_service._get_client") as mock_client_factory:
            mock_client = MagicMock()
            mock_client_factory.return_value = mock_client
            mock_client.models.generate_content.side_effect = [mock_resp1, mock_resp2]

            result = process_assistant_message(
                user_prompt="aporta 100 euros al oro",
                db=self.db,
                api_key="fake-test-key",
            )

            self.assertEqual(result["action_executed"], "simulate_dca_plan")
            self.assertEqual(result["tool_args"]["monthly_deposit"], 100.0)
            self.assertEqual(result["tool_args"]["allocation_gold_pct"], 100.0)
            self.assertEqual(result["tool_args"]["allocation_equity_pct"], 0.0)
            self.assertIn("oro físico", result["text_response"])
            self.assertEqual(result["data_payload"]["status"], "success")
            self.assertGreater(result["data_payload"]["results"]["final_portfolio_value"], 0)
            print("[OK] test_07: Gemini Function Calling con bucle completo de resolución verificado.")

    def test_08_fallback_intent_parser_numerical_extraction(self):
        """Verifica que el extractor de reserva extraiga importes numéricos y clases de activo
        ante ausencia de API key o cuota agotada.
        """
        result = process_assistant_message(
            user_prompt="aporta 100 euros al oro",
            db=self.db,
            api_key="",  # Forzar fallback determinista
        )
        self.assertEqual(result["action_executed"], "simulate_dca_plan")
        self.assertEqual(result["tool_args"]["monthly_deposit"], 100.0)
        self.assertEqual(result["tool_args"]["allocation_gold_pct"], 100.0)
        self.assertEqual(result["tool_args"]["allocation_equity_pct"], 0.0)
        self.assertIn("Simulación calculada", result["text_response"])
        self.assertEqual(result["data_payload"]["status"], "success")
        print("[OK] test_08: Fallback extractor extrae parámetros numéricos de forma resiliente.")

    # ========================================================================
    # 4. Pruebas del Endpoint REST POST /api/v1/assistant/chat (routers/assistant.py)
    # ========================================================================

    def test_09_endpoint_assistant_chat_success(self):
        """Prueba el endpoint HTTP POST /api/v1/assistant/chat con consulta de simulación."""
        payload = {
            "user_prompt": "aporta 100 euros al oro",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("text_response", data)
        self.assertIn(data["action_executed"], ["simulate_dca_plan", "GENERAL_QUERY"])
        self.assertIn("data_payload", data)
        self.assertIn("tool_args", data)
        self.assertGreater(len(data["text_response"]), 0)
        print(f"[OK] test_09: POST /api/v1/assistant/chat respondio 200 OK: action={data['action_executed']}.")

    def test_10_endpoint_assistant_chat_portfolio(self):
        """Prueba el endpoint HTTP POST /api/v1/assistant/chat con consulta de balance."""
        payload = {
            "user_prompt": "¿Cómo va mi cartera?",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn(data["action_executed"], ["get_portfolio_summary", "GENERAL_QUERY"])
        self.assertIn("data_payload", data)
        print("[OK] test_10: POST /api/v1/assistant/chat consulta de cartera verificada.")

    def test_11_endpoint_assistant_chat_validation(self):
        """Verifica que un prompt vacío retorne error 422 de validación."""
        payload = {
            "user_prompt": "",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertIn(response.status_code, [400, 422])
        print("[OK] test_11: Validación Pydantic de prompt vacío verificada.")


if __name__ == "__main__":
    unittest.main()
