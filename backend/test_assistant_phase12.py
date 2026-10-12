"""Suite de pruebas de integración para la Fase 12:
Bucle Multimodal de Respuesta (Síntesis ElevenLabs, Payloads y Degradación Elegante).
"""
import base64
import unittest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from db.database import SessionLocal
from main import app
from tts_service import generate_speech, DEFAULT_VOICE_ID, DEFAULT_MODEL_ID


class TestAssistantPhase12(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.db = SessionLocal()

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    # ========================================================================
    # 1. Pruebas de Síntesis de Voz (tts_service.py)
    # ========================================================================

    def test_01_tts_config_constants(self):
        """Verifica que el voice_id y model_id coincidan estrictamente con la especificación."""
        self.assertEqual(DEFAULT_VOICE_ID, "t9LRTh3y1ioN00e9wsNh")
        self.assertEqual(DEFAULT_MODEL_ID, "eleven_multilingual_v2")
        print("[OK] test_01: Constantes de voz ElevenLabs verificadas.")

    def test_02_tts_empty_text_returns_none(self):
        """Verifica que texto vacío o whitespace retorne None sin invocar la API."""
        self.assertIsNone(generate_speech(""))
        self.assertIsNone(generate_speech("   "))
        self.assertIsNone(generate_speech(None))
        print("[OK] test_02: TTS maneja texto vacío retornando None de forma segura.")

    @patch.dict("os.environ", {"ELEVENLABS_API_KEY": ""}, clear=False)
    def test_03_tts_missing_api_key_returns_none(self):
        """Verifica que si no hay API key configurada, retorna None sin romper el flujo."""
        result = generate_speech("Hola mundo")
        self.assertIsNone(result)
        print("[OK] test_03: TTS sin API key retorna None (Graceful Degradation).")

    @patch.dict("os.environ", {"ELEVENLABS_API_KEY": "test_mock_key_123"}, clear=False)
    @patch("tts_service.ElevenLabs")
    def test_04_tts_successful_synthesis_returns_base64(self, mock_elevenlabs_cls):
        """Verifica que la síntesis exitosa retorne el audio codificado en Base64."""
        sample_audio_bytes = b"ID3_MOCK_MP3_STREAM_BINARY_DATA"
        mock_client = MagicMock()
        mock_client.text_to_speech.convert.return_value = [sample_audio_bytes]
        mock_elevenlabs_cls.return_value = mock_client

        result_b64 = generate_speech("Resumen del mercado financiero")

        self.assertIsNotNone(result_b64)
        decoded = base64.b64decode(result_b64)
        self.assertEqual(decoded, sample_audio_bytes)
        mock_client.text_to_speech.convert.assert_called_once_with(
            voice_id="t9LRTh3y1ioN00e9wsNh",
            text="Resumen del mercado financiero",
            model_id="eleven_multilingual_v2",
            output_format="mp3_44100_128",
        )
        print(f"[OK] test_04: TTS sintetiza audio y retorna Base64 ({len(result_b64)} chars).")

    @patch.dict("os.environ", {"ELEVENLABS_API_KEY": "test_mock_key_123"}, clear=False)
    @patch("tts_service.ElevenLabs")
    def test_05_tts_exception_fallback_graceful_degradation(self, mock_elevenlabs_cls):
        """Verifica que ante un fallo de ElevenLabs (cuota agotada o timeout),
        la excepción se capture y retorne None sin romper el flujo conversacional.
        """
        mock_client = MagicMock()
        mock_client.text_to_speech.convert.side_effect = Exception("Rate limit exceeded (429)")
        mock_elevenlabs_cls.return_value = mock_client

        result = generate_speech("Texto que produce error")
        self.assertIsNone(result)
        print("[OK] test_05: TTS captura excepción y degrada elegantemente devolviendo None.")

    # ========================================================================
    # 2. Pruebas del Endpoint Multimodal POST /api/v1/assistant/chat
    # ========================================================================

    @patch("routers.assistant.generate_speech")
    def test_06_endpoint_chat_multimodal_dca_simulation(self, mock_tts):
        """Verifica el payload completo retornado por el endpoint ante simulación DCA."""
        fake_audio_b64 = base64.b64encode(b"FAKE_AUDIO_MP3").decode("utf-8")
        mock_tts.return_value = fake_audio_b64

        payload = {
            "user_prompt": "aporta 100 euros al oro",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertIn("text_response", data)
        self.assertIn("action_type", data)
        self.assertIn("action_executed", data)
        self.assertIn("tool_args", data)
        self.assertIn("data_payload", data)
        self.assertIn("audio_base64", data)

        self.assertEqual(data["action_type"], "DCA_SIMULATED")
        self.assertEqual(data["action_executed"], "simulate_dca_plan")
        self.assertEqual(data["audio_base64"], fake_audio_b64)

        # Validar payload estructurado para reactividad de Flutter
        d_payload = data["data_payload"]
        self.assertEqual(d_payload["status"], "success")
        self.assertIn("simulation_parameters", d_payload)
        self.assertEqual(d_payload["simulation_parameters"]["monthly_deposit"], 100.0)
        self.assertEqual(d_payload["simulation_parameters"]["allocation_gold_pct"], 100.0)
        self.assertIn("results", d_payload)
        self.assertIn("simulation", d_payload)
        print("[OK] test_06: Endpoint POST /api/v1/assistant/chat entrega payload multimodal completo (DCA_SIMULATED + audio).")

    @patch("routers.assistant.generate_speech")
    def test_07_endpoint_chat_multimodal_portfolio_query(self, mock_tts):
        """Verifica el payload completo ante consulta de cartera."""
        mock_tts.return_value = "AUDIO_B64_PORTFOLIO"

        payload = {
            "user_prompt": "¿Cómo va mi cartera?",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(data["action_type"], "PORTFOLIO_QUERY")
        self.assertEqual(data["action_executed"], "get_portfolio_summary")
        self.assertEqual(data["audio_base64"], "AUDIO_B64_PORTFOLIO")
        self.assertIn("current_value", data["data_payload"])
        self.assertIn("total_invested", data["data_payload"])
        print("[OK] test_07: Endpoint responde con PORTFOLIO_QUERY y datos para reactividad.")

    @patch("routers.assistant.generate_speech")
    def test_08_endpoint_chat_tts_fallback_none_audio(self, mock_tts):
        """Verifica que si la síntesis TTS retorna None, el endpoint responde 200 OK
        con audio_base64: null y mantiene los datos financieros intactos.
        """
        mock_tts.return_value = None

        payload = {
            "user_prompt": "simula 50 euros al mes en renta variable",
            "user_id": 1,
        }
        response = self.client.post("/api/v1/assistant/chat", json=payload)
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertIsNone(data["audio_base64"])
        self.assertEqual(data["action_type"], "DCA_SIMULATED")
        self.assertGreater(len(data["text_response"]), 0)
        print("[OK] test_08: Fallback multimodal verificado: responde 200 OK con audio_base64=None ante degradación de voz.")


if __name__ == "__main__":
    unittest.main()
