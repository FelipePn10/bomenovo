"""Regras de negócio das tarefas. Um usuário só enxerga e altera as próprias tarefas."""
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
        return self.tasks.create(self.user.id, **data.model_dump())

    def update(self, task_id: int, data: TaskUpdate) -> Task:
        task = self.get(task_id)
        # exclude_unset: só altera os campos que vieram na requisição
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Envie ao menos um campo para atualizar.")
        # Título e prioridade são obrigatórios: não podem virar null
        for field in ("title", "priority"):
            if field in changes and changes[field] is None:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"O campo '{field}' não pode ser nulo.")
        return self.tasks.update(task, **changes)

    def delete(self, task_id: int) -> None:
        self.tasks.delete(self.get(task_id))
