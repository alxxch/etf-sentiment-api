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
    broker_fee: Optional[float] = Field(default=0.0, ge=0, description="Comisión del broker", examples=[0.0])
    currency: str = Field(default="EUR", description="Divisa de la transacción", examples=["EUR"])
    is_automated: bool = Field(default=True, description="Generado automáticamente por DCA")
    external_tx_id: Optional[str] = Field(default=None, description="Identificador externo del broker para idempotencia")


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


# ============================================================================
# Schemas de Open Banking y Brokers (BrokerAccount & Sync)
# ============================================================================

class BrokerAccountBase(BaseModel):
    broker_name: str = Field(
        ...,
        description="Nombre de la entidad o broker (ej: Trade Republic)",
        examples=["Trade Republic"],
    )
    account_reference: str = Field(
        ...,
        description="Número de cuenta o referencia externa del broker",
        examples=["TR-ES-984210"],
    )


class BrokerAccountCreate(BrokerAccountBase):
    user_id: Optional[int] = Field(
        default=1,
        description="Identificador del usuario propietario (por defecto 1 - Demo User)",
        examples=[1],
    )


class BrokerAccountResponse(BrokerAccountBase):
    id: int
    user_id: int
    sync_status: str = Field(..., description="Estado de sincronización (PENDING, SYNCED, ERROR)")
    last_synced_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class SyncResponse(BaseModel):
    account_id: int = Field(..., description="ID de la cuenta de broker sincronizada")
    broker_name: str = Field(..., description="Nombre del broker")
    sync_status: str = Field(..., description="Estado final de la sincronización")
    synced_transactions: int = Field(..., description="Número de transacciones nuevas añadidas")
    skipped_transactions: int = Field(..., description="Número de transacciones duplicadas omitidas")
    last_synced_at: Optional[datetime] = Field(None, description="Marca de tiempo de la última sincronización")
    message: str = Field(..., description="Mensaje descriptivo del resultado")


# ============================================================================
# Schemas de Rebalanceo Inteligente (Rebalance Advice)
# ============================================================================

class AssetRebalanceItem(BaseModel):
    ticker: str = Field(..., description="Ticker del activo (ej: VWCE.DE, 8PSG.DE)", examples=["VWCE.DE"])
    asset_class: str = Field(..., description="Clase de activo (EQUITY o GOLD)", examples=["EQUITY"])
    current_value: float = Field(..., description="Valor actual de mercado en EUR", examples=[1200.0])
    current_allocation_pct: float = Field(..., description="Porcentaje real en cartera (0-100)", examples=[85.7])
    target_allocation_pct: float = Field(..., description="Porcentaje objetivo según plan (0-100)", examples=[80.0])
    drift_pct: float = Field(..., description="Desviación porcentual (actual - objetivo)", examples=[5.7])
    drift_amount: float = Field(..., description="Desviación absoluta en EUR frente al ideal actual", examples=[80.0])
    suggested_deposit: float = Field(..., description="Monto sugerido de la aportación mensual en EUR", examples=[120.0])
    suggested_deposit_pct: float = Field(..., description="Porcentaje de la aportación mensual asignado (0-100)", examples=[60.0])
    projected_value: float = Field(..., description="Valoración proyectada tras la aportación sugerida", examples=[1320.0])
    projected_allocation_pct: float = Field(..., description="Porcentaje proyectado tras la aportación sugerida", examples=[82.5])


class RebalanceAdviceResponse(BaseModel):
    portfolio_id: int = Field(..., description="ID de la cartera analizada")
    user_id: int = Field(..., description="ID del usuario propietario")
    current_portfolio_value: float = Field(..., description="Valor total actual de la cartera en EUR", examples=[1400.0])
    monthly_deposit: float = Field(..., description="Aportación mensual disponible para rebalancear en EUR", examples=[200.0])
    post_rebalance_portfolio_value: float = Field(..., description="Valor total proyectado tras la aportación", examples=[1600.0])
    rebalance_status: str = Field(..., description="Estado del rebalanceo: BALANCED, FULLY_REBALANCED, PARTIALLY_REBALANCED", examples=["FULLY_REBALANCED"])
    summary_message: str = Field(..., description="Directriz matemática explicativa para el usuario")
    assets: List[AssetRebalanceItem] = Field(default=[], description="Desglose por activo de desviaciones y asignación recomendada")


