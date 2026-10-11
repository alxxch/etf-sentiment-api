import json
import os
import re
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
import google.generativeai as genai

# Cargar variables de entorno desde backend/.env o la raíz
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


def _get_model(model_name: str = "gemini-2.5-flash") -> genai.GenerativeModel:
    """Instancia el modelo de Gemini configurado para salida estructurada JSON."""
    return genai.GenerativeModel(
        model_name=model_name,
        generation_config={"response_mime_type": "application/json"},
    )


def analyze_sentiment(news_list: List[str]) -> Dict[str, Any]:
    """Analiza una lista de titulares de noticias y genera un score de sentimiento

    y un resumen conciso mediante Google Gemini.

    Args:
        news_list: Lista de cadenas con titulares o resúmenes de noticias.

    Returns:
        Diccionario con la estructura exacta:
            {
                "sentiment_score": int, # 0 (muy pesimista) a 100 (muy optimista)
                "ai_summary": str       # Resumen corto explicativo en español
            }
    """
    if not news_list:
        return {
            "sentiment_score": 50,
            "ai_summary": "Sin noticias recientes disponibles; sentimiento neutral de mercado.",
        }

    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        return {
            "sentiment_score": 50,
            "ai_summary": "GEMINI_API_KEY no configurada. Configure su API key en el archivo .env para habilitar el análisis de IA.",
        }

    formatted_news = "\n".join(f"{i + 1}. {title}" for i, title in enumerate(news_list))
    prompt = f"""Analiza estos titulares. Devuelve SOLO un JSON con formato {{"sentiment_score": Int (0-100), "ai_summary": "String corto"}}.

El sentimiento debe evaluarse en una escala de 0 a 100 (donde 0 es extremadamente bajista/negativo, 50 es neutral, y 100 es extremadamente alcista/positivo).
El "ai_summary" debe ser una síntesis breve, directa y profesional en español (máximo 2 frases) explicando la tendencia del mercado o activo.

Titulares a analizar:
{formatted_news}
"""

    # Probar con modelos disponibles (gemini-2.5-flash, gemini-flash-latest)
    candidate_models = ["gemini-2.5-flash", "gemini-flash-latest", "gemini-2.5-flash-lite"]
    last_error: Optional[Exception] = None

    for m_name in candidate_models:
        try:
            model = _get_model(m_name)
            response = model.generate_content(prompt)
            raw_text = response.text.strip() if response and response.text else ""

            # Limpiar posible bloque markdown ```json ... ``` si el modelo lo incluye
            if raw_text.startswith("```"):
                raw_text = re.sub(r"^```(?:json)?\s*", "", raw_text)
                raw_text = re.sub(r"\s*```$", "", raw_text)

            parsed = json.loads(raw_text)

            sentiment_score = int(parsed.get("sentiment_score", 50))
            # Asegurar rango 0 - 100
            sentiment_score = max(0, min(100, sentiment_score))
            ai_summary = str(parsed.get("ai_summary", "Análisis de sentimiento completado.")).strip()

            return {
                "sentiment_score": sentiment_score,
                "ai_summary": ai_summary,
            }
        except Exception as e:
            last_error = e
            continue

    print(f"[ai_service] Advertencia al contactar con Gemini: {last_error}")
    return {
        "sentiment_score": 50,
        "ai_summary": f"Sentimiento neutral estimado (aviso de servicio IA: {type(last_error).__name__ if last_error else 'error desconocido'}).",
    }


if __name__ == "__main__":
    sample_news = [
        "Barclays says AI trade is maturing, favors greater diversification",
        "Is Vanguard FTSE All-World ex-US Index Admiral (VFWAX) a Strong Mutual Fund Pick Right Now?",
    ]
    print("Probando analyze_sentiment con noticias de ejemplo...")
    result = analyze_sentiment(sample_news)
    print("Resultado:")
    print(json.dumps(result, indent=2, ensure_ascii=False))
