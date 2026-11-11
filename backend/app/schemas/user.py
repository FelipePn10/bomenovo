"""Esquemas Pydantic de usuário e autenticação (entrada e saída da API)."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    """Dados para cadastro."""
    name: str = Field(min_length=2, max_length=100, examples=["Maria Silva"])
    email: EmailStr = Field(examples=["maria@email.com"])
    password: str = Field(min_length=6, max_length=72, examples=["senha123"])


class UserLogin(BaseModel):
    """Dados para login."""
    email: EmailStr = Field(examples=["maria@email.com"])
    password: str = Field(examples=["senha123"])


class UserUpdate(BaseModel):
    """Dados que o usuário pode alterar no próprio perfil."""
    name: str = Field(min_length=2, max_length=100)


class PasswordChange(BaseModel):
    """Troca de senha: exige a senha atual por segurança."""
    current_password: str
    new_password: str = Field(min_length=6, max_length=72)


class UserOut(BaseModel):
    """Dados do usuário devolvidos pela API (sem a senha!)."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: EmailStr
    created_at: datetime


class Token(BaseModel):
    """Resposta do login."""
    access_token: str
    token_type: str = "bearer"
    user: UserOut
