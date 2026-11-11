"""Modelo ORM da tabela de tarefas (recurso principal do CRUD)."""
from datetime import date, datetime, timezone

from sqlalchemy import JSON, Boolean, Date, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    done: Mapped[bool] = mapped_column(Boolean, default=False)
    # Prioridade da tarefa: "baixa", "media" ou "alta"
    priority: Mapped[str] = mapped_column(String(10), default="media")
    # Data limite (opcional). Usada no app para mostrar tarefas atrasadas
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Categoria: "faculdade", "trabalho", "pessoal", "casa", "saude" ou "outros"
    category: Mapped[str] = mapped_column(String(20), default="outros")
    # Quando a tarefa foi concluída (preenchido pelo serviço). Usado nas estatísticas do app
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Checklist (subtarefas) salvo como JSON: [{"text": "Ler cap. 1", "done": true}, ...]
    checklist: Mapped[list] = mapped_column(JSON, default=list)
    # Repetição: "nunca", "diaria", "semanal" ou "mensal"
    recurrence: Mapped[str] = mapped_column(String(10), default="nunca")
    # Total de minutos de foco (Pomodoro) dedicados à tarefa
    focus_minutes: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)

    owner: Mapped["User"] = relationship(back_populates="tasks")  # noqa: F821
