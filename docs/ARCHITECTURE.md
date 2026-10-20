# Architecture

This repository contains two applications, not a Flask app with embedded pages.

```text
Production:
Browser → frontend / Nginx → /api/* → backend / Gunicorn → PostgreSQL
                 └──────── static React build

Development:
Browser → frontend / Vite → /api/* → backend / Flask → PostgreSQL
```

Only the frontend publishes a host port. Both applications share the
`frontend` Docker network. Backend, migrations and PostgreSQL share the internal
`backend` network; the database is not publicly exposed.

## Application boundaries

`app/backend` owns Python dependencies, API handlers, ORM models, Alembic revisions
and pytest tests. `src/webapp` is a Python package. It contains no HTML templates
or static frontend assets. Gunicorn loads `webapp:create_app()`.

`app/frontend` owns React/TypeScript source, its API client, browser assets,
npm dependencies and frontend tests. Vite builds production files into `dist/`.
Only that build is copied into the final Nginx image; Node and npm are absent.

In development, source code is mounted read-only. Vite caches go to `/tmp`.
The Alembic revisions directory is writable for migration generation. Dependency
changes require rebuilding development images; they are not installed at startup.

There is no shared library directory. Python dependencies use pyproject/uv.lock;
frontend dependencies use package.json/package-lock.json. Extract your own shared
package only when there is an actual second consumer.

## HTTP contract

| Endpoint              | Responsibility                                         |
| --------------------- | ------------------------------------------------------ |
| `/`                   | React HTML and assets, served by the frontend          |
| `GET /api/status`     | JSON: backend version and persisted counter            |
| `POST /api/increment` | Atomically increment the counter; return updated JSON  |
| `/healthz`            | Backend process responds without querying the database |
| `/readyz`             | Backend can query the database                         |
| `/nginx-healthz`      | Production frontend's Nginx health                     |

The frontend requests relative same-origin API paths; production Nginx and dev
Vite forward them to Flask. No CORS middleware is needed for this arrangement.
Nginx has SPA fallback for UI paths, but API failures are not rewritten to HTML.

The counter endpoint checks an Origin header when supplied. This demo is not
an authentication or complete CSRF solution. Design those controls when adding
accounts or cookie-based sessions.

## Database lifecycle

1. PostgreSQL initializes an empty volume.
2. Its init hook creates the application database and non-superuser role.
3. A one-shot job runs `alembic upgrade head` from the production backend image.
4. The backend starts after migration success; the frontend waits for readiness.

The init hook runs only on an empty volume. Alembic records schema revisions in
`alembic_version` and takes a PostgreSQL advisory lock during migration.
Application startup never calls `create_all`.

The application role owns its database and can perform DDL. Separate migration
and runtime roles are a possible hardening step, not implemented here.

## Build and runtime files

| File                             | Responsibility                                                       |
| -------------------------------- | -------------------------------------------------------------------- |
| `app/backend/Dockerfile`         | Python development/production images                                 |
| `app/frontend/Dockerfile`        | Node development image and Nginx production image                    |
| `infra/nginx/default.conf`       | Static files, SPA fallback, API routing and headers                  |
| `infra/compose/compose.yaml`     | Production services, builds, networks, storage and limits            |
| `infra/compose/compose.dev.yaml` | Development targets, source mounts and public frontend env           |
| `scripts/tooling/`               | Repository formatter/linter image; not part of the application stack |

Two Compose files are sufficient. Production defaults include build instructions:
`make up` builds them, whereas `make deploy` pulls release images and uses
`--no-build`. The dev override only changes development-specific behavior.
Its `!override` tmpfs entry requires Compose 2.24.4+.

The backend build context is `app/backend`. The frontend context is the repository
root because its final image also needs `infra/nginx/default.conf`. The root
`.dockerignore` allows only frontend source/build files and that config, excluding
all env files, backend code, secrets and backups.

## Settings and security boundaries

Deployment settings live in `infra/.env`; each app owns its own env file.
Frontend `VITE_*` settings are public build inputs, never server secrets.
Password files are mounted into PostgreSQL, backend and the migration job only.
The frontend image and container never receive database credentials.

The backend runs as UID 10001. The Vite development server runs as the Node image's
non-root user. Production Nginx uses its official entrypoint and worker model.
Application containers have read-only root filesystems and writable tmpfs paths.
Backend and dev frontend drop all Linux capabilities. Container logs rotate.

File-backed secrets are not encrypted. The host `secrets/` directory uses mode
700 and files 644 so different container users can read their mounted files.
The host directory restricts ordinary user access; Docker daemon access grants
effective access to these secrets.

Health checks do not replace external monitoring, and Docker does not restart
a running container solely because it becomes unhealthy. Operators own TLS,
firewall rules, host patching, off-site backups, capacity sizing and alerting.
