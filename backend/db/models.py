from datetime import datetime, timezone
from typing import Any, Dict
from sqlalchemy import Column, DateTime, Float, Integer, String, Text, func
from .database import Base


class EtfHistory(Base):
    """Modelo ORM para almacenar el registro histórico de cotizaciones,
    puntuación de sentimiento y resúmenes de inteligencia artificial de ETFs.
    """
    __tablename__ = "etf_history"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    ticker = Column(String(20), index=True, nullable=False)
    price = Column(Float, nullable=False)
    change_percent = Column(Float, nullable=False)
    sentiment_score = Column(Integer, nullable=False)
    ai_summary = Column(Text, nullable=False)
    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    def to_dict(self) -> Dict[str, Any]:
        """Convierte la entidad del modelo en un diccionario serializable."""
        return {
            "id": self.id,
            "ticker": self.ticker,
            "price": self.price,
            "change_percent": self.change_percent,
            "sentiment_score": self.sentiment_score,
            "ai_summary": self.ai_summary,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
        }

    def __repr__(self) -> str:
        return (
            f"<EtfHistory(id={self.id}, ticker='{self.ticker}', "
            f"price={self.price}, score={self.sentiment_score}, timestamp='{self.timestamp}')>"
        )
