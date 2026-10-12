"""Servicio y Adaptadores de Integración de Brokers (Open Banking & Live Broker API).
Implementa el patrón Adapter para abstraer la conectividad con diferentes entidades
financieras (ej. Trade Republic) y el orquestador de sincronización idempotente.
"""
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from db.models import BrokerAccount, Portfolio, SyncStatus, Transaction


class BaseBrokerAdapter(ABC):
    """Clase base abstracta que define la interfaz común para adaptadores de brokers."""

    @abstractmethod
    def get_portfolio_balance(self, account_reference: str) -> Dict[str, Any]:
        """Obtiene el balance de efectivo y valoración consolidada de la cartera."""
        pass

    @abstractmethod
    def get_transactions(self, account_reference: str) -> List[Dict[str, Any]]:
        """Extrae el histórico o últimas transacciones normalizadas en formato unificado."""
        pass


class TradeRepublicAdapter(BaseBrokerAdapter):
    """Adaptador concreto para la plataforma Trade Republic.
    Actualmente provee datos estructurados simulados (Mock) para ETFs y Oro físico.
    """

    def get_portfolio_balance(self, account_reference: str) -> Dict[str, Any]:
        """Extrae un mock de balance de efectivo y valoración de activos."""
        return {
            "broker": "Trade Republic",
            "account_reference": account_reference,
            "cash_balance": 185.50,
            "invested_balance": 3450.00,
            "total_value": 3635.50,
            "currency": "EUR",
            "last_updated": datetime.now(timezone.utc).isoformat(),
        }

    def get_transactions(self, account_reference: str) -> List[Dict[str, Any]]:
        """Extrae un mock de transacciones estructurado (ETFs y Oro físico)
        devolviendo una lista de diccionarios con formato unificado.
        """
        return [
            {
                "external_tx_id": "TR-TX-1001",
                "ticker": "VWCE.DE",
                "asset_class": "EQUITY",
                "shares": 1.25,
                "price_per_share": 160.00,
                "amount_invested": 200.00,
                "fee": 1.00,
                "broker_fee": 1.00,
                "currency": "EUR",
                "is_automated": True,
                "timestamp": datetime(2026, 10, 1, 9, 30, 0, tzinfo=timezone.utc),
            },
            {
                "external_tx_id": "TR-TX-1002",
                "ticker": "8PSG.DE",
                "asset_class": "GOLD",
                "shares": 2.00,
                "price_per_share": 45.00,
                "amount_invested": 90.00,
                "fee": 1.00,
                "broker_fee": 1.00,
                "currency": "EUR",
                "is_automated": True,
                "timestamp": datetime(2026, 10, 5, 14, 15, 0, tzinfo=timezone.utc),
            },
            {
                "external_tx_id": "TR-TX-1003",
                "ticker": "VWCE.DE",
                "asset_class": "EQUITY",
                "shares": 0.95,
                "price_per_share": 168.42,
                "amount_invested": 160.00,
                "fee": 1.00,
                "broker_fee": 1.00,
                "currency": "EUR",
                "is_automated": True,
                "timestamp": datetime(2026, 10, 10, 10, 0, 0, tzinfo=timezone.utc),
            },
        ]


# Registro de adaptadores soportados
BROKER_ADAPTERS: Dict[str, type] = {
    "trade republic": TradeRepublicAdapter,
    "traderepublic": TradeRepublicAdapter,
}


def get_broker_adapter(broker_name: str) -> BaseBrokerAdapter:
    """Instancia y retorna el adaptador apropiado para el broker especificado."""
    normalized_name = broker_name.strip().lower()
    adapter_cls = BROKER_ADAPTERS.get(normalized_name)
    if not adapter_cls:
        raise ValueError(f"Broker '{broker_name}' no soportado actualmente.")
    return adapter_cls()


def sync_broker_account(account_id: int, db: Session) -> Dict[str, Any]:
    """Servicio orquestador que:
    1. Localiza la cuenta de broker en la BD.
    2. Instancia el adaptador correcto según broker_name.
    3. Obtiene las transacciones en formato unificado.
    4. Mapea al modelo Transaction e inserta solo aquellas con external_tx_id no existentes (Idempotencia).
    5. Actualiza sync_status y last_synced_at.
    6. Ejecuta db.commit() y retorna el resultado.
    """
    broker_account = db.query(BrokerAccount).filter(BrokerAccount.id == account_id).first()
    if not broker_account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cuenta de broker con ID {account_id} no encontrada.",
        )

    # Identificar o crear la cartera del usuario
    portfolio = db.query(Portfolio).filter(Portfolio.user_id == broker_account.user_id).first()
    if not portfolio:
        portfolio = Portfolio(
            user_id=broker_account.user_id,
            name="Mi Cartera",
            currency="EUR",
            initial_balance=0.0,
        )
        db.add(portfolio)
        db.flush()

    # Instanciar el adaptador correspondiente
    try:
        adapter = get_broker_adapter(broker_account.broker_name)
    except ValueError as e:
        broker_account.sync_status = SyncStatus.ERROR
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    try:
        raw_transactions = adapter.get_transactions(broker_account.account_reference)
    except Exception as e:
        broker_account.sync_status = SyncStatus.ERROR
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Fallo al consultar la API del broker '{broker_account.broker_name}': {str(e)}",
        )

    synced_count = 0
    skipped_count = 0

    for tx_data in raw_transactions:
        ext_id = tx_data.get("external_tx_id")
        if not ext_id:
            continue

        # Verificación de Idempotencia: no duplicar si el external_tx_id ya existe
        existing_tx = (
            db.query(Transaction)
            .filter(Transaction.external_tx_id == ext_id)
            .first()
        )
        if existing_tx:
            skipped_count += 1
            continue

        # Mapear datos al modelo Transaction
        new_tx = Transaction(
            portfolio_id=portfolio.id,
            ticker=tx_data["ticker"],
            asset_class=tx_data.get("asset_class", "EQUITY"),
            shares=float(tx_data["shares"]),
            price_per_share=float(tx_data["price_per_share"]),
            amount_invested=float(tx_data["amount_invested"]),
            fee=float(tx_data.get("fee", 0.0)),
            broker_fee=float(tx_data.get("broker_fee", 0.0)),
            currency=tx_data.get("currency", "EUR"),
            is_automated=bool(tx_data.get("is_automated", True)),
            external_tx_id=ext_id,
            timestamp=tx_data.get("timestamp") or datetime.now(timezone.utc),
        )
        db.add(new_tx)
        synced_count += 1

    # Actualizar estado de la cuenta
    broker_account.sync_status = SyncStatus.SYNCED
    broker_account.last_synced_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(broker_account)

    return {
        "account_id": broker_account.id,
        "broker_name": broker_account.broker_name,
        "sync_status": broker_account.sync_status.value if hasattr(broker_account.sync_status, "value") else str(broker_account.sync_status),
        "synced_transactions": synced_count,
        "skipped_transactions": skipped_count,
        "last_synced_at": broker_account.last_synced_at,
        "message": (
            f"Sincronización completada con éxito. "
            f"{synced_count} nuevas transacciones añadidas, {skipped_count} duplicadas omitidas."
        ),
    }
