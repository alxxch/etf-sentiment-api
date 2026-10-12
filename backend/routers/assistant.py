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

router = APIRouter()


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
    y el motor DCA de la v3.0, y retorna la respuesta ejecutiva con el payload de datos estructurados.
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
        return result
    except Exception as e:
        print(f"[assistant] Error procesando consulta: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno procesando la consulta del asistente: {str(e)}",
        )
