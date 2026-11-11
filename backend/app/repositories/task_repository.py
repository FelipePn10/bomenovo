"""Acesso aos dados de tarefas. Toda consulta é filtrada pelo dono da tarefa."""
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.task import Task


class TaskRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_by_owner(self, owner_id: int) -> list[Task]:
        stmt = select(Task).where(Task.owner_id == owner_id).order_by(Task.id.desc())
        return list(self.db.scalars(stmt))

    def get_by_id(self, task_id: int, owner_id: int) -> Task | None:
        stmt = select(Task).where(Task.id == task_id, Task.owner_id == owner_id)
        return self.db.scalar(stmt)

    def create(self, owner_id: int, **data) -> Task:
        task = Task(owner_id=owner_id, **data)
        self.db.add(task)
        self.db.commit()
        self.db.refresh(task)
        return task

    def update(self, task: Task, **data) -> Task:
        for field, value in data.items():
            setattr(task, field, value)
        self.db.commit()
        self.db.refresh(task)
        return task

    def delete(self, task: Task) -> None:
        self.db.delete(task)
        self.db.commit()

    def delete_completed(self, owner_id: int) -> int:
        stmt = delete(Task).where(Task.owner_id == owner_id, Task.done.is_(True))
        result = self.db.execute(stmt)
        self.db.commit()
        return result.rowcount
