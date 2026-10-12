from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


# ============================================================================
# Schemas de Usuario (User)
# ============================================================================

class UserBase(BaseModel):
    username: str = Field(..., description="Nombre de usuario", examples=["demo_user"])
    email: str = Field(..., description="Correo electrónico", examples=["demo@example.com"])


class UserCreate(UserBase):
    pass


class UserResponse(UserBase):
    id: int
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Schemas de Plan de Ahorro (SavingsPlan)
# ============================================================================

class SavingsPlanBase(BaseModel):
    monthly_deposit: float = Field(
        default=200.0,
        ge=10.0,
        description="Aportación periódica en EUR",
        examples=[200.0],
    )
    frequency: str = Field(
        default="monthly",
        description="Frecuencia de las aportaciones (monthly, biweekly)",
        examples=["monthly"],
    )
    allocation_equity_pct: float = Field(
        default=80.0,
        ge=0.0,
        le=100.0,
        description="Porcentaje asignado a ETFs de renta variable",
        examples=[80.0],
    )
    allocation_gold_pct: float = Field(
        default=20.0,
        ge=0.0,
        le=100.0,
        description="Porcentaje asignado a oro físico de cobertura",
        examples=[20.0],
    )
    is_active: bool = Field(default=True, description="Estado activo del plan")


class SavingsPlanCreate(SavingsPlanBase):
    portfolio_id: Optional[int] = Field(default=None, description="ID de la cartera a la que pertenece")


class SavingsPlanUpdate(BaseModel):
    monthly_deposit: Optional[float] = Field(default=None, ge=10.0)
    frequency: Optional[str] = None
    allocation_equity_pct: Optional[float] = Field(default=None, ge=0.0, le=100.0)
    allocation_gold_pct: Optional[float] = Field(default=None, ge=0.0, le=100.0)
    is_active: Optional[bool] = None


class SavingsPlanResponse(SavingsPlanBase):
    id: int
    portfolio_id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Schemas de Transacciones (Transaction)
# ============================================================================

class TransactionBase(BaseModel):
    ticker: str = Field(..., description="Símbolo del activo (ej: VWCE.DE, 8PSG.DE)", examples=["VWCE.DE"])
    asset_class: str = Field(
        default="EQUITY",
        description="Clase de activo (EQUITY o GOLD)",
        examples=["EQUITY"],
    )
    shares: float = Field(..., gt=0, description="Número de participaciones adquiridas", examples=[1.25])
    price_per_share: float = Field(..., gt=0, description="Precio por participación en EUR", examples=[160.0])
    amount_invested: float = Field(..., gt=0, description="Monto total invertido en EUR", examples=[200.0])
    fee: float = Field(default=0.0, ge=0, description="Comisión aplicada", examples=[0.0])
    is_automated: bool = Field(default=True, description="Generado automáticamente por DCA")


class TransactionCreate(TransactionBase):
    portfolio_id: Optional[int] = Field(default=None, description="ID de la cartera")


class TransactionResponse(TransactionBase):
    id: int
    portfolio_id: int
    timestamp: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Schemas de Cartera (Portfolio)
# ============================================================================

class PortfolioBase(BaseModel):
    name: str = Field(default="Mi Cartera", description="Nombre descriptivo de la cartera", examples=["Mi Cartera"])
    currency: str = Field(default="EUR", description="Divisa base", examples=["EUR"])
    initial_balance: float = Field(default=0.0, ge=0, description="Saldo inicial disponible", examples=[0.0])


class PortfolioCreate(PortfolioBase):
    user_id: Optional[int] = Field(default=None, description="ID del usuario propietario")


class PortfolioResponse(PortfolioBase):
    id: int
    user_id: int
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class PortfolioDetailResponse(PortfolioResponse):
    savings_plan: Optional[SavingsPlanResponse] = None
    transactions: List[TransactionResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Schemas de Simulación DCA y Rendimiento
# ============================================================================

class DcaSimulationRequest(BaseModel):
    monthly_deposit: float = Field(default=200.0, ge=10.0, description="Aportación mensual en EUR")
    months: int = Field(default=6, ge=1, le=60, description="Meses a simular retrospectivamente")
    allocation_equity_pct: float = Field(default=80.0, ge=0.0, le=100.0, description="% Renta Variable")
    allocation_gold_pct: float = Field(default=20.0, ge=0.0, le=100.0, description="% Oro físico")


class DcaSimulationResult(BaseModel):
    total_invested: float = Field(..., description="Total desembolsado en EUR")
    current_value: float = Field(..., description="Valor actual liquidativo")
    pnl: float = Field(..., description="Ganancia o pérdida absoluta")
    roi_pct: float = Field(..., description="Retorno sobre la inversión porcentual")
    equity_shares: float = Field(..., description="Participaciones acumuladas en renta variable")
    gold_shares: float = Field(..., description="Participaciones acumuladas en oro")
    transactions_count: int = Field(..., description="Número de operaciones simuladas")
