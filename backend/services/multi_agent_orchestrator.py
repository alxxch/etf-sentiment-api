"""Orquestador Multi-Agente (Investment Committee) — Fase 25.

Implementa el patrón "Swarm of Agents" o Comité de IA:
  1. Lanza en paralelo (asyncio.gather) tres llamadas a Gemini con personas distintas:
       • Analista Técnico
       • Economista Macro
       • Gestor de Riesgos
  2. Captura sus respuestas y las envía al Sintetizador (Lead Advisor) para
     generar el veredicto ejecutivo final.

Todos los intentos a la API de Gemini están protegidos por un sistema de
reintentos con Exponential Backoff ante errores de cuota (429 / RESOURCE_EXHAUSTED).
"""
from __future__ import annotations

import asyncio
import json
import os
import time
from typing import Any, Dict, Optional

from dotenv import load_dotenv
from google import genai
from google.genai import errors, types

from services.ai_personas import (
    LEAD_ADVISOR_PROMPT,
    MACRO_ECONOMIST_PROMPT,
    RISK_MANAGER_PROMPT,
    TECHNICAL_ANALYST_PROMPT,
)

load_dotenv(dotenv_path=os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"))
load_dotenv()

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
_CANDIDATE_MODELS = ["gemini-2.5-flash", "gemini-3.8-flash", "gemini-flash-latest"]
_MAX_RETRIES: int = 3          # intentos máximos ante 429
_BASE_BACKOFF_SECONDS: float = 2.0  # espera base para Exponential Backoff
_TEMPERATURE_PERSONAS: float = 0.4   # algo de creatividad para debate
_TEMPERATURE_SYNTHESIS: float = 0.3  # más determinista en la síntesis


def _get_client() -> genai.Client:
    """Instancia el cliente Google GenAI."""
    key = os.getenv("GEMINI_API_KEY", "").strip()
    return genai.Client(api_key=key)


# ---------------------------------------------------------------------------
# Construcción de los prompts de contexto financiero
# ---------------------------------------------------------------------------

def _build_analyst_context(
    user_query: str,
    portfolio_data: Dict[str, Any],
    montecarlo_data: Dict[str, Any],
) -> str:
    """Construye el bloque de contexto financiero estructurado que recibe cada agente."""
    ticker = montecarlo_data.get("ticker", "VWCE.DE")
    horizon_days = montecarlo_data.get("horizon_days", 1260)
    horizon_years = round(horizon_days / 252, 1)
    p10_final = montecarlo_data.get("final_p10", 0.0)
    p50_final = montecarlo_data.get("final_p50", 0.0)
    p90_final = montecarlo_data.get("final_p90", 0.0)
    initial_investment = montecarlo_data.get("initial_investment", 0.0)
    monthly_contribution = montecarlo_data.get("monthly_contribution", 0.0)
    ann_vol = montecarlo_data.get("annualized_vol", 0.0)
    ann_return = montecarlo_data.get("annualized_return", 0.0)

    total_invested = portfolio_data.get("total_invested", 0.0)
    current_value = portfolio_data.get("current_value", 0.0)
    pnl = portfolio_data.get("pnl", 0.0)
    roi_pct = portfolio_data.get("roi_pct", 0.0)
    sentiment_score = portfolio_data.get("market_sentiment_score", 58)

    # Calcular ratio riesgo/retorno
    upside = p90_final - initial_investment if initial_investment > 0 else 0.0
    downside = initial_investment - p10_final if initial_investment > 0 else 0.0
    rr_ratio = round(upside / downside, 2) if downside > 0 else float("inf")

    return f"""
=== CONSULTA DEL USUARIO ===
{user_query}

=== DATOS DE LA CARTERA REAL ===
• Capital total aportado: {total_invested:.2f} EUR
• Valor actual de mercado: {current_value:.2f} EUR
• P&L neto: {pnl:+.2f} EUR ({roi_pct:+.2f}% ROI)
• Sentiment Score de mercado (0-100): {sentiment_score}/100

=== PROYECCIÓN MONTE CARLO — {ticker} ===
• Horizonte: {horizon_days} días hábiles ({horizon_years} años)
• Inversión inicial proyectada: {initial_investment:.2f} EUR
• Aportación mensual DCA: {monthly_contribution:.2f} EUR/mes
• Retorno anualizado estimado (µ): {ann_return*100:.2f}%
• Volatilidad anualizada (σ): {ann_vol*100:.2f}%

Escenarios al final del horizonte:
  — P10 (pesimista, ~10% probabilidad peor): {p10_final:.2f} EUR
  — P50 (base, mediana):                     {p50_final:.2f} EUR
  — P90 (optimista, ~10% probabilidad mejor): {p90_final:.2f} EUR
  — Ratio Riesgo/Retorno (upside/downside):  {rr_ratio}x
""".strip()


# ---------------------------------------------------------------------------
# Llamada a Gemini con Exponential Backoff (síncrona, envuelta en asyncio)
# ---------------------------------------------------------------------------

async def _call_gemini_async(
    system_prompt: str,
    user_context: str,
    persona_name: str,
    max_retries: int = _MAX_RETRIES,
    temperature: float = _TEMPERATURE_PERSONAS,
) -> str:
    """Llama a Gemini de forma asíncrona (usando run_in_executor) con reintentos
    ante errores de cuota 429 / RESOURCE_EXHAUSTED.

    Parameters
    ----------
    system_prompt : str
        System instruction del agente (su persona).
    user_context : str
        Contexto financiero estructurado a analizar.
    persona_name : str
        Nombre identificativo del agente (solo para logs).
    max_retries : int
        Número máximo de reintentos ante 429.
    temperature : float
        Temperatura del modelo para esta llamada.

    Returns
    -------
    str
        Respuesta en texto del agente, o mensaje de fallback si falla.
    """
    loop = asyncio.get_event_loop()

    def _sync_call() -> str:
        client = _get_client()
        last_error: Optional[Exception] = None

        for attempt in range(1, max_retries + 1):
            for model_name in _CANDIDATE_MODELS:
                try:
                    response = client.models.generate_content(
                        model=model_name,
                        contents=user_context,
                        config=types.GenerateContentConfig(
                            system_instruction=system_prompt,
                            temperature=temperature,
                        ),
                    )
                    text = response.text.strip() if response and response.text else ""
                    if text:
                        print(f"[committee] ✓ {persona_name} respondió con {model_name} "
                              f"(intento {attempt})")
                        return text

                except errors.APIError as api_err:
                    code = getattr(api_err, "code", None)
                    err_str = str(api_err)

                    # 429 / cuota agotada → Exponential Backoff
                    if code == 429 or "RESOURCE_EXHAUSTED" in err_str or "quota" in err_str.lower():
                        wait = _BASE_BACKOFF_SECONDS * (2 ** (attempt - 1))
                        print(f"[committee] ⚠ {persona_name} — quota 429 en {model_name} "
                              f"(intento {attempt}/{max_retries}). "
                              f"Esperando {wait:.1f}s antes de reintentar…")
                        last_error = api_err
                        time.sleep(wait)
                        break  # Sale del loop de modelos, reintenta en el siguiente attempt

                    # Modelo no disponible → prueba el siguiente modelo
                    if code == 404:
                        print(f"[committee] Modelo {model_name} no disponible (404). "
                              f"Probando siguiente…")
                        last_error = api_err
                        continue

                    print(f"[committee] APIError en {model_name} para {persona_name}: {api_err}")
                    last_error = api_err
                    continue

                except Exception as exc:
                    print(f"[committee] Excepción en {model_name} para {persona_name}: {exc}")
                    last_error = exc
                    continue

        # Fallback si todos los intentos fallaron
        err_msg = str(last_error) if last_error else "error desconocido"
        print(f"[committee] ✗ {persona_name} — todos los intentos agotados. "
              f"Usando respuesta de contingencia. Último error: {err_msg}")
        return (
            f"[Análisis no disponible temporalmente — límite de cuota de API alcanzado. "
            f"Se omite la perspectiva del {persona_name} en esta sesión.]"
        )

    # Ejecutar la llamada síncrona en el thread pool del event loop
    return await loop.run_in_executor(None, _sync_call)


# ---------------------------------------------------------------------------
# Orquestador principal
# ---------------------------------------------------------------------------

async def run_investment_committee(
    user_query: str,
    portfolio_data: Dict[str, Any],
    montecarlo_data: Dict[str, Any],
) -> Dict[str, Any]:
    """Ejecuta el Comité de Inversión Multi-Agente de forma completamente asíncrona.

    Flujo:
    1. Construye el contexto financiero común a partir de portfolio_data y montecarlo_data.
    2. Lanza en paralelo (asyncio.gather) las llamadas a los 3 agentes especialistas.
    3. Consolida sus respuestas y las envía al Sintetizador (Lead Advisor).
    4. Devuelve el veredicto final junto al debate individual de cada agente.

    Parameters
    ----------
    user_query : str
        Consulta original del usuario en lenguaje natural.
    portfolio_data : dict
        Datos reales de la cartera del usuario (total_invested, current_value, pnl, etc.).
    montecarlo_data : dict
        Resultado de la simulación Monte Carlo (p10, p50, p90 finals, stats, etc.).

    Returns
    -------
    dict con claves:
        - ``final_advice``        : str — veredicto ejecutivo del Lead Advisor
        - ``committee_debate``    : dict — respuestas individuales de cada agente
        - ``action_executed``     : str — siempre "INVESTMENT_COMMITTEE"
        - ``committee_invoked``   : bool — True
    """
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        return _fallback_committee_response(user_query, portfolio_data, montecarlo_data)

    # Construir el contexto financiero compartido
    financial_context = _build_analyst_context(user_query, portfolio_data, montecarlo_data)

    print("[committee] 🚀 Lanzando 3 agentes en paralelo…")
    start_time = time.time()

    # Fase 1: Ejecución paralela de los 3 especialistas
    technical_task = _call_gemini_async(
        system_prompt=TECHNICAL_ANALYST_PROMPT,
        user_context=financial_context,
        persona_name="Analista Técnico",
    )
    macro_task = _call_gemini_async(
        system_prompt=MACRO_ECONOMIST_PROMPT,
        user_context=financial_context,
        persona_name="Economista Macro",
    )
    risk_task = _call_gemini_async(
        system_prompt=RISK_MANAGER_PROMPT,
        user_context=financial_context,
        persona_name="Gestor de Riesgos",
    )

    technical_opinion, macro_opinion, risk_opinion = await asyncio.gather(
        technical_task, macro_task, risk_task
    )

    elapsed_parallel = round(time.time() - start_time, 2)
    print(f"[committee] ✓ 3 agentes completados en {elapsed_parallel}s")

    # Fase 2: Síntesis por el Lead Advisor
    synthesis_prompt = f"""Recibes los análisis independientes de tres expertos del Comité de Inversión.
Tu misión: sintetizarlos en un único consejo ejecutivo con tu estilo Apple Finance.

=== CONSULTA ORIGINAL DEL USUARIO ===
{user_query}

=== OPINIÓN DEL ANALISTA TÉCNICO ===
{technical_opinion}

=== OPINIÓN DEL ECONOMISTA MACRO ===
{macro_opinion}

=== OPINIÓN DEL GESTOR DE RIESGOS ===
{risk_opinion}

Redacta ahora tu veredicto final siguiendo tu estructura obligatoria de 3 secciones \
(Diagnóstico, Recomendación, Horizonte). Máximo 150 palabras."""

    print("[committee] 🤖 Sintetizador procesando el debate…")
    final_advice = await _call_gemini_async(
        system_prompt=LEAD_ADVISOR_PROMPT,
        user_context=synthesis_prompt,
        persona_name="Lead Advisor (Sintetizador)",
        temperature=_TEMPERATURE_SYNTHESIS,
    )

    total_elapsed = round(time.time() - start_time, 2)
    print(f"[committee] ✅ Comité completado en {total_elapsed}s total")

    return {
        "final_advice": final_advice,
        "committee_debate": {
            "technical_analyst": technical_opinion,
            "macro_economist": macro_opinion,
            "risk_manager": risk_opinion,
            "lead_advisor": final_advice,
        },
        "action_executed": "INVESTMENT_COMMITTEE",
        "committee_invoked": True,
        "elapsed_seconds": total_elapsed,
    }


def _fallback_committee_response(
    user_query: str,
    portfolio_data: Dict[str, Any],
    montecarlo_data: Dict[str, Any],
) -> Dict[str, Any]:
    """Respuesta de contingencia cuando no hay API key configurada."""
    p50 = montecarlo_data.get("final_p50", 0.0)
    roi = portfolio_data.get("roi_pct", 0.0)
    ticker = montecarlo_data.get("ticker", "VWCE.DE")
    horizon_years = round(montecarlo_data.get("horizon_days", 1260) / 252, 1)

    advice = (
        f"**Diagnóstico**: Tu estrategia DCA en {ticker} presenta un ROI acumulado de {roi:+.1f}% "
        f"con una proyección base (P50) de {p50:.0f} EUR a {horizon_years} años.\n\n"
        f"**Recomendación**: Mantén la aportación mensual sistemática y revisa la diversificación "
        f"entre renta variable y oro en función del ciclo de tipos de interés vigente.\n\n"
        f"**Horizonte**: Revisa tu posición en 6 meses o ante un cambio de ciclo macro significativo."
    )

    fallback_msg = "[Análisis basado en datos históricos — API de IA no configurada]"

    return {
        "final_advice": advice,
        "committee_debate": {
            "technical_analyst": fallback_msg,
            "macro_economist": fallback_msg,
            "risk_manager": fallback_msg,
            "lead_advisor": advice,
        },
        "action_executed": "INVESTMENT_COMMITTEE",
        "committee_invoked": True,
        "elapsed_seconds": 0.0,
    }
