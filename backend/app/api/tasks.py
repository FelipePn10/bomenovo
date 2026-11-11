"""Rotas do CRUD de tarefas. Todas são protegidas por token JWT."""
from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.task import DeletedCount, FocusSession, TaskCreate, TaskOut, TaskUpdate
from app.services.task_service import TaskService

router = APIRouter(
    prefix="/tasks",
    tags=["Tarefas"],
    responses={401: {"description": "Token ausente ou inválido"}},
)


def get_service(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> TaskService:
    """Monta o serviço já vinculado ao usuário logado."""
    return TaskService(db, user)


@router.get("", response_model=list[TaskOut], summary="Listar tarefas")
def list_tasks(service: TaskService = Depends(get_service)):
    """Lista todas as tarefas do usuário logado (mais recentes primeiro)."""
    return service.list()


# Precisa vir antes de "/{task_id}", senão o FastAPI tentaria ler "concluidas" como um id
@router.delete("/concluidas", response_model=DeletedCount, summary="Excluir todas as tarefas concluídas")
def delete_completed(service: TaskService = Depends(get_service)):
    return DeletedCount(deleted=service.delete_completed())


@router.get("/{task_id}", response_model=TaskOut, summary="Buscar tarefa por ID",
            responses={404: {"description": "Tarefa não encontrada"}})
def get_task(task_id: int, service: TaskService = Depends(get_service)):
    return service.get(task_id)


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED, summary="Criar tarefa")
def create_task(data: TaskCreate, service: TaskService = Depends(get_service)):
    return service.create(data)


@router.put("/{task_id}", response_model=TaskOut, summary="Atualizar tarefa",
            responses={400: {"description": "Nenhum campo enviado"}, 404: {"description": "Tarefa não encontrada"}})
def update_task(task_id: int, data: TaskUpdate, service: TaskService = Depends(get_service)):
    """Atualiza os campos enviados (os demais permanecem iguais)."""
    return service.update(task_id, data)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Excluir tarefa",
               responses={404: {"description": "Tarefa não encontrada"}})
def delete_task(task_id: int, service: TaskService = Depends(get_service)):
    service.delete(task_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{task_id}/foco", response_model=TaskOut, summary="Registrar minutos de foco",
             responses={404: {"description": "Tarefa não encontrada"}})
def add_focus(task_id: int, data: FocusSession, service: TaskService = Depends(get_service)):
    """Soma os minutos de uma sessão do Modo Foco (Pomodoro) ao total da tarefa."""
    return service.add_focus(task_id, data.minutes)
