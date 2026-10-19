# Gerenciador de Tarefas — FastAPI + Flutter

Trabalho prático: uma **API RESTful em FastAPI** com CRUD de **tarefas** e autenticação **JWT**, consumida por um **app Flutter** e por uma **interface web em Python (Flask)**.

- Recurso do CRUD: **tarefas** (cada usuário vê e altera apenas as próprias)
- Banco: **SQLite** (arquivo `backend/tarefas.db`, criado automaticamente)
- Senhas salvas com **bcrypt**; rotas de tarefas protegidas por **Bearer token (JWT)**
- Documentação automática: **Swagger** em http://localhost:8000/docs

## Estrutura

```
.
├── backend/
│   ├── app/
│   │   ├── main.py            # Ponto de entrada (FastAPI, CORS, tratamento de erros)
│   │   ├── core/              # config.py, database.py, security.py (bcrypt + JWT)
│   │   ├── models/            # Modelos ORM (SQLAlchemy): User, Task
│   │   ├── schemas/           # Esquemas Pydantic (validação/serialização)
│   │   ├── repositories/      # Acesso ao banco
│   │   ├── services/          # Regras de negócio
│   │   └── api/               # Rotas: auth.py, tasks.py, deps.py (usuário logado)
│   ├── tests/test_api.py      # Testes automatizados (pytest)
│   ├── requests.http          # Exemplos de requisições
│   └── requirements.txt
├── web/                       # Interface web em Flask (consome a mesma API) — veja web/README.md
└── mobile/                    # App Flutter
    └── lib/
        ├── main.dart
        ├── config.dart        # URL da API
        ├── models/task.dart
        ├── services/api_service.dart   # Chamadas HTTP + token
        └── screens/           # login, cadastro, lista e formulário de tarefas
```

## Como rodar o backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger: http://localhost:8000/docs — faça login em `POST /auth/login`, copie o `access_token`, clique em **Authorize** e cole o token para testar as rotas protegidas.
- Testes: `pytest -v` (dentro da pasta `backend`, com o venv ativo).
- Opcional: copie `.env.example` para `.env` para trocar a `SECRET_KEY`, expiração do token ou o banco.

## Endpoints

| Método | Rota             | Protegida | Descrição                          | Sucesso |
|--------|------------------|:---------:|------------------------------------|---------|
| POST   | `/auth/register` |           | Cadastrar usuário                  | 201     |
| POST   | `/auth/login`    |           | Login, devolve o token JWT         | 200     |
| GET    | `/auth/me`       | ✅        | Dados do usuário logado            | 200     |
| GET    | `/tasks`         | ✅        | Listar tarefas do usuário          | 200     |
| GET    | `/tasks/{id}`    | ✅        | Buscar tarefa por ID               | 200     |
| POST   | `/tasks`         | ✅        | Criar tarefa                       | 201     |
| PUT    | `/tasks/{id}`    | ✅        | Atualizar tarefa (campos enviados) | 200     |
| DELETE | `/tasks/{id}`    | ✅        | Excluir tarefa                     | 204     |

### Erros

| Código | Quando                                       | Exemplo de resposta |
|--------|----------------------------------------------|---------------------|
| 400    | `PUT` sem nenhum campo                       | `{"detail": "Envie ao menos um campo para atualizar."}` |
| 401    | Sem token                                    | `{"detail": "Token de acesso não informado. Envie o header 'Authorization: Bearer <token>'."}` |
| 401    | Token inválido/expirado                      | `{"detail": "Token inválido ou expirado. Faça login novamente."}` |
| 401    | Login com e-mail/senha errados               | `{"detail": "E-mail ou senha inválidos."}` |
| 404    | Tarefa não existe (ou é de outro usuário)    | `{"detail": "Tarefa 99 não encontrada."}` |
| 409    | Cadastro com e-mail repetido                 | `{"detail": "Este e-mail já está cadastrado."}` |
| 422    | Dados inválidos (ex.: título vazio)          | `{"detail": "Dados inválidos na requisição.", "errors": [{"campo": "title", "erro": "..."}]}` |

## Exemplos de requisições (curl)

```bash
# Cadastro
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Maria Silva", "email": "maria@email.com", "password": "senha123"}'
# -> 201 {"id":1,"name":"Maria Silva","email":"maria@email.com","created_at":"..."}

# Login
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "maria@email.com", "password": "senha123"}'
# -> 200 {"access_token":"eyJhbGciOi...","token_type":"bearer","user":{...}}

TOKEN="cole_o_access_token_aqui"

# Rota protegida SEM token -> 401
curl http://localhost:8000/tasks

# Rota protegida COM token
curl http://localhost:8000/auth/me -H "Authorization: Bearer $TOKEN"

# Create
curl -X POST http://localhost:8000/tasks \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title": "Estudar FastAPI", "description": "Ler a documentação"}'

# Read (todas / por ID)
curl http://localhost:8000/tasks   -H "Authorization: Bearer $TOKEN"
curl http://localhost:8000/tasks/1 -H "Authorization: Bearer $TOKEN"

# Update
curl -X PUT http://localhost:8000/tasks/1 \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"done": true}'

# Delete -> 204
curl -X DELETE http://localhost:8000/tasks/1 -H "Authorization: Bearer $TOKEN"
```

Os mesmos exemplos estão em `backend/requests.http`.

## Como rodar o app Flutter

Com o backend rodando:

```bash
cd mobile
flutter pub get
flutter run                 # escolha o dispositivo (emulador Android, Chrome, etc.)
```

A URL da API é definida em `lib/config.dart`:

- **Emulador Android:** usa `http://10.0.2.2:8000` automaticamente (é o localhost do computador).
- **Web/Desktop:** usa `http://localhost:8000`.
- **Celular físico** (mesma rede Wi-Fi): informe o IP do computador:
  `flutter run --dart-define=API_URL=http://192.168.0.10:8000`

Funcionalidades do app: cadastro, login (token salvo no aparelho com `shared_preferences`), listar tarefas, criar, editar, marcar como concluída, excluir e sair. Se o token expirar, o app volta para o login mostrando a mensagem da API.

## Interface web em Python (Flask)

A segunda interface exigida pelo trabalho fica em `web/` e consome a mesma API. Com o backend rodando:

```bash
cd web
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py                # http://localhost:5000
```

Cadastro, login, criar, listar, editar, concluir e excluir tarefas; a lista se atualiza sozinha a cada 5 s, então alterações feitas no Flutter aparecem na web (e vice-versa). Detalhes e exemplos de uso em [`web/README.md`](web/README.md).
