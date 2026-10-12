"""Router de Notificaciones y Alertas Proactivas (Fase 15).
Endpoints REST para listar las notificaciones del usuario ordenadas cronológicamente
y marcar alertas como leídas.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from db.database import get_db
from db.models import Notification, User
from schemas import NotificationResponse

router = APIRouter()


@router.get(
    "",
    response_model=List[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Lista las notificaciones del usuario ordenadas por fecha reciente",
)
@router.get(
    "/",
    response_model=List[NotificationResponse],
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_user_notifications(
    user_id: Optional[int] = Query(default=1, description="ID del usuario (por defecto 1 - Demo User)"),
    unread_only: bool = Query(default=False, description="Filtrar únicamente alertas pendientes de leer"),
    limit: int = Query(default=50, ge=1, le=200, description="Número máximo de notificaciones a devolver"),
    db: Session = Depends(get_db),
) -> List[Notification]:
    """Obtiene la lista de notificaciones proactivas (DRIFT, OPPORTUNITY, SYSTEM)
    del usuario ordenadas cronológicamente de forma descendente.
    """
    query = db.query(Notification)

    if user_id is not None:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            query = query.filter(Notification.user_id == user.id)

    if unread_only:
        query = query.filter(Notification.is_read.is_(False))

    notifications = query.order_by(Notification.timestamp.desc()).limit(limit).all()
    return notifications


@router.patch(
    "/{id}/read",
    response_model=NotificationResponse,
    status_code=status.HTTP_200_OK,
    summary="Marca una notificación como leída",
)
def mark_notification_as_read(
    id: int,
    db: Session = Depends(get_db),
) -> Notification:
    """Actualiza el estado de una notificación a `is_read=True`."""
    notification = db.query(Notification).filter(Notification.id == id).first()
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Notificación con ID {id} no encontrada.",
        )

    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification

