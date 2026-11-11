"""Rotas de autenticação: cadastro, login e dados do usuário logado."""
from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import PasswordChange, Token, UserCreate, UserLogin, UserOut, UserUpdate
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Autenticação"])


@router.post(
    "/register",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar usuário",
    responses={409: {"description": "E-mail já cadastrado"}},
)
def register(data: UserCreate, db: Session = Depends(get_db)):
    """Cria uma conta. A senha é salva com hash bcrypt."""
    return AuthService(db).register(data)


@router.post(
    "/login",
    response_model=Token,
    summary="Fazer login",
    responses={401: {"description": "Credenciais inválidas"}},
)
def login(data: UserLogin, db: Session = Depends(get_db)):
    """Valida e-mail e senha e devolve um token JWT para usar nas rotas protegidas."""
    token, user = AuthService(db).login(data)
    return Token(access_token=token, user=UserOut.model_validate(user))


@router.get(
    "/me",
    response_model=UserOut,
    summary="Usuário logado (rota protegida)",
    responses={401: {"description": "Token ausente ou inválido"}},
)
def me(current_user: User = Depends(get_current_user)):
    """Devolve os dados do dono do token."""
    return current_user


@router.put("/me", response_model=UserOut, summary="Editar o próprio perfil")
def update_me(data: UserUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Altera o nome do usuário logado."""
    return AuthService(db).update_profile(current_user, data)


@router.put(
    "/password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Trocar a senha",
    responses={400: {"description": "Senha atual incorreta"}},
)
def change_password(data: PasswordChange, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    AuthService(db).change_password(current_user, data)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
