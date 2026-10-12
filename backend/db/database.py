import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Cargar variables de entorno desde backend/.env o la raíz
load_dotenv(dotenv_path=os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"))
load_dotenv()

# URL de conexión a la base de datos (PostgreSQL por defecto)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/etf_db",
)

# Compatibilidad con prefijos 'postgres://' y normalización para driver psycopg2 en SQLAlchemy 2.x
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)
elif DATABASE_URL.startswith("postgresql://") and not DATABASE_URL.startswith("postgresql+"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

# Argumentos adicionales según el dialecto
connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

# Motor de base de datos con verificación previa de conexión activa (pool_pre_ping)
engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
    echo=False,
)

# Fábrica de sesiones
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# Base declarativa para modelos ORM
Base = declarative_base()


def get_db():
    """Generador de sesiones de base de datos para inyección de dependencias en FastAPI.
    Garantiza que la sesión se cierre adecuadamente al finalizar cada petición.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
