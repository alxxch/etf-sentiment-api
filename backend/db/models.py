import enum
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import Boolean, Column, DateTime, Enum as SQLEnum, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship
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


class User(Base):
    """Modelo ORM para usuarios de la plataforma Fintech."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relación One-to-One con Portfolio: un usuario posee una cartera
    portfolio = relationship(
        "Portfolio",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )

    # Relación One-to-Many con BrokerAccount: cuentas de brokers conectadas
    broker_accounts = relationship(
        "BrokerAccount",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="BrokerAccount.id.asc()",
    )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "email": self.email,
            "username": self.username,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"


class Portfolio(Base):
    """Modelo ORM para carteras de inversión."""
    __tablename__ = "portfolios"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    name = Column(String(100), default="Mi Cartera", nullable=False)
    currency = Column(String(10), default="EUR", nullable=False)
    initial_balance = Column(Float, default=0.0, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relación One-to-One inversa con User
    user = relationship("User", back_populates="portfolio")

    # Relación One-to-One con SavingsPlan: una cartera posee un plan de ahorro
    savings_plan = relationship(
        "SavingsPlan",
        back_populates="portfolio",
        uselist=False,
        cascade="all, delete-orphan",
    )

    # Relación One-to-Many con Transaction: una cartera posee múltiples transacciones
    transactions = relationship(
        "Transaction",
        back_populates="portfolio",
        cascade="all, delete-orphan",
        order_by="Transaction.timestamp.desc()",
    )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "currency": self.currency,
            "initial_balance": self.initial_balance,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<Portfolio(id={self.id}, user_id={self.user_id}, name='{self.name}')>"


class SavingsPlan(Base):
    """Modelo ORM para planes de ahorro sistemáticos (Dollar Cost Averaging - DCA)."""
    __tablename__ = "savings_plans"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    portfolio_id = Column(
        Integer,
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    monthly_deposit = Column(Float, nullable=False, default=200.0)
    frequency = Column(String(20), default="monthly", nullable=False)  # monthly, biweekly
    allocation_equity_pct = Column(Float, nullable=False, default=80.0)  # % para ETFs de renta variable
    allocation_gold_pct = Column(Float, nullable=False, default=20.0)    # % para Oro físico refugio
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=True,
    )

    # Relación One-to-One inversa con Portfolio
    portfolio = relationship("Portfolio", back_populates="savings_plan")

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "portfolio_id": self.portfolio_id,
            "monthly_deposit": self.monthly_deposit,
            "frequency": self.frequency,
            "allocation_equity_pct": self.allocation_equity_pct,
            "allocation_gold_pct": self.allocation_gold_pct,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self) -> str:
        return (
            f"<SavingsPlan(id={self.id}, portfolio_id={self.portfolio_id}, "
            f"monthly={self.monthly_deposit}, equity_pct={self.allocation_equity_pct}, "
            f"gold_pct={self.allocation_gold_pct})>"
        )


class Transaction(Base):
    """Modelo ORM para transacciones y aportaciones periódicas en la cartera."""
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    portfolio_id = Column(
        Integer,
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    ticker = Column(String(20), nullable=False, index=True)
    asset_class = Column(String(30), nullable=False, default="EQUITY")  # EQUITY, GOLD
    shares = Column(Float, nullable=False)
    price_per_share = Column(Float, nullable=False)
    amount_invested = Column(Float, nullable=False)
    external_tx_id = Column(String(100), unique=True, index=True, nullable=True)
    broker_fee = Column(Float, default=0.0, nullable=True)
    currency = Column(String(10), default="EUR", nullable=False)
    fee = Column(Float, default=0.0, nullable=False)
    is_automated = Column(Boolean, default=True, nullable=False)
    timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    # Relación Many-to-One con Portfolio
    portfolio = relationship("Portfolio", back_populates="transactions")

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "portfolio_id": self.portfolio_id,
            "external_tx_id": self.external_tx_id,
            "ticker": self.ticker,
            "asset_class": self.asset_class,
            "shares": self.shares,
            "price_per_share": self.price_per_share,
            "amount_invested": self.amount_invested,
            "fee": self.fee,
            "broker_fee": self.broker_fee,
            "currency": self.currency,
            "is_automated": self.is_automated,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
        }

    def __repr__(self) -> str:
        return (
            f"<Transaction(id={self.id}, portfolio_id={self.portfolio_id}, "
            f"ticker='{self.ticker}', shares={self.shares}, amount={self.amount_invested})>"
        )


class SyncStatus(str, enum.Enum):
    PENDING = "PENDING"
    SYNCED = "SYNCED"
    ERROR = "ERROR"


class BrokerAccount(Base):
    """Modelo ORM para cuentas conectadas de brokers (Open Banking & Live Broker API)."""
    __tablename__ = "broker_accounts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    broker_name = Column(String(100), nullable=False)  # ej. "Trade Republic"
    account_reference = Column(String(100), nullable=False)
    sync_status = Column(
        SQLEnum(SyncStatus, name="sync_status_enum"),
        default=SyncStatus.PENDING,
        nullable=False,
    )
    last_synced_at = Column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relación Many-to-One con User
    user = relationship("User", back_populates="broker_accounts")

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "broker_name": self.broker_name,
            "account_reference": self.account_reference,
            "sync_status": self.sync_status.value if hasattr(self.sync_status, "value") else str(self.sync_status),
            "last_synced_at": self.last_synced_at.isoformat() if self.last_synced_at else None,
        }

    def __repr__(self) -> str:
        return (
            f"<BrokerAccount(id={self.id}, user_id={self.user_id}, "
            f"broker='{self.broker_name}', status='{self.sync_status}')>"
        )
