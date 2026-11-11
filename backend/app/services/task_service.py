"""Regras de negócio das tarefas. Um usuário só enxerga e altera as próprias tarefas."""
import calendar
from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.task import Task
from app.models.user import User
from app.repositories.task_repository import TaskRepository
from app.schemas.task import TaskCreate, TaskUpdate


class TaskService:
    def __init__(self, db: Session, user: User):
        self.tasks = TaskRepository(db)
        self.user = user

    def list(self) -> list[Task]:
        return self.tasks.list_by_owner(self.user.id)

    def get(self, task_id: int) -> Task:
        task = self.tasks.get_by_id(task_id, self.user.id)
        if not task:
            raise HTTPException(status.HTTP_404_NOT_FOUND, detail=f"Tarefa {task_id} não encontrada.")
        return task

    def create(self, data: TaskCreate) -> Task:
        # model_dump converte tudo (inclusive os itens do checklist) em dicionários simples
        task = data.model_dump()
        if task["done"]:
            task["completed_at"] = datetime.now(timezone.utc)
        return self.tasks.create(self.user.id, **task)

    def update(self, task_id: int, data: TaskUpdate) -> Task:
        task = self.get(task_id)
        # exclude_unset: só altera os campos que vieram na requisição
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Envie ao menos um campo para atualizar.")
        # Título e prioridade são obrigatórios: não podem virar null
        for field in ("title", "priority", "category", "checklist", "recurrence"):
            if field in changes and changes[field] is None:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"O campo '{field}' não pode ser nulo.")
        # Guarda a data de conclusão só quando o status realmente muda
        just_completed = changes.get("done") is True and not task.done
        if "done" in changes and changes["done"] != task.done:
            changes["completed_at"] = datetime.now(timezone.utc) if changes["done"] else None
        task = self.tasks.update(task, **changes)
        # Tarefa recorrente concluída: já cria a próxima ocorrência
        if just_completed and task.recurrence != "nunca":
            self._create_next(task)
        return task

    def _create_next(self, task: Task) -> Task:
        """Cria a próxima repetição: mesma tarefa, pendente, com o checklist desmarcado e a data avançada."""
        base = task.due_date or date.today()
        return self.tasks.create(
            self.user.id,
            title=task.title,
            description=task.description,
            priority=task.priority,
            category=task.category,
            recurrence=task.recurrence,
            due_date=next_date(base, task.recurrence),
            checklist=[{"text": item["text"], "done": False} for item in task.checklist or []],
        )

    def add_focus(self, task_id: int, minutes: int) -> Task:
        """Soma os minutos de uma sessão de foco ao total da tarefa."""
        task = self.get(task_id)
        return self.tasks.update(task, focus_minutes=(task.focus_minutes or 0) + minutes)

    def delete(self, task_id: int) -> None:
        self.tasks.delete(self.get(task_id))

    def delete_completed(self) -> int:
        """Apaga todas as tarefas concluídas do usuário e devolve quantas foram apagadas."""
        return self.tasks.delete_completed(self.user.id)


def next_date(base: date, recurrence: str) -> date:
    """Calcula a próxima data de uma tarefa recorrente."""
    if recurrence == "diaria":
        return base + timedelta(days=1)
    if recurrence == "semanal":
        return base + timedelta(weeks=1)
    # Mensal: mesmo dia no mês seguinte. Se o dia não existir (ex.: 31/01 -> fevereiro), usa o último dia do mês
    year, month = (base.year + 1, 1) if base.month == 12 else (base.year, base.month + 1)
    day = min(base.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)
