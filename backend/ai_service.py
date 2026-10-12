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


class GeminiRateLimitException(Exception):
    """Excepción específica cuando se agota la cuota de peticiones de Gemini (429 / RESOURCE_EXHAUSTED)."""
    pass


def _get_client(api_key: Optional[str] = None) -> genai.Client:
    """Instancia el cliente oficial de Google GenAI con la API Key configurada."""
    key = api_key or os.getenv("GEMINI_API_KEY", "").strip()
    return genai.Client(api_key=key)


def analyze_sentiment(news_list: List[str], raise_on_quota: bool = False) -> Dict[str, Any]:
    """Analiza una lista de titulares de noticias y genera un score de sentimiento
    y un resumen conciso mediante la API oficial de Google GenAI (google-genai).

    Args:
        news_list: Lista de cadenas con titulares o resúmenes de noticias.
        raise_on_quota: Si es True, eleva GeminiRateLimitException en lugar de devolver
                        el score neutral (55). Usado en tareas de Celery con Exponential Backoff.

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
    is_quota_exhausted = (
        (isinstance(last_error, errors.APIError) and getattr(last_error, "code", None) == 429)
        or "RESOURCE_EXHAUSTED" in err_str
        or "quota" in err_str.lower()
    )

    if is_quota_exhausted:
        if raise_on_quota:
            raise GeminiRateLimitException(
                f"Límite de cuota alcanzado en la API de Gemini (429 RESOURCE_EXHAUSTED): {err_str}"
            )
        return {
            "sentiment_score": 55,
            "ai_summary": "Sentimiento estable de mercado. (Límite temporal de peticiones alcanzado en Gemini; servicio autorregulando la cuota).",
        }

    return {
        "sentiment_score": 50,
        "ai_summary": f"Sentimiento neutral estimado (aviso de servicio IA: {type(last_error).__name__ if last_error else 'error desconocido'}).",
    }


from sqlalchemy.orm import Session
from services.ai_tools import get_assistant_tools
from services.tool_dispatcher import dispatch_tool_call

ASSISTANT_SYSTEM_PROMPT = """Eres el Asistente Financiero Cuantitativo de 'Smart Market Sentiment'. Tu misión es asesorar al usuario con precisión analítica, objetividad y concisión matemática (estilo analista cuantitativo de Apple Finance).

Tienes acceso a herramientas (Tools) conectadas a la base de datos PostgreSQL y al motor de simulación DCA:
1. `get_portfolio_summary`: Para consultar balance, valor actual, P&L, ROI o asignación de activos.
2. `simulate_dca_plan`: Para simular aportaciones periódicas Dollar Cost Averaging (DCA). Parámetros: monthly_deposit (monto mensual en euros), months (meses a simular, default 6 o 12), allocation_equity_pct (% renta variable), allocation_gold_pct (% oro físico).
3. `get_market_sentiment`: Para consultar el sentimiento de mercado o cotizaciones (VWCE.DE, 8PSG.DE, etc.).
4. `update_savings_plan`: Para actualizar permanentemente la configuración del plan de ahorro del usuario.

