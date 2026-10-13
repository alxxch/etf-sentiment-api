"""Re-exportación del servicio de IA desde el módulo raíz ai_service.py
Permite importar tanto desde `ai_service` como desde `services.ai_service`.
"""
import sys
import os

# Asegurar que el directorio backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from ai_service import (
    GeminiRateLimitException,
    analyze_sentiment,
    process_assistant_message,
    ASSISTANT_SYSTEM_PROMPT,
)

from services.multi_agent_orchestrator import run_investment_committee  # noqa: F401

__all__ = [
    "GeminiRateLimitException",
    "analyze_sentiment",
    "process_assistant_message",
    "ASSISTANT_SYSTEM_PROMPT",
    "run_investment_committee",
]
