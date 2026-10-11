import base64
import os
from typing import Optional
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs

# Cargar variables de entorno desde backend/.env o la raíz
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()

# Voz predeterminada con tono profesional y neutro para análisis financiero
DEFAULT_VOICE_ID = "JBFqnCBsd6RMkjVDRZzb"  # George (Multilingual, claro y narrativo)
DEFAULT_MODEL_ID = "eleven_multilingual_v2"


def generate_speech(
    text: str,
    voice_id: str = DEFAULT_VOICE_ID,
    model_id: str = DEFAULT_MODEL_ID,
) -> Optional[str]:
    """Genera audio sintetizado a partir de texto utilizando la API de ElevenLabs

    y lo retorna codificado en base64.

    Args:
        text: Resumen o texto a narrar (ej. ai_summary generado por Gemini).
        voice_id: Identificador de la voz en ElevenLabs.
        model_id: Modelo multilingüe optimizado para español.

    Returns:
        String con el audio MP3 codificado en base64, o None si no hay API key o hubo un error.
    """
    clean_text = text.strip() if text else ""
    if not clean_text:
        return None

    api_key = os.getenv("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("[tts_service] ELEVENLABS_API_KEY no configurada. Omitiendo síntesis de voz.")
        return None

    try:
        client = ElevenLabs(api_key=api_key)
        audio_stream = client.text_to_speech.convert(
            voice_id=voice_id,
            text=clean_text,
            model_id=model_id,
            output_format="mp3_44100_128",
        )

        audio_bytes = b"".join(chunk for chunk in audio_stream)
        if not audio_bytes:
            return None

        audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")
        return audio_base64
    except Exception as e:
        print(f"[tts_service] Advertencia al generar audio con ElevenLabs: {e}")
        return None


if __name__ == "__main__":
    sample_text = "El mercado muestra un sentimiento moderadamente alcista impulsado por diversificación global."
    print("Probando generate_speech...")
    b64_output = generate_speech(sample_text)
    if b64_output:
        print(f"Éxito: Audio generado ({len(b64_output)} caracteres en base64).")
    else:
        print("No se generó audio (comprobar ELEVENLABS_API_KEY).")
