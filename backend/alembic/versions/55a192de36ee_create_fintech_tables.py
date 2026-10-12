"""create_fintech_tables

Revision ID: 55a192de36ee
Revises: 3dd84f6126eb
Create Date: 2026-10-12 15:24:10.171785

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '55a192de36ee'
down_revision: Union[str, Sequence[str], None] = '3dd84f6126eb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: Crear tablas users, portfolios, savings_plans y transactions."""
    # 1. Tabla users
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('username', sa.String(length=100), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)

    # 2. Tabla portfolios
    op.create_table(
        'portfolios',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('currency', sa.String(length=10), nullable=False),
        sa.Column('initial_balance', sa.Float(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )
    op.create_index(op.f('ix_portfolios_id'), 'portfolios', ['id'], unique=False)
    op.create_index(op.f('ix_portfolios_user_id'), 'portfolios', ['user_id'], unique=True)

    # 3. Tabla savings_plans
    op.create_table(
        'savings_plans',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('portfolio_id', sa.Integer(), nullable=False),
        sa.Column('monthly_deposit', sa.Float(), nullable=False),
        sa.Column('frequency', sa.String(length=20), nullable=False),
        sa.Column('allocation_equity_pct', sa.Float(), nullable=False),
        sa.Column('allocation_gold_pct', sa.Float(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(['portfolio_id'], ['portfolios.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('portfolio_id'),
    )
    op.create_index(op.f('ix_savings_plans_id'), 'savings_plans', ['id'], unique=False)
    op.create_index(op.f('ix_savings_plans_portfolio_id'), 'savings_plans', ['portfolio_id'], unique=True)

    # 4. Tabla transactions
    op.create_table(
        'transactions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('portfolio_id', sa.Integer(), nullable=False),
        sa.Column('ticker', sa.String(length=20), nullable=False),
        sa.Column('asset_class', sa.String(length=30), nullable=False),
        sa.Column('shares', sa.Float(), nullable=False),
        sa.Column('price_per_share', sa.Float(), nullable=False),
        sa.Column('amount_invested', sa.Float(), nullable=False),
        sa.Column('fee', sa.Float(), nullable=False),
        sa.Column('is_automated', sa.Boolean(), nullable=False),
        sa.Column(
            'timestamp',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['portfolio_id'], ['portfolios.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_transactions_id'), 'transactions', ['id'], unique=False)
    op.create_index(op.f('ix_transactions_portfolio_id'), 'transactions', ['portfolio_id'], unique=False)
    op.create_index(op.f('ix_transactions_ticker'), 'transactions', ['ticker'], unique=False)
    op.create_index(op.f('ix_transactions_timestamp'), 'transactions', ['timestamp'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_transactions_timestamp'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_ticker'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_portfolio_id'), table_name='transactions')
    op.drop_index(op.f('ix_transactions_id'), table_name='transactions')
    op.drop_table('transactions')

    op.drop_index(op.f('ix_savings_plans_portfolio_id'), table_name='savings_plans')
    op.drop_index(op.f('ix_savings_plans_id'), table_name='savings_plans')
    op.drop_table('savings_plans')

    op.drop_index(op.f('ix_portfolios_user_id'), table_name='portfolios')
    op.drop_index(op.f('ix_portfolios_id'), table_name='portfolios')
    op.drop_table('portfolios')

    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_index(op.f('ix_users_id'), table_name='users')
    op.drop_table('users')
