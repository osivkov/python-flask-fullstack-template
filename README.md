# Flask Full-stack Template

A single-host Docker Compose template with separate Flask API and React
applications. Both live in one repository, with independent dependencies,
configuration, tests and Dockerfiles. The example counter stores data in PostgreSQL.

## Stack

| Component          | Technologies                                           |
| ------------------ | ------------------------------------------------------ |
| Backend            | Python 3.13, Flask, Gunicorn                           |
| Database           | PostgreSQL 17, SQLAlchemy, Flask-SQLAlchemy, psycopg   |
| Migrations         | Alembic, packaged with the backend release             |
| Frontend           | React, TypeScript, Vite                                |
| Public entry point | Nginx, serving the built frontend and proxying the API |
| Dependencies       | uv + uv.lock; npm + package-lock.json                  |
| Tests              | pytest; Vitest + React Testing Library                 |
| Automation         | Make, Docker Compose, GitHub Actions                   |

This is not a Kubernetes cluster or a highly available deployment. TLS,
authentication, off-server backups and monitoring are not included.

## Structure

```text
app/
├── backend/
│   ├── src/webapp/       # Flask API, models and database configuration
│   ├── tests/
│   ├── alembic/
│   ├── pyproject.toml
│   ├── uv.lock
│   ├── .env.example
│   └── Dockerfile
└── frontend/
    ├── src/             # React UI, API client and tests
    ├── public/          # assets copied without transformation
    ├── package.json
    ├── package-lock.json
    ├── .env.example
    └── Dockerfile

infra/
├── compose/             # production defaults + development override
├── nginx/               # routing and response headers
├── postgres/            # first-start database/role creation
└── .env.example         # deployment settings

docs/                    # architecture, deployment and operations
scripts/                 # init, smoke, backup/restore and check tooling
Makefile
README.md
```

Backend and frontend are siblings: neither contains the other's source code.
The Flask package name `webapp` is a Python import name, not a frontend directory.
There are no server-rendered pages or frontend assets inside the backend.

## First run

Install Docker Engine, Docker Compose **2.24.4+**, GNU Make, OpenSSL and curl.
Python and Node.js are not required on the host. Run commands from the repository root.

```bash
make init
make dev
make smoke
```

Open [localhost:8080](http://localhost:8080).

Initialization creates ignored local env files and random DB password files
without overwriting existing configuration. On an empty volume, PostgreSQL
creates a non-superuser application role and database. A one-shot migration job
runs `alembic upgrade head`; the backend starts after it succeeds, followed by
the frontend. Existing database volumes are retained.

## Development versus production

|                   | Development                                 | Production                                   |
| ----------------- | ------------------------------------------- | -------------------------------------------- |
| Command           | `make dev`                                  | `make up` locally; `make deploy` on a server |
| Backend           | Flask debug server, mounted source          | Gunicorn, code copied into image             |
| Frontend          | Vite dev server, mounted source, hot reload | Built static files served by Nginx           |
| Node.js           | Running in the frontend container           | Build-time only                              |
| Test dependencies | Included                                    | Not included                                 |
| API access        | Vite proxies `/api/` to Flask               | Nginx proxies `/api/` to Flask               |

Use development while editing. Switch to production to verify release images
and for every server deployment; do not expose the Flask debugger or Vite dev
server publicly. Both modes publish only `127.0.0.1:8080` by default.

```bash
make up         # build production images and switch the local stack
make dev        # switch back to development
make status
make logs
make restart    # restart without changing mode
make down       # stop; keep database data
```

These commands switch one stack and keep its database. They do not create
independent dev and production databases. Never use `down -v` on data you need.

Both application Dockerfiles expose `development` and `production` targets.
Helper build stages share dependencies or build the frontend; there is no
separate test target. The migration job uses the production backend image even
in dev mode. `make dev` builds it first to support a fresh checkout.

## Configuration

| File                    | Responsibility                                                      |
| ----------------------- | ------------------------------------------------------------------- |
| `infra/.env`            | Project/volume names, image repositories, release tag, HTTP binding |
| `infra/.env.production` | Deployment settings for a server; example supplied                  |
| `app/backend/.env`      | Database connection and future server-side settings                 |
| `app/frontend/.env`     | Public frontend configuration                                       |
| `secrets/*.txt`         | Generated database passwords, mounted at runtime                    |

Make explicitly loads the deployment, backend and frontend env files for Compose.
Compose passes only backend settings to Flask and only frontend settings to the
Vite dev server. PostgreSQL initialization reads DB_NAME/DB_USER from the backend
file so these values are not duplicated in infra configuration.

`VITE_API_BASE=/api` keeps requests on the same origin. **Frontend env values are
public**, embedded during production builds. Never put passwords or tokens there.
Changing production frontend settings requires rebuilding its image; changing
container env alone does not change JavaScript already built. Dev env changes
require `make dev` again.

Each checkout has one backend and one frontend env file. Use separate checkouts
for independently configured environments. Keep project and volume names stable.
Changing env files does not rotate PostgreSQL passwords or rename an existing DB.
Example env files are public; real env files, secrets and backups are ignored.

Compose secrets here are local files, not an encrypted secret manager.
Memory and log limits are explicit in Compose; tune them for your workload.

## Checks and tests

```bash
make format       # format Python, JS/TS, CSS, JSON, shell, YAML and Markdown
make format-check # check formatting without writing
make lint         # formatting, Python/shell/Docker/CI linters + TypeScript check
make check        # resolve and validate both Compose modes
make test         # backend and frontend tests
make smoke        # check frontend HTTP and backend health through the public port
```

Checks run in Docker. Frontend type checking and tests use its own development
image; Python tests use the backend development image. No Node dependencies are
added to Python and no Python dependencies are added to the frontend.

Backend tests use disposable SQLite databases. CI checks formatting and types,
validates both Compose modes, runs the application tests, starts the production
stack and checks the public frontend and backend health endpoints. Frontend tests
cover its API client, loading failures and counter interaction. This is not a
browser end-to-end test suite.

## Working on the template

- Put API handlers in `app/backend/src/webapp/views/` and ORM models in `models/`.
- Put UI code and browser API calls in `app/frontend/src/`.
- Add Python libraries through `pyproject.toml` and update `uv.lock`.
- Add frontend libraries through `package.json` and update `package-lock.json`.
- Do not vendor third-party libraries into a shared `libs/` directory.
- Re-run `make dev` after dependency or Dockerfile changes.

For a database change:

```bash
make dev
# Edit an ORM model, then generate and review a revision:
make migration MESSAGE="add users"
make up
make test
```

Commit models and migrations together. The first-start PostgreSQL script creates
roles and databases, not application tables; Alembic owns the schema.

## Deployment and operations

`make up` builds locally. `make deploy` pulls published backend and frontend
images and explicitly disables builds. The dev override is never used on a server.

```bash
make init-prod
# Review infra/.env.production and both application env files.
# Publish release images and configure DNS/TLS before deploying.
make deploy ENV_FILE=infra/.env.production
make smoke ENV_FILE=infra/.env.production
```

The included release workflow is optional and publishes on pushed `v*` tags.
Nothing is published by local Make commands. Nginx serves HTTP only by default.

```bash
make backup
make restore FILE=backups/FILE.dump TARGET=restore_drill
```

Restore creates a separate database and never switches the live application.
Backups must be copied off-server and recovery tested.

The shell scripts are limited to setup, smoke checks and recovery operations.
Dockerfiles define images; Compose defines runtime wiring; application code does
not manage containers.

- [Architecture](docs/ARCHITECTURE.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Operations](docs/OPERATIONS.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [MIT license](LICENSE)
