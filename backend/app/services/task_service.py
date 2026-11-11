"""Regras de negócio das tarefas. Um usuário só enxerga e altera as próprias tarefas."""
from datetime import datetime, timezone

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
        for field in ("title", "priority", "category"):
            if field in changes and changes[field] is None:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"O campo '{field}' não pode ser nulo.")
        # Guarda a data de conclusão só quando o status realmente muda
        if "done" in changes and changes["done"] != task.done:
            changes["completed_at"] = datetime.now(timezone.utc) if changes["done"] else None
        return self.tasks.update(task, **changes)

    def delete(self, task_id: int) -> None:
        self.tasks.delete(self.get(task_id))

    def delete_completed(self) -> int:
        """Apaga todas as tarefas concluídas do usuário e devolve quantas foram apagadas."""
        return self.tasks.delete_completed(self.user.id)
