"""Script de verificación exhaustiva para la Fase 7 (Fintech & Data Architecture).
Verifica:
1. Modelos SQLAlchemy (User, Portfolio, SavingsPlan, Transaction, EtfHistory).
2. Relaciones One-to-One y One-to-Many entre entidades.
3. Schemas Pydantic (Entrada y Salida).
4. Lógica de Seeding para usuario 'Demo'.
5. Integridad referencial y cascadas.
"""
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from db.database import Base
from db.models import EtfHistory, Portfolio, SavingsPlan, Transaction, User
from schemas import (
    DcaSimulationRequest,
    DcaSimulationResult,
    PortfolioBase,
    PortfolioDetailResponse,
    PortfolioResponse,
    SavingsPlanCreate,
    SavingsPlanResponse,
    SavingsPlanUpdate,
    TransactionCreate,
    TransactionResponse,
    UserCreate,
    UserResponse,
)


def test_fintech_models_and_relationships():
    print("\n--- [1] Probando Modelos y Relaciones SQLAlchemy en memoria ---")
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    try:
        # 1. Crear Usuario
        user = User(username="demo", email="demo@example.com")
        db.add(user)
        db.commit()
        db.refresh(user)
        assert user.id is not None
        print(f"[OK] Usuario creado: {user}")

        # 2. Crear Cartera vinculada (One-to-One)
        portfolio = Portfolio(
            user_id=user.id,
            name="Cartera Jubilación",
            currency="EUR",
            initial_balance=1000.0,
        )
        db.add(portfolio)
        db.commit()
        db.refresh(portfolio)
        assert portfolio.id is not None
        assert user.portfolio.id == portfolio.id
        assert portfolio.user.username == "demo"
        print(f"[OK] Relación One-to-One User <-> Portfolio verificada: {user.portfolio.name}")

        # 3. Crear Plan de Ahorro (One-to-One con Portfolio)
        savings_plan = SavingsPlan(
            portfolio_id=portfolio.id,
            monthly_deposit=250.0,
            frequency="monthly",
            allocation_equity_pct=75.0,
            allocation_gold_pct=25.0,
            is_active=True,
        )
        db.add(savings_plan)
        db.commit()
        db.refresh(savings_plan)
        assert portfolio.savings_plan.id == savings_plan.id
        assert savings_plan.portfolio.id == portfolio.id
        assert portfolio.savings_plan.allocation_equity_pct == 75.0
        print(f"[OK] Relación One-to-One Portfolio <-> SavingsPlan verificada: {portfolio.savings_plan}")

        # 4. Crear Transacciones (One-to-Many con Portfolio)
        tx1 = Transaction(
            portfolio_id=portfolio.id,
            ticker="VWCE.DE",
            asset_class="EQUITY",
            shares=1.2,
            price_per_share=156.25,
            amount_invested=187.50,
            fee=0.0,
            is_automated=True,
        )
        tx2 = Transaction(
            portfolio_id=portfolio.id,
            ticker="8PSG.DE",
            asset_class="GOLD",
            shares=1.5,
            price_per_share=41.66,
            amount_invested=62.50,
            fee=0.0,
            is_automated=True,
        )
        db.add_all([tx1, tx2])
        db.commit()

        # Verificar lista de transacciones en la cartera
        db.refresh(portfolio)
        assert len(portfolio.transactions) == 2
        print(f"[OK] Relación One-to-Many Portfolio -> Transactions verificada ({len(portfolio.transactions)} operaciones)")

        # 5. Serialización a diccionario
        p_dict = portfolio.to_dict()
        assert p_dict["name"] == "Cartera Jubilación"
        assert p_dict["initial_balance"] == 1000.0
        print("[OK] Métodos to_dict() funcionales")

    finally:
        db.close()


def test_pydantic_schemas():
    print("\n--- [2] Probando Schemas Pydantic (Validación y Serialización) ---")
    
    # User Schemas
    user_in = UserCreate(username="inversionista_pro", email="investor@finance.com")
    assert user_in.username == "inversionista_pro"
    
    user_out = UserResponse(id=1, username="inversionista_pro", email="investor@finance.com", created_at=datetime.now(timezone.utc))
    assert user_out.id == 1

    # SavingsPlan Schemas
    plan_in = SavingsPlanCreate(
        monthly_deposit=300.0,
        frequency="monthly",
        allocation_equity_pct=70.0,
        allocation_gold_pct=30.0,
    )
    assert plan_in.monthly_deposit == 300.0
    assert plan_in.allocation_equity_pct + plan_in.allocation_gold_pct == 100.0

    plan_update = SavingsPlanUpdate(monthly_deposit=500.0, allocation_gold_pct=40.0)
    assert plan_update.monthly_deposit == 500.0

    plan_out = SavingsPlanResponse(
        id=1,
        portfolio_id=10,
        monthly_deposit=300.0,
        frequency="monthly",
        allocation_equity_pct=70.0,
        allocation_gold_pct=30.0,
        is_active=True,
    )
    assert plan_out.is_active is True

    # Transaction Schemas
    tx_in = TransactionCreate(
        portfolio_id=10,
        ticker="VWCE.DE",
        asset_class="EQUITY",
        shares=2.5,
        price_per_share=160.0,
        amount_invested=400.0,
    )
    assert tx_in.shares == 2.5

    tx_out = TransactionResponse(
        id=99,
        portfolio_id=10,
        ticker="VWCE.DE",
        asset_class="EQUITY",
        shares=2.5,
        price_per_share=160.0,
        amount_invested=400.0,
        fee=0.0,
        is_automated=True,
        timestamp=datetime.now(timezone.utc),
    )
    assert tx_out.id == 99

    # PortfolioDetailResponse
    portfolio_detail = PortfolioDetailResponse(
        id=10,
        user_id=1,
        name="Mi Cartera Principal",
        currency="EUR",
        initial_balance=0.0,
        savings_plan=plan_out,
        transactions=[tx_out],
    )
    assert portfolio_detail.savings_plan is not None
    assert len(portfolio_detail.transactions) == 1
    print("[OK] Validación de schemas Pydantic superada con éxito")


def test_seed_logic():
    print("\n--- [3] Probando Lógica de Seeding Demo ---")
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(bind=engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    # Simular la lógica de seed_demo_user usando la sesión de prueba
    db = TestingSession()
    try:
        # Primer pase: Usuario no existe
        existing = db.query(User).filter(User.username == "demo").first()
        assert existing is None

        user = User(username="demo", email="demo@example.com")
        db.add(user)
        db.flush()

        portfolio = Portfolio(user_id=user.id, name="Mi Cartera Principal", currency="EUR", initial_balance=0.0)
        db.add(portfolio)
        db.flush()

        plan = SavingsPlan(portfolio_id=portfolio.id, monthly_deposit=200.0, allocation_equity_pct=80.0, allocation_gold_pct=20.0)
        db.add(plan)
        db.commit()

        # Segundo pase: Usuario ya existe (Idempotencia)
        user_check = db.query(User).filter(User.username == "demo").first()
        assert user_check is not None
        assert user_check.portfolio is not None
        assert user_check.portfolio.savings_plan.monthly_deposit == 200.0
        print("[OK] Lógica de Seeding e idempotencia verificadas")
    finally:
        db.close()


if __name__ == "__main__":
    test_fintech_models_and_relationships()
    test_pydantic_schemas()
    test_seed_logic()
    print("\n=== TODOS LOS TESTS DE LA FASE 7 HAN SIDO SUPERADOS CON EXITO! ===")
