from datetime import datetime
from typing import Any, Dict, List, Optional
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

# ============================================================================
# Schemas de Simulación DCA y Rendimiento vs Sentimiento
# ============================================================================

class DcaSimulationRequest(BaseModel):
    initial_capital: float = Field(
        default=0.0,
        ge=0.0,
        description="Capital inicial disponible antes de las aportaciones periódicas",
        examples=[0.0],
    )
    monthly_deposit: float = Field(
        default=200.0,
        ge=10.0,
        description="Aportación mensual en EUR",
        examples=[200.0],
    )
    months: int = Field(
        default=6,
        ge=1,
        le=60,
        description="Meses a simular retrospectivamente",
        examples=[6],
    )
    allocation_equity_pct: float = Field(
        default=80.0,
        ge=0.0,
        le=100.0,
        description="% Renta Variable (ej: VWCE.DE)",
        examples=[80.0],
    )
    allocation_gold_pct: float = Field(
        default=20.0,
        ge=0.0,
        le=100.0,
        description="% Oro físico cobertura (ej: 8PSG.DE)",
        examples=[20.0],
    )


class DcaStepPoint(BaseModel):
    month_index: int = Field(..., description="Índice secuencial del mes simulado")
    date: str = Field(..., description="Fecha de corte o aportación (YYYY-MM-DD)")
    cumulative_invested: float = Field(..., description="Capital acumulado aportado hasta este punto")
    portfolio_value: float = Field(..., description="Valoración real de los activos en esta fecha")
    pnl: float = Field(..., description="Beneficio / Pérdida en EUR")
    roi_pct: float = Field(..., description="Rentabilidad porcentual ROI")
    market_sentiment_score: int = Field(..., ge=0, le=100, description="Puntuación de sentimiento de mercado (0-100)")
    equity_price: float = Field(..., description="Precio de renta variable en el paso")
    gold_price: float = Field(..., description="Precio de oro en el paso")
    equity_shares_bought: float = Field(..., description="Participaciones de renta variable adquiridas")
    gold_shares_bought: float = Field(..., description="Participaciones de oro adquiridas")


class DcaSimulationResult(BaseModel):
    total_invested: float = Field(..., description="Total desembolsado en EUR")
    current_value: float = Field(..., description="Valor actual liquidativo")
    pnl: float = Field(..., description="Ganancia o pérdida absoluta")
    roi_pct: float = Field(..., description="Retorno sobre la inversión porcentual")
    equity_shares: float = Field(..., description="Participaciones acumuladas en renta variable")
    gold_shares: float = Field(..., description="Participaciones acumuladas en oro")
    break_even_equity: float = Field(..., description="Precio de equilibrio medio para renta variable")
    break_even_gold: float = Field(..., description="Precio de equilibrio medio para oro")
    current_equity_price: float = Field(..., description="Precio actual de cotización de renta variable")
    current_gold_price: float = Field(..., description="Precio actual de cotización del oro")
    transactions_count: int = Field(..., description="Número de operaciones simuladas")
    allocation_equity_pct: float = Field(..., description="% asignado a renta variable")
    allocation_gold_pct: float = Field(..., description="% asignado a oro")
    steps: List[DcaStepPoint] = Field(default=[], description="Serie temporal para graficar rentabilidad vs sentimiento")


class AssetAllocationItem(BaseModel):
    ticker: str = Field(..., description="Ticker del activo")
    asset_class: str = Field(..., description="Clase de activo (EQUITY o GOLD)")
    shares: float = Field(..., description="Total participaciones poseídas")
    current_price: float = Field(..., description="Precio unitario actual en EUR")
    current_value: float = Field(..., description="Valor total actual en EUR")
    allocation_pct: float = Field(..., description="Porcentaje real dentro del total de la cartera")
    break_even_price: float = Field(..., description="Precio medio de compra (Break-Even)")
    pnl: float = Field(..., description="P&L acumulado en EUR")
    roi_pct: float = Field(..., description="ROI acumulado en %")


class PortfolioStatusResponse(BaseModel):
    id: int
    user_id: int
    user_email: str
    user_name: str
    name: str
    currency: str
    initial_balance: float
    total_invested: float
    current_value: float
    pnl: float
    roi_pct: float
    market_sentiment_score: int
    asset_allocation: List[AssetAllocationItem] = []
    savings_plan: Optional[SavingsPlanResponse] = None
    transactions: List[TransactionResponse] = []


# ============================================================================
# Schemas del Asistente Conversacional Multimodal (NLP & Function Calling)
# ============================================================================

class AssistantChatRequest(BaseModel):
    user_prompt: str = Field(
        ...,
        min_length=1,
        description="Consulta o comando en lenguaje natural transcrito desde voz",
        examples=["Simula una aportación de 100 euros al oro"],
    )
    user_id: Optional[int] = Field(
        default=1,
        description="ID del usuario (por defecto 1 - Demo User)",
        examples=[1],
    )
    session_id: Optional[str] = Field(
        default=None,
        description="Identificador opcional de sesión para contexto conversacional",
        examples=["session_abc123"],
    )


class AssistantChatResponse(BaseModel):
    text_response: str = Field(
        ...,
        description="Respuesta redactada en lenguaje natural por Gemini",
        examples=["He simulado una aportación mensual de 100€ al oro..."],
    )
    action_type: str = Field(
        ...,
        description="Tipo normalizado de acción ejecutada (ej: PORTFOLIO_QUERY, DCA_SIMULATED, SAVINGS_PLAN_UPDATED, GENERAL_QUERY)",
        examples=["DCA_SIMULATED"],
    )
    action_executed: Optional[str] = Field(
        default=None,
        description="Nombre de la herramienta o función ejecutada (ej: simulate_dca_plan)",
        examples=["simulate_dca_plan"],
    )
    tool_args: Dict[str, Any] = Field(
        default_factory=dict,
        description="Parámetros estructurados extraídos por Gemini",
        examples=[{"monthly_deposit": 100.0, "allocation_gold_pct": 100.0}],
    )
    data_payload: Dict[str, Any] = Field(
        default_factory=dict,
        description="Datos resultantes de la operación (para sincronización de interfaz)",
    )
    audio_base64: Optional[str] = Field(
        default=None,
        description="Audio narrado sintetizado con ElevenLabs (Fase 12)",
    )