# ============================================================================
# Schemas de Notificaciones y Alertas (Fase 15)
# ============================================================================

class NotificationResponse(BaseModel):
    id: int
    user_id: int
    title: str = Field(..., description="Título de la notificación")
    message: str = Field(..., description="Contenido explicativo de la notificación")
    type: str = Field(..., description="Tipo de notificación: OPPORTUNITY, DRIFT, SYSTEM")
    is_read: bool = Field(..., description="Indica si la alerta ha sido leída")
    timestamp: datetime = Field(..., description="Fecha y hora de creación de la alerta")

    model_config = ConfigDict(from_attributes=True)

# ============================================================================
# Schemas de Simulación Monte Carlo — Fase 24 (Predictive Analytics)
# ============================================================================

class MonteCarloRequest(BaseModel):
    """Parámetros de entrada para la simulación Monte Carlo sobre datos históricos de ETFs."""

    ticker: str = Field(
        default="VWCE.DE",
        description="Símbolo del ETF sobre el que se proyecta la simulación",
        examples=["VWCE.DE"],
    )
    horizon_days: int = Field(
        default=1260,
        ge=5,
        le=7560,
        description="Horizonte temporal en días hábiles a proyectar (por defecto 252 * 5 = 1 260 días)",
        examples=[1260],
    )
    n_simulations: int = Field(
        default=5000,
        ge=100,
        le=50000,
        description="Número de trayectorias Monte Carlo (por defecto 5 000)",
        examples=[5000],
    )
    initial_investment: float = Field(
        default=10000.0,
        ge=0.0,
        description="Capital inicial a proyectar en EUR",
        examples=[10000.0],
    )
    monthly_contribution: float = Field(
        default=200.0,
        ge=0.0,
        description="Aportación mensual adicional en EUR (contribución DCA)",
        examples=[200.0],
    )


class MonteCarloProjectionPoint(BaseModel):
    """Punto de proyección para una banda percentil de la simulación Monte Carlo."""

    day: int = Field(..., description="Índice del día proyectado desde el inicio (0 = hoy)")
    value: float = Field(..., description="Valor proyectado de la cartera en EUR")


class MonteCarloResponse(BaseModel):
    """Respuesta de la simulación Monte Carlo con bandas P10, P50 y P90."""

    ticker: str = Field(..., description="Símbolo del ETF analizado")
    horizon_days: int = Field(..., description="Horizonte temporal de la proyección en días hábiles")
    n_simulations: int = Field(..., description="Número de trayectorias simuladas")
    initial_investment: float = Field(..., description="Capital inicial proyectado en EUR")
    monthly_contribution: float = Field(..., description="Aportación mensual en EUR")

    # Arrays de proyección para cada escenario (longitud = horizon_days + 1)
    p10: List[float] = Field(
        ...,
        description="Escenario pesimista — Percentil 10: el 90 % de los escenarios supera este valor",
    )
    p50: List[float] = Field(
        ...,
        description="Escenario base — Percentil 50 (mediana): trayectoria central",
    )
    p90: List[float] = Field(
        ...,
        description="Escenario optimista — Percentil 90: solo el 10 % de los escenarios supera este valor",
    )
    days: List[int] = Field(
        ...,
        description="Índices de día correspondientes [0, 1, …, horizon_days]",
    )

    # Estadísticas del modelo calibrado con la serie histórica
    mean_daily_return: float = Field(..., description="Retorno medio diario del activo (µ) estimado")
    std_daily_return: float = Field(..., description="Volatilidad diaria del activo (σ) estimada")
    annualized_return: float = Field(..., description="Retorno anualizado estimado")
    annualized_vol: float = Field(..., description="Volatilidad anualizada estimada")

    # Valores finales resumidos (último día)
    final_p10: float = Field(..., description="Valor final proyectado en el escenario pesimista (P10)")
    final_p50: float = Field(..., description="Valor final proyectado en el escenario base (P50)")
    final_p90: float = Field(..., description="Valor final proyectado en el escenario optimista (P90)")

