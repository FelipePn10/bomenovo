"""Conexão com o banco de dados (SQLAlchemy) e sessão por requisição."""
from collections.abc import Generator

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings

# Serviços de hospedagem (Render, Neon...) entregam "postgres://"; o SQLAlchemy usa o driver psycopg
database_url = settings.DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1)
database_url = database_url.replace("postgresql://", "postgresql+psycopg://", 1)

# check_same_thread=False é necessário apenas para SQLite com FastAPI
connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}

engine = create_engine(database_url, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Classe base de todos os modelos ORM."""


def get_db() -> Generator[Session, None, None]:
    """Dependência do FastAPI: abre uma sessão e garante que ela seja fechada."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def add_missing_columns() -> None:
    """Migração simples: adiciona na tabela tasks as colunas que surgiram depois.

    O create_all só cria tabelas novas, não altera as existentes. Assim quem já
    tinha um tarefas.db não precisa apagar o arquivo.
    """
    existing = {c["name"] for c in inspect(engine).get_columns("tasks")}
    new_columns = {
        "priority": "VARCHAR(10) NOT NULL DEFAULT 'media'",
        "due_date": "DATE",
    }
    with engine.begin() as conn:
        for name, ddl in new_columns.items():
            if name not in existing:
                conn.execute(text(f"ALTER TABLE tasks ADD COLUMN {name} {ddl}"))
