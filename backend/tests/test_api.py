"""Testes automatizados da API (rodar com: pytest -v)."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app

# Banco SQLite em memória, isolado para os testes
engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def override_get_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def reset_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


client = TestClient(app)
USER = {"name": "Maria", "email": "maria@email.com", "password": "senha123"}


def auth_headers(user=USER) -> dict:
    client.post("/auth/register", json=user)
    token = client.post("/auth/login", json={"email": user["email"], "password": user["password"]}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_register_hashes_password():
    r = client.post("/auth/register", json=USER)
    assert r.status_code == 201
    assert "password" not in r.json() and "hashed_password" not in r.json()

    from app.models.user import User
    db = TestingSession()
    stored = db.query(User).first().hashed_password
    db.close()
    assert stored != USER["password"] and stored.startswith("$2")  # hash bcrypt


def test_register_duplicate_email():
    client.post("/auth/register", json=USER)
    r = client.post("/auth/register", json=USER)
    assert r.status_code == 409


def test_login_wrong_password():
    client.post("/auth/register", json=USER)
    r = client.post("/auth/login", json={"email": USER["email"], "password": "errada"})
    assert r.status_code == 401
    assert r.json()["detail"] == "E-mail ou senha inválidos."


def test_protected_route_without_token():
    r = client.get("/tasks")
    assert r.status_code == 401
    assert "Token de acesso não informado" in r.json()["detail"]


def test_protected_route_invalid_token():
    r = client.get("/tasks", headers={"Authorization": "Bearer token-falso"})
    assert r.status_code == 401
    assert "inválido" in r.json()["detail"]


def test_me():
    r = client.get("/auth/me", headers=auth_headers())
    assert r.status_code == 200
    assert r.json()["email"] == USER["email"]


def test_crud_tasks():
    h = auth_headers()

    # Create
    r = client.post("/tasks", json={"title": "Estudar", "description": "FastAPI"}, headers=h)
    assert r.status_code == 201
    task_id = r.json()["id"]
    assert r.json()["done"] is False

    # Read (lista e por ID)
    assert len(client.get("/tasks", headers=h).json()) == 1
    assert client.get(f"/tasks/{task_id}", headers=h).json()["title"] == "Estudar"

    # Update parcial
    r = client.put(f"/tasks/{task_id}", json={"done": True}, headers=h)
    assert r.status_code == 200
    assert r.json()["done"] is True and r.json()["title"] == "Estudar"

    # Delete
    assert client.delete(f"/tasks/{task_id}", headers=h).status_code == 204
    assert client.get(f"/tasks/{task_id}", headers=h).status_code == 404


def test_validation_error_message():
    r = client.post("/tasks", json={"title": ""}, headers=auth_headers())
    assert r.status_code == 422
    assert r.json()["detail"] == "Dados inválidos na requisição."
    assert r.json()["errors"][0]["campo"] == "title"


def test_update_without_fields():
    h = auth_headers()
    task_id = client.post("/tasks", json={"title": "X"}, headers=h).json()["id"]
    assert client.put(f"/tasks/{task_id}", json={}, headers=h).status_code == 400


def test_user_cannot_access_other_users_task():
    h1 = auth_headers()
    task_id = client.post("/tasks", json={"title": "Privada"}, headers=h1).json()["id"]

    h2 = auth_headers({"name": "João", "email": "joao@email.com", "password": "senha123"})
    assert client.get(f"/tasks/{task_id}", headers=h2).status_code == 404
    assert client.delete(f"/tasks/{task_id}", headers=h2).status_code == 404
    assert client.get("/tasks", headers=h2).json() == []


def test_priority_and_due_date():
    h = auth_headers()

    # Sem informar, a prioridade padrão é "media" e não há data limite
    r = client.post("/tasks", json={"title": "Padrão"}, headers=h)
    assert r.json()["priority"] == "media" and r.json()["due_date"] is None

    r = client.post("/tasks", json={"title": "Prova", "priority": "alta", "due_date": "2026-12-01"}, headers=h)
    assert r.status_code == 201
    task_id = r.json()["id"]
    assert r.json()["priority"] == "alta" and r.json()["due_date"] == "2026-12-01"

    # Enviar due_date null remove a data
    r = client.put(f"/tasks/{task_id}", json={"due_date": None}, headers=h)
    assert r.json()["due_date"] is None

    # Prioridade inválida ou nula é recusada
    assert client.post("/tasks", json={"title": "X", "priority": "urgente"}, headers=h).status_code == 422
    assert client.put(f"/tasks/{task_id}", json={"priority": None}, headers=h).status_code == 400


def test_category_and_completed_at():
    h = auth_headers()
    r = client.post("/tasks", json={"title": "TCC", "category": "faculdade"}, headers=h)
    assert r.json()["category"] == "faculdade" and r.json()["completed_at"] is None
    task_id = r.json()["id"]

    # Concluir preenche completed_at; reabrir limpa
    assert client.put(f"/tasks/{task_id}", json={"done": True}, headers=h).json()["completed_at"] is not None
    assert client.put(f"/tasks/{task_id}", json={"done": False}, headers=h).json()["completed_at"] is None

    assert client.post("/tasks", json={"title": "X", "category": "festa"}, headers=h).status_code == 422


def test_delete_completed():
    h = auth_headers()
    client.post("/tasks", json={"title": "Feita 1", "done": True}, headers=h)
    client.post("/tasks", json={"title": "Feita 2", "done": True}, headers=h)
    client.post("/tasks", json={"title": "Pendente"}, headers=h)

    r = client.delete("/tasks/concluidas", headers=h)
    assert r.status_code == 200 and r.json()["deleted"] == 2
    assert [t["title"] for t in client.get("/tasks", headers=h).json()] == ["Pendente"]


def test_update_profile_and_password():
    h = auth_headers()
    r = client.put("/auth/me", json={"name": "Maria Souza"}, headers=h)
    assert r.status_code == 200 and r.json()["name"] == "Maria Souza"

    # Senha atual errada
    r = client.put("/auth/password", json={"current_password": "errada", "new_password": "nova123"}, headers=h)
    assert r.status_code == 400

    r = client.put("/auth/password", json={"current_password": "senha123", "new_password": "nova123"}, headers=h)
    assert r.status_code == 204
    assert client.post("/auth/login", json={"email": USER["email"], "password": "nova123"}).status_code == 200
