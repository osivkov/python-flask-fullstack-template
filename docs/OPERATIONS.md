# Operations

Use `ENV_FILE=infra/.env.production` with Make commands on the server. Examples below
assume commands run from the repository root.

## Inspect the stack

```bash
make status ENV_FILE=infra/.env.production
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml logs --tail=200 backend
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml logs --tail=200 frontend
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml logs --tail=200 postgres
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml stats --no-stream
df -h
```

If a service is unavailable, check DNS, available disk space, container state,
frontend/backend logs, readiness and then database logs. Inspect migration logs if
the backend has not started. Do not delete volumes to fix a failed startup.

## Change the schema

Start the development stack, change a model and generate a revision:

```bash
make dev
make migration MESSAGE="add users"
```

Review the generated file in `app/backend/alembic/versions/`. Autogeneration is
a draft: check constraints, indexes, data conversions and downgrade behavior.
The migration command writes into a host-mounted directory using the host file
owner, including with rootless Docker.

Apply and test the change:

```bash
make up
make format
make lint
make test
make smoke
```

`make up` rebuilds the runtime image and applies its migrations. On the server,
publish and deploy a new release instead. Do not edit migrations that have
already been applied to a shared environment.

## Dependencies

`pyproject.toml` describes direct dependencies; `uv.lock` records the resolved
versions and artifact hashes. Update them together using uv and run the checks:

```bash
cd app/backend
uv lock --upgrade
cd ../..
make lint
make test
make up
make smoke
```

uv can be run in a Python container if you do not install it on the host.
Docker builds use `uv sync --locked` and fail when the lockfile is out of date.

For frontend packages, use Node 24.15+ and npm, or run npm in a Node 24 container:

```bash
cd app/frontend
npm install PACKAGE_NAME
cd ../..
make format
make lint
make test
make dev
```

Commit package.json and package-lock.json together. Images use `npm ci` and
never install missing dependencies at startup. Frontend settings prefixed with
VITE\_ are public and are compiled into production assets; rebuild and publish
the frontend image after changing them.

## Backup and restore

```bash
make backup ENV_FILE=infra/.env.production
```

The command creates a custom-format PostgreSQL dump and SHA-256 checksum under
`backups/`. These files contain application data. Copy them to encrypted storage
outside the server and set a retention schedule appropriate to your recovery
requirements. A backup on the same disk does not protect against server loss.

Test recovery into a new database, never over the running application database:

```bash
make restore ENV_FILE=infra/.env.production \
  FILE=backups/20261020T120000Z-app.dump \
  TARGET=restore_drill

docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml exec -T postgres \
  psql -U postgres -d restore_drill -c 'TABLE alembic_version;'
```

The restore command refuses names without the `restore_` prefix and refuses to
overwrite an existing database. A failed restore removes only the newly created
target. The running application is not switched to the restored database.

After checking the recovered data, remove only the test database:

```bash
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml exec postgres \
  dropdb -U postgres restore_drill
```

A real recovery requires stopping writes, restoring, checking data and roles,
and explicitly switching the application. Test that procedure before relying
on it during an incident.

## Rotate a database password

Schedule a maintenance window. Stop the backend, connect as the database
administrator and use `\password app` (substitute your configured role):

```bash
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml stop backend
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml exec postgres psql -U postgres
```

Write the same new password to `secrets/db_app_password.txt`. Keep the parent
directory at `700` and the file at `644`, then recreate the affected containers:

```bash
docker compose --env-file infra/.env.production --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml up -d --force-recreate migrate backend frontend
make smoke ENV_FILE=infra/.env.production
```

Changing a secret file alone does not change PostgreSQL credentials.

## Existing volumes

Keep `COMPOSE_PROJECT_NAME` stable after first deployment. When intentionally
renaming a stack, first make a backup and stop the old stack without `-v`.
Set `POSTGRES_VOLUME_NAME` to the exact existing volume and
`POSTGRES_VOLUME_EXTERNAL=true` in the new infra env. External volumes are not
deleted by Compose.
