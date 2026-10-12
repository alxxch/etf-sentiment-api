"""Router de Open Banking y Conectividad con Brokers.
Endpoints REST para vincular cuentas de entidades financieras externas (ej. Trade Republic),
consultar cuentas asociadas y ejecutar sincronización idempotente de carteras y transacciones.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import BrokerAccount, SyncStatus, User
from schemas import BrokerAccountCreate, BrokerAccountResponse, SyncResponse
from services.broker_service import sync_broker_account

router = APIRouter()


@router.post(
    "/link-account",
    response_model=BrokerAccountResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registra una nueva cuenta de broker conectado",
)
def link_broker_account(
    payload: BrokerAccountCreate,
    db: Session = Depends(get_db),
) -> BrokerAccount:
    """Vincula una nueva cuenta de broker externo para el usuario indicado.
    Si el usuario no existe, valida y asigna al usuario Demo predeterminado.
    """
    user_id = payload.user_id or 1
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        # Fallback al primer usuario existente si el ID específico no se encuentra
        user = db.query(User).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Usuario con ID {user_id} no encontrado en la base de datos.",
            )
        user_id = user.id

    new_account = BrokerAccount(
        user_id=user_id,
        broker_name=payload.broker_name.strip(),
        account_reference=payload.account_reference.strip(),
        sync_status=SyncStatus.PENDING,
    )
    db.add(new_account)
    db.commit()
    db.refresh(new_account)
    return new_account


@router.post(
    "/sync/{account_id}",
    response_model=SyncResponse,
    status_code=status.HTTP_200_OK,
    summary="Dispara la sincronización bajo demanda para una cuenta de broker",
)
def trigger_broker_sync(
    account_id: int,
    db: Session = Depends(get_db),
) -> SyncResponse:
    """Orquesta la sincronización de transacciones con el broker asociado a la cuenta.
    Garantiza idempotencia mediante la verificación del identificador único `external_tx_id`.
    """
    sync_result = sync_broker_account(account_id=account_id, db=db)
    return SyncResponse(**sync_result)


@router.get(
    "/accounts",
    response_model=List[BrokerAccountResponse],
    status_code=status.HTTP_200_OK,
    summary="Lista los brokers conectados para el usuario",
)
def get_broker_accounts(
    user_id: Optional[int] = Query(default=1, description="ID del usuario a consultar"),
    db: Session = Depends(get_db),
) -> List[BrokerAccount]:
    """Retorna todas las cuentas de brokers vinculadas por el usuario."""
    query = db.query(BrokerAccount)
    if user_id is not None:
        query = query.filter(BrokerAccount.user_id == user_id)
    accounts = query.order_by(BrokerAccount.id.asc()).all()
    return accounts
