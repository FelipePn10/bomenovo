"""Esquemas Pydantic de tarefa (validação e serialização)."""
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# Valores aceitos para a prioridade (qualquer outro valor gera erro 422)
Priority = Literal["baixa", "media", "alta"]


class TaskCreate(BaseModel):
    """Dados para criar uma tarefa."""
    title: str = Field(min_length=1, max_length=120, examples=["Estudar FastAPI"])
    description: str | None = Field(default=None, examples=["Ler a documentação oficial"])
    done: bool = False
    priority: Priority = "media"
    due_date: date | None = Field(default=None, examples=["2026-12-01"])


class TaskUpdate(BaseModel):
    """Dados para atualizar uma tarefa. Todos os campos são opcionais (atualização parcial)."""
    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    done: bool | None = None
    priority: Priority | None = None
    # Enviar "due_date": null remove a data limite
    due_date: date | None = None


class TaskOut(BaseModel):
    """Tarefa devolvida pela API."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    done: bool
    priority: str
    due_date: date | None
    created_at: datetime
    owner_id: int
