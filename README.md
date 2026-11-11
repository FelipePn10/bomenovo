# Gerenciador de Tarefas — FastAPI + Flutter

Trabalho prático: uma **API RESTful em FastAPI** com CRUD de **tarefas** e autenticação **JWT**, consumida por um **app Flutter** e por uma **interface web em Python (Flask)**.

- Recurso do CRUD: **tarefas** (cada usuário vê e altera apenas as próprias), com prioridade e data limite
- Banco: **SQLite** (arquivo `backend/tarefas.db`, criado automaticamente) ou **PostgreSQL** quando hospedado
- Senhas salvas com **bcrypt**; rotas de tarefas protegidas por **Bearer token (JWT)**
- Documentação automática: **Swagger** em http://localhost:8000/docs
- API hospedada (Render): https://api-tarefas-4pv6.onrender.com (Swagger em [/docs](https://api-tarefas-4pv6.onrender.com/docs))
- APK para Android: página [Releases](https://github.com/FelipePn10/bomenovo/releases/latest) do repositório

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
├── mobile/                    # App Flutter
│   └── lib/
│       ├── main.dart          # Inicia o app (token, tema, idioma pt-BR)
│       ├── config.dart        # URL padrão da API
│       ├── theme.dart         # Cores, estilo dos componentes e modo claro/escuro
│       ├── models/            # Task (com prioridade e data limite) e User
│       ├── services/api_service.dart   # Chamadas HTTP, token e endereço do servidor
│       ├── utils/dates.dart   # Formatação de datas ("Hoje", "Atrasada há 2 dias"...)
│       ├── widgets/           # Componentes reutilizados (card da tarefa, progresso...)
│       └── screens/           # login, cadastro, tarefas, formulário e perfil
├── render.yaml                # Deploy gratuito da API no Render
└── .github/workflows/android.yml   # Gera o APK automaticamente no GitHub
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
| 400    | `PUT` sem nenhum campo (ou título/prioridade nulos) | `{"detail": "Envie ao menos um campo para atualizar."}` |
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

# Create (priority: "baixa" | "media" | "alta"; due_date é opcional)
curl -X POST http://localhost:8000/tasks \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title": "Estudar FastAPI", "description": "Ler a documentação", "priority": "alta", "due_date": "2026-12-01"}'

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

### Campos da tarefa

| Campo         | Tipo                         | Obrigatório | Observação                          |
|---------------|------------------------------|:-----------:|-------------------------------------|
| `title`       | texto (1 a 120)              | sim         |                                     |
| `description` | texto                        | não         |                                     |
| `done`        | booleano                     | não         | padrão `false`                      |
| `priority`    | `baixa`, `media` ou `alta`   | não         | padrão `media`                      |
| `due_date`    | data `AAAA-MM-DD`            | não         | enviar `null` no `PUT` remove a data |

Quem já tinha um `tarefas.db` da versão anterior não precisa apagar: ao iniciar, a API adiciona as colunas novas (`priority` e `due_date`) sozinha.

## App Flutter

### Funcionalidades

- Cadastro (com confirmação de senha) e login; depois do cadastro o login é feito automaticamente
- Sessão salva no aparelho: abrindo o app de novo, vai direto para as tarefas. Se o token expirar, volta para o login com o aviso da API
- Lista com card de progresso (% concluído, pendentes, para hoje e atrasadas)
- Busca por título/descrição, filtros (todas, pendentes, atrasadas, concluídas) e ordenação (mais recentes, data limite, prioridade)
- Criar e editar tarefa com prioridade, data limite (calendário em português + atalhos "Hoje", "Amanhã", "Em 1 semana") e status
- Gestos nos cards: arrastar para a direita conclui/reabre, para a esquerda exclui (com confirmação)
- Perfil com dados da conta, estatísticas, tema claro/escuro/automático e troca do servidor da API
- Layout responsivo: no celular a lista tem 1 coluna; em tablet, celular deitado ou navegador vira 2 colunas, e os formulários ficam centralizados com largura limitada

### Rodando em modo de desenvolvimento

Com o backend rodando:

```bash
cd mobile
flutter pub get
flutter run                 # escolha o dispositivo (emulador Android, Chrome, etc.)
flutter test                # testes do app
```

### Endereço da API

O app precisa saber onde a API está. A ordem é:

1. O endereço salvo no próprio app (botão **Servidor** na tela de login, ou em **Perfil > Servidor da API**). Tem um botão **Testar** para conferir se a API responde.
2. O valor passado na compilação: `flutter run --dart-define=API_URL=http://192.168.0.10:8000`
3. O padrão: `http://10.0.2.2:8000` no emulador Android (é o localhost do computador) e `http://localhost:8000` na web/desktop.

No **celular físico** com a API rodando no computador, os dois precisam estar na mesma rede Wi-Fi e o endereço é o IP do computador (descubra com `ip a` no Linux ou `ipconfig` no Windows), por exemplo `http://192.168.0.10:8000`. Lembre de iniciar o uvicorn com `--host 0.0.0.0`.

## Hospedando a API de graça (Render)

Dá para fazer de dois jeitos. O manual é o mais garantido.

### Opção 1: manual (Postgres + Web Service)

Crie uma conta em https://render.com (dá para entrar com o GitHub) e siga os passos abaixo.

**1. Banco de dados:** **New > Postgres**

- Name: `tarefas-db`
- Plan: **Free**
- Depois de criado, copie o **Internal Database URL**, que fica na página do banco, em *Connections*.

**2. API:** **New > Web Service**, escolha este repositório e preencha:

| Campo          | Valor                                                   |
|----------------|---------------------------------------------------------|
| Language       | Python 3                                                |
| Branch         | `main`                                                  |
| Root Directory | `backend`                                               |
| Build Command  | `pip install -r requirements.txt`                       |
| Start Command  | `uvicorn app.main:app --host 0.0.0.0 --port $PORT`      |
| Instance Type  | **Free**                                                |

Em **Environment Variables**, adicione:

| Variável                      | Valor                                                              |
|-------------------------------|--------------------------------------------------------------------|
| `DATABASE_URL`                | a Internal Database URL copiada no passo 1                         |
| `SECRET_KEY`                  | um texto aleatório (`python -c "import secrets; print(secrets.token_hex(32))"`) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` (token vale 24h)                                            |

**3.** Clique em **Deploy Web Service**. Quando terminar, a API fica em algo como `https://api-tarefas.onrender.com` (o Swagger fica em `/docs`).

**4.** Use esse endereço no app (botão **Servidor**) ou coloque como padrão do APK (veja a seção sobre o APK).

### Opção 2: Blueprint (automático)

O arquivo `render.yaml` cria a API e o banco de uma vez. No painel do Render, vá em **Blueprints** (menu lateral) > **New Blueprint Instance** e selecione este repositório. O repositório precisa estar no GitHub com o `render.yaml` na raiz.

Limitações do plano gratuito: a API "dorme" depois de 15 minutos sem uso e a primeira requisição pode levar uns 50 segundos (o app espera até 60s e avisa se demorar). O PostgreSQL gratuito do Render expira depois de 30 dias; se precisar de mais tempo, dá para criar um banco grátis no [Neon](https://neon.tech) e colocar a URL dele na variável `DATABASE_URL` do serviço.

## Gerando o APK (Android)

### Pelo GitHub (não precisa instalar nada)

O workflow `.github/workflows/android.yml` compila o APK no GitHub Actions, rodando antes o `flutter analyze` e os testes.

- **A cada push na `main`** que altere o app: o APK aparece na aba **Actions**, dentro da execução, em **Artifacts** (vem compactado em .zip).
- **Para gerar uma versão para download**, crie uma tag:

  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```

  O APK (`minhas-tarefas.apk`) fica na página **Releases** do repositório.

O APK gerado pelo GitHub já vem apontando para a API do Render (`https://api-tarefas-4pv6.onrender.com`). Para usar outro endereço, crie a variável `API_URL` em **Settings > Secrets and variables > Actions > Variables**; o endereço também pode ser trocado dentro do app.

### Na própria máquina

Precisa do Android SDK (vem com o Android Studio):

```bash
cd mobile
flutter build apk --release --dart-define=API_URL=https://api-tarefas.onrender.com
# APK gerado em: mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Instalando no celular

Baixe o `.apk` no celular e abra. O Android vai pedir para permitir a instalação de "fontes desconhecidas" para o navegador/gerenciador de arquivos; é normal, porque o app não vem da Play Store. O APK é assinado com a chave de debug, o que basta para instalar, mas não para publicar na loja.

## Interface web em Python (Flask)

A segunda interface exigida pelo trabalho fica em `web/` e consome a mesma API. Com o backend rodando:

```bash
cd web
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py                # http://localhost:5000
```

Cadastro, login, criar, listar, editar, concluir e excluir tarefas; a lista se atualiza sozinha a cada 5 s, então alterações feitas no Flutter aparecem na web (e vice-versa). Detalhes e exemplos de uso em [`web/README.md`](web/README.md).