REGLAS DE ACTUACIÓN:
- Siempre que el usuario pregunte por su dinero, cartera, planes o simulaciones, invoca la herramienta correspondiente.
- Si el usuario dice "aporta X euros al oro" o "simula X euros al oro", debes pasar monthly_deposit=X, allocation_gold_pct=100.0 y allocation_equity_pct=0.0.
- Si el usuario menciona solo ETFs o renta variable, allocation_equity_pct=100.0 y allocation_gold_pct=0.0.
- Si pide una aportación general sin especificar activo, usa el reparto estándar (80% renta variable, 20% oro).
- Tras recibir el resultado de la herramienta, redacta una respuesta final en español, profesional, concisa (máximo 2 a 3 oraciones) y con tono de alta dirección financiera, destacando los números clave (capital final, P&L, ROI).
- No uses listas extensas ni markdown redundante.
"""


def _fallback_intent_parser(user_prompt: str, db: Session, user_id: int = 1) -> Dict[str, Any]:
    """Extractor semántico de reserva para operar de forma resiliente si la API externa
    de Gemini alcanza límites de cuota (429) o no dispone de conexión.
    """
    prompt_lower = user_prompt.lower()

    # 1. Intención de simulación DCA con extracción de importes numéricos
    if any(keyword in prompt_lower for keyword in ["simula", "aporta", "aportar", "invertir", "dca", "ahorro mensual"]):
        # Extraer monto numérico (ej: "100 euros", "100€", "150.50")
        match_amount = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:€|euros?|eur)?", prompt_lower)
        amount = float(match_amount.group(1).replace(",", ".")) if match_amount else 100.0

        # Extraer meses si se especifican
        match_months = re.search(r"(\d+)\s*(?:meses|mes)", prompt_lower)
        months = int(match_months.group(1)) if match_months else 6

        # Detectar activo
        is_gold = "oro" in prompt_lower or "gold" in prompt_lower or "8psg" in prompt_lower
        is_equity = "variable" in prompt_lower or "etf" in prompt_lower or "vwce" in prompt_lower or "mundo" in prompt_lower

        if is_gold and not is_equity:
            gold_pct = 100.0
            equity_pct = 0.0
        elif is_equity and not is_gold:
            gold_pct = 0.0
            equity_pct = 100.0
        else:
            equity_pct = 80.0
            gold_pct = 20.0

        tool_args = {
            "monthly_deposit": amount,
            "months": months,
            "allocation_equity_pct": equity_pct,
            "allocation_gold_pct": gold_pct,
        }
        result = dispatch_tool_call("simulate_dca_plan", tool_args, db=db, user_id=user_id)
        res_data = result.get("results", {})
        final_val = res_data.get("final_portfolio_value", 0.0)
        pnl = res_data.get("pnl", 0.0)
        roi = res_data.get("roi_pct", 0.0)

        asset_desc = "oro físico (8PSG.DE)" if gold_pct == 100 else ("renta variable global" if equity_pct == 100 else "80% RV / 20% Oro")
        text = (
            f"Simulación calculada: aportando {amount:.2f}€/mes en {asset_desc} durante {months} meses, "
            f"acumularías un valor final de {final_val:.2f}€, con un P&L de {pnl:+.2f}€ ({roi:+.2f}% ROI)."
        )
        return {
            "text_response": text,
            "action_executed": "simulate_dca_plan",
            "tool_args": tool_args,
            "data_payload": result,
        }

    # 2. Intención de consulta de cartera
    if any(keyword in prompt_lower for keyword in ["cartera", "portfolio", "balance", "cuánto tengo", "cómo va", "mis activos"]):
        result = dispatch_tool_call("get_portfolio_summary", {}, db=db, user_id=user_id)
        c_val = result.get("current_value", 0.0)
        tot_inv = result.get("total_invested", 0.0)
        pnl = result.get("pnl", 0.0)
        roi = result.get("roi_pct", 0.0)
        text = (
            f"Tu cartera actual está valorada en {c_val:.2f}€ sobre una inversión total de {tot_inv:.2f}€, "
            f"generando una rentabilidad neta de {pnl:+.2f}€ ({roi:+.2f}% ROI)."
        )
        return {
            "text_response": text,
            "action_executed": "get_portfolio_summary",
            "tool_args": {},
            "data_payload": result,
        }

    # 3. Intención de consulta de sentimiento / mercado
    if any(keyword in prompt_lower for keyword in ["sentimiento", "mercado", "cotización", "precio", "noticias"]):
        ticker = "8PSG.DE" if ("oro" in prompt_lower or "gold" in prompt_lower) else "VWCE.DE"
        tool_args = {"ticker": ticker}
        result = dispatch_tool_call("get_market_sentiment", tool_args, db=db, user_id=user_id)
        score = result.get("sentiment_score", 58)
        lbl = result.get("sentiment_label", "Neutral")
        price = result.get("current_price", 0.0)
        text = (
            f"El sentimiento actual para {ticker} es {lbl} con una puntuación de {score}/100. "
            f"La cotización de referencia se sitúa en {price:.2f}€."
        )
        return {
            "text_response": text,
            "action_executed": "get_market_sentiment",
            "tool_args": tool_args,
            "data_payload": result,
        }

    # 4. Respuesta general
    return {
        "text_response": (
            "Puedo ayudarte a consultar el estado de tu cartera, simular estrategias de aportación DCA "
            "(por ejemplo: 'aporta 100€ al oro') o evaluar el sentimiento del mercado en tiempo real."
        ),
        "action_executed": "GENERAL_QUERY",
        "tool_args": {},
        "data_payload": {},
    }


def process_assistant_message(
    user_prompt: str,
    db: Session,
    user_id: int = 1,
    api_key: Optional[str] = None,
) -> Dict[str, Any]:
    """Procesa una consulta en lenguaje natural mediante Function Calling con Google Gemini.
    Ejecuta el ciclo:
    1. Envío de prompt + declaración de herramientas (Tools).
    2. Si Gemini solicita llamada a función, despacho contra PostgreSQL / dca_simulator.
    3. Reenvío del resultado a Gemini para redactar la respuesta ejecutiva final en lenguaje natural.
    4. En caso de fallo o saturación de cuota, fallback semántico inteligente.
    """
    clean_prompt = user_prompt.strip()
    if not clean_prompt:
        return {
            "text_response": "No he recibido ningún comando de voz o texto.",
            "action_executed": "NONE",
            "tool_args": {},
            "data_payload": {},
        }

    key = api_key or os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        print("[ai_service] GEMINI_API_KEY no configurada. Ejecutando fallback semántico.")
        return _fallback_intent_parser(clean_prompt, db=db, user_id=user_id)

    client = _get_client(key)
    tools = [get_assistant_tools()]
    candidate_models = ["gemini-2.5-flash", "gemini-3.8-flash", "gemini-flash-latest"]

    for m_name in candidate_models:
        try:
            # 1. Primera llamada: Determinar intención o invocar herramienta
            response = client.models.generate_content(
                model=m_name,
                contents=clean_prompt,
                config=types.GenerateContentConfig(
                    tools=tools,
                    system_instruction=ASSISTANT_SYSTEM_PROMPT,
                    temperature=0.2,
                ),
            )

            # Verificar si Gemini solicitó ejecutar alguna función
            if response and response.function_calls:
                fc = response.function_calls[0]
                tool_name = fc.name
                tool_args = dict(fc.args) if fc.args else {}
                print(f"[ai_service] Gemini Function Call detectada: {tool_name} con args: {tool_args}")

                # 2. Despachar la herramienta de forma transaccional
                tool_result = dispatch_tool_call(
                    tool_name=tool_name,
                    args=tool_args,
                    db=db,
                    user_id=user_id,
                )

                # 3. Segunda llamada: Enviar resultado de vuelta a Gemini para redacción final
                user_content = types.Content(
                    role="user",
                    parts=[types.Part.from_text(text=clean_prompt)],
                )
                model_call_content = response.candidates[0].content
                tool_response_part = types.Part.from_function_response(
                    name=tool_name,
                    response={"result": tool_result},
                )
                tool_content = types.Content(
                    role="user",
                    parts=[tool_response_part],
                )

                second_turn = client.models.generate_content(
                    model=m_name,
                    contents=[user_content, model_call_content, tool_content],
                    config=types.GenerateContentConfig(
                        tools=tools,
                        system_instruction=ASSISTANT_SYSTEM_PROMPT,
                        temperature=0.2,
                    ),
                )

                final_text = (
                    second_turn.text.strip()
                    if second_turn and second_turn.text
                    else "Acción financiera procesada y calculada correctamente."
                )

                return {
                    "text_response": final_text,
                    "action_executed": tool_name,
                    "tool_args": tool_args,
                    "data_payload": tool_result,
                }

            # Si no hubo Function Call, el modelo contestó directamente
            final_text = response.text.strip() if response and response.text else "Entendido."
            return {
                "text_response": final_text,
                "action_executed": "GENERAL_QUERY",
                "tool_args": {},
                "data_payload": {},
            }

        except errors.APIError as e:
            if getattr(e, "code", None) == 429 or "RESOURCE_EXHAUSTED" in str(e) or "quota" in str(e).lower():
                print(f"[ai_service] Quota Limit (429) en {m_name}. Activando fallback determinista.")
                break
            if getattr(e, "code", None) == 404:
                continue
            print(f"[ai_service] APIError en modelo {m_name}: {e}")
        except Exception as e:
            print(f"[ai_service] Excepción en modelo {m_name}: {e}")
            continue

    # Fallback si no fue posible completar la llamada con la API de Gemini
    return _fallback_intent_parser(clean_prompt, db=db, user_id=user_id)


if __name__ == "__main__":
    from db.database import SessionLocal
    db = SessionLocal()
    try:
        print("Probando asistente con intención: 'simula una aportación de 100 euros al oro'")
        out = process_assistant_message("simula una aportación de 100 euros al oro", db=db)
        print("Respuesta:")
        print(json.dumps(out, indent=2, ensure_ascii=False))
    finally:
        db.close()

