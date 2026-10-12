import json
import os
import re
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
from google import genai
from google.genai import errors, types

# Cargar variables de entorno desde backend/.env o la raíz
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()


def _get_client(api_key: Optional[str] = None) -> genai.Client:
    """Instancia el cliente oficial de Google GenAI con la API Key configurada."""
    key = api_key or os.getenv("GEMINI_API_KEY", "").strip()
    return genai.Client(api_key=key)


def analyze_sentiment(news_list: List[str]) -> Dict[str, Any]:
    """Analiza una lista de titulares de noticias y genera un score de sentimiento
    y un resumen conciso mediante la API oficial de Google GenAI (google-genai).

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

    client = _get_client(api_key)

    # Intentar gemini-2.5-flash y fallback a modelos actuales si el modelo no está disponible
    candidate_models = ["gemini-2.5-flash", "gemini-3.8-flash", "gemini-flash-latest"]
    last_error: Optional[Exception] = None

    for m_name in candidate_models:
        try:
            response = client.models.generate_content(
                model=m_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )

            raw_text = response.text.strip() if response and response.text else ""

            # Limpiar posible bloque markdown ```json ... ``` si el modelo lo incluye
            if raw_text.startswith("```"):
                raw_text = re.sub(r"^```(?:json)?\s*", "", raw_text)
                raw_text = re.sub(r"\s*```$", "", raw_text)

            parsed = json.loads(raw_text)

            sentiment_score = int(parsed.get("sentiment_score", 50))
            sentiment_score = max(0, min(100, sentiment_score))
            ai_summary = str(parsed.get("ai_summary", "Análisis de sentimiento completado.")).strip()

            return {
                "sentiment_score": sentiment_score,
                "ai_summary": ai_summary,
            }
        except errors.APIError as e:
            last_error = e
            # Si el error es 429 (ResourceExhausted / Quota Limit), detener el ciclo e ir al fallback
            if getattr(e, "code", None) == 429 or "RESOURCE_EXHAUSTED" in str(e) or "quota" in str(e).lower():
                print(f"[ai_service] Quota Limit (429 RESOURCE_EXHAUSTED) en modelo {m_name}: {e.message if hasattr(e, 'message') else e}")
                break
            # Si el modelo fue retirado o no encontrado (404), intentar con el siguiente modelo de la lista
            if getattr(e, "code", None) == 404:
                print(f"[ai_service] Modelo {m_name} no disponible (404). Intentando siguiente modelo...")
                continue
            print(f"[ai_service] Error de API en modelo {m_name}: {e}")
        except Exception as e:
            last_error = e
            print(f"[ai_service] Excepción en modelo {m_name}: {e}")
            continue

    print(f"[ai_service] Advertencia al contactar con Gemini: {last_error}")

    # Fallback refinado ante ResourceExhausted (429) o cuota temporal
    err_str = str(last_error) if last_error else ""
    if (
        (isinstance(last_error, errors.APIError) and getattr(last_error, "code", None) == 429)
        or "RESOURCE_EXHAUSTED" in err_str
        or "quota" in err_str.lower()
    ):
        return {
            "sentiment_score": 55,
            "ai_summary": "Sentimiento estable de mercado. (Límite temporal de peticiones alcanzado en Gemini; servicio autorregulando la cuota).",
        }

    return {
        "sentiment_score": 50,
        "ai_summary": f"Sentimiento neutral estimado (aviso de servicio IA: {type(last_error).__name__ if last_error else 'error desconocido'}).",
    }


if __name__ == "__main__":
    sample_news = [
        "Barclays says AI trade is maturing, favors greater diversification",
        "Is Vanguard FTSE All-World ex-US Index Admiral (VFWAX) a Strong Mutual Fund Pick Right Now?",
    ]
    print("Probando analyze_sentiment con nuevo SDK google-genai...")
    result = analyze_sentiment(sample_news)
    print("Resultado:")
    print(json.dumps(result, indent=2, ensure_ascii=False))
