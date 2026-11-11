"""Ponto de entrada da aplicação FastAPI.

Rodar:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
Docs:   http://localhost:8000/docs
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import models  # noqa: F401  (registra as tabelas no metadata)
from app.api import auth, tasks
from app.core.database import Base, engine, add_missing_columns


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Cria as tabelas automaticamente na primeira execução
    Base.metadata.create_all(bind=engine)
    # Bancos criados na versão anterior ganham as colunas novas (priority, due_date)
    add_missing_columns()
    yield


app = FastAPI(
    title="API de Tarefas",
    description="API RESTful com CRUD de tarefas e autenticação JWT, consumida por um app Flutter.",
    version="1.0.0",
    lifespan=lifespan,
)

# Libera o acesso do app Flutter (web/emulador). Em produção, restrinja as origens.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError):
    """Transforma erros de validação do Pydantic em uma mensagem clara."""
    errors = [
        {"campo": ".".join(str(p) for p in err["loc"] if p != "body"), "erro": err["msg"]}
        for err in exc.errors()
    ]
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content={"detail": "Dados inválidos na requisição.", "errors": errors},
    )


app.include_router(auth.router)
app.include_router(tasks.router)


@app.get("/", tags=["Status"], summary="Verificar se a API está no ar")
def root():
    return {"status": "ok", "docs": "/docs"}
