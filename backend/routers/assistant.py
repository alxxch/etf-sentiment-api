"""Router del Asistente Financiero Inteligente (Voice & NLP Assistant).
Expone endpoints para procesar consultas en lenguaje natural mediante Function Calling
con Google Gemini 2.5, interactuando con la base de datos PostgreSQL y motores DCA.
"""
from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ai_service import process_assistant_message
from db.database import get_db
from schemas import AssistantChatRequest, AssistantChatResponse
from tts_service import generate_speech

router = APIRouter()

# Mapeo de nombres de herramientas a tipos de acción estandarizados
ACTION_TYPE_MAP = {
    "simulate_dca_plan": "DCA_SIMULATED",
    "get_portfolio_summary": "PORTFOLIO_QUERY",
    "get_market_sentiment": "MARKET_SENTIMENT_QUERY",
    "update_savings_plan": "SAVINGS_PLAN_UPDATED",
    "GENERAL_QUERY": "GENERAL_QUERY",
}


@router.post(
    "/chat",
    response_model=AssistantChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Procesa comandos de voz o texto del asistente financiero mediante Gemini Function Calling",
)
def chat_assistant(
    request: AssistantChatRequest,
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Recibe la consulta transcrita del usuario (ej: 'Simula una aportación de 100 euros al oro'),
    ejecuta el bucle de Function Calling con Gemini, resuelve las operaciones contra PostgreSQL
    y el motor DCA de la v3.0, genera la síntesis por voz con ElevenLabs (t9LRTh3y1ioN00e9wsNh)
    y retorna la respuesta multimodal con el payload estructurado.
    """
    clean_prompt = request.user_prompt.strip()
    if not clean_prompt:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El campo 'user_prompt' no puede estar vacío.",
        )

    try:
        result = process_assistant_message(
            user_prompt=clean_prompt,
            db=db,
            user_id=request.user_id or 1,
        )

        action_executed = result.get("action_executed", "GENERAL_QUERY")
        action_type = ACTION_TYPE_MAP.get(action_executed, action_executed)
        text_response = result.get("text_response", "")

        # Generar síntesis de voz con ElevenLabs (Voz t9LRTh3y1ioN00e9wsNh, eleven_multilingual_v2)
        audio_base64 = generate_speech(text_response)

        return {
            "text_response": text_response,
            "action_type": action_type,
            "action_executed": action_executed,
            "tool_args": result.get("tool_args", {}),
            "data_payload": result.get("data_payload", {}),
            "audio_base64": audio_base64,
        }
    except Exception as e:
        print(f"[assistant] Error procesando consulta: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno procesando la consulta del asistente: {str(e)}",
        )
