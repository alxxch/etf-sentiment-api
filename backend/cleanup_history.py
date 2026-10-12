import os
import sys
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()

from db import EtfHistory, SessionLocal


def cleanup_fallback_records() -> int:
    """Elimina registros en etf_history generados por caídas de cuota o rate limits de Gemini."""
    db = SessionLocal()
    try:
        query = db.query(EtfHistory).filter(
            EtfHistory.ai_summary.ilike("%Límite temporal de peticiones%")
            | EtfHistory.ai_summary.ilike("%Limite temporal de peticiones%")
            | EtfHistory.ai_summary.ilike("%GEMINI_API_KEY no configurada%")
            | EtfHistory.ai_summary.ilike("%RESOURCE_EXHAUSTED%")
        )
        count = query.count()
        if count > 0:
            deleted = query.delete(synchronize_session=False)
            db.commit()
            print(f"[cleanup] Limpieza completada: {deleted} registros con cuota saturada eliminados.")
            return deleted
        else:
            print("[cleanup] No se encontraron registros con mensajes de cuota o fallback.")
            return 0
    except Exception as e:
        db.rollback()
        print(f"[cleanup] Error durante la limpieza: {e}")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    deleted_count = cleanup_fallback_records()
    sys.exit(0)
