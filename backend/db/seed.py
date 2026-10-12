import logging
from typing import Optional
from .database import SessionLocal
from .models import Portfolio, SavingsPlan, User

logger = logging.getLogger(__name__)


def seed_demo_user() -> Optional[User]:
    """Inyecta un usuario 'Demo' por defecto en la base de datos si no existe,
    creando automáticamente su Portfolio inicial y su SavingsPlan configurado
    con 80% Renta Variable y 20% Oro.
    """
    db = SessionLocal()
    try:
        demo_user = db.query(User).filter(
            (User.username == "demo") | (User.email == "demo@example.com")
        ).first()

        if demo_user is None:
            demo_user = User(
                username="demo",
                email="demo@example.com",
            )
            db.add(demo_user)
            db.flush()

            # Crear cartera por defecto asociada al usuario
            portfolio = Portfolio(
                user_id=demo_user.id,
                name="Mi Cartera Principal",
                currency="EUR",
                initial_balance=0.0,
            )
            db.add(portfolio)
            db.flush()

            # Crear plan de ahorro DCA por defecto (200€/mes, 80% RV / 20% Oro)
            savings_plan = SavingsPlan(
                portfolio_id=portfolio.id,
                monthly_deposit=200.0,
                frequency="monthly",
                allocation_equity_pct=80.0,
                allocation_gold_pct=20.0,
                is_active=True,
            )
            db.add(savings_plan)
            db.commit()
            db.refresh(demo_user)

            print(
                f"[seed] Usuario 'Demo' inicializado con éxito "
                f"(User ID: {demo_user.id}, Portfolio ID: {portfolio.id})."
            )
            return demo_user
        else:
            print(f"[seed] Usuario 'Demo' ya existe en la base de datos (ID: {demo_user.id}).")
            # Verificar si tiene cartera asignada
            if not demo_user.portfolio:
                portfolio = Portfolio(
                    user_id=demo_user.id,
                    name="Mi Cartera Principal",
                    currency="EUR",
                    initial_balance=0.0,
                )
                db.add(portfolio)
                db.flush()

                savings_plan = SavingsPlan(
                    portfolio_id=portfolio.id,
                    monthly_deposit=200.0,
                    frequency="monthly",
                    allocation_equity_pct=80.0,
                    allocation_gold_pct=20.0,
                    is_active=True,
                )
                db.add(savings_plan)
                db.commit()
                print(f"[seed] Cartera y Plan de Ahorro inicializados para el usuario Demo.")
            return demo_user
    except Exception as e:
        db.rollback()
        print(f"[seed] Error al inicializar usuario Demo: {e}")
        return None
    finally:
        db.close()


if __name__ == "__main__":
    seed_demo_user()
