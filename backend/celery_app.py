import os
from celery import Celery
from celery.schedules import crontab
from dotenv import load_dotenv

# Cargar variables de entorno desde backend/.env o la raíz
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()

# URL de conexión a Redis (broker y backend de resultados)
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

# Instancia principal de Celery
celery_app = Celery(
    "etf_sentiment_tasks",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=["tasks"],
)

# Configuración de Celery y programación periódica (Beat)
celery_app.conf.update(
    timezone="Europe/Madrid",  # Hora Central Europea (CET)
    enable_utc=True,
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    result_expires=3600,
    beat_schedule={
        "daily-market-close-etf-analysis": {
            "task": "tasks.analyze_daily_market",
            # De lunes a viernes (1-5) a las 18:00 CET (cierre de mercados europeos)
            "schedule": crontab(hour=18, minute=0, day_of_week="1-5"),
        },
    },
)

if __name__ == "__main__":
    celery_app.start()
