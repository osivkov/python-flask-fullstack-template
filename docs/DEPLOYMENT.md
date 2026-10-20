# Deployment

The template deploys on one Linux server. Install Docker Engine, Compose 2.24.4+,
Git, GNU Make, OpenSSL and curl. This guide does not set up TLS or monitoring.

## Images

Deploy two production images:

```text
ghcr.io/owner/repository-backend:v0.1.0
ghcr.io/owner/repository-frontend:v0.1.0
```

The frontend image contains the React build and Nginx configuration. A separate
Nginx image/service and a Node runtime service are not needed.

The optional GitHub Actions release workflow runs CI, then builds and publishes
both images when you push a `v*` tag. Local commands do not publish anything.
The workflow builds Linux amd64. Configure extra platforms if needed.

Use immutable release tags and do not move them. For strict artifact identity,
pin digests in Compose instead of appending a version tag. Python and npm
lockfiles fix dependencies; base image tags may still receive updates.

The workflow builds the frontend with `VITE_API_BASE=/api`. Other browser settings
must be supplied at build time and require a new frontend image. Never pass
server secrets as Vite build arguments.

## Configure the server

Clone the repository, enter its root and run:

```bash
make init-prod
```

Edit `infra/.env.production`:

```dotenv
COMPOSE_PROJECT_NAME=my-service-production
POSTGRES_VOLUME_NAME=my-service-production-postgres
BACKEND_IMAGE=ghcr.io/owner/repository-backend
FRONTEND_IMAGE=ghcr.io/owner/repository-frontend
APP_VERSION=v0.1.0
SITE_ADDRESS=https://app.example.com
BIND_ADDRESS=127.0.0.1
HTTP_PORT=8080
```

Review `app/backend/.env` and `app/frontend/.env` on the server too.
The backend DB name/user must match its initialized database. Env files and
passwords are ignored by Git; only example files belong in the repository.
Separate environments should use separate checkouts and volume names.

The HTTP origin binds to localhost by default. Keep PostgreSQL private.
Configure host access, SSH keys and firewall rules. Private registry packages
require logging into the registry with image read access.

## TLS

Nginx serves HTTP on container port 8080. Before public use, choose one approach:

1. Add HTTPS to `infra/nginx/default.conf`, mount certificates read-only and
   publish port 443. Arrange certificate renewal and reload. Rebuild the frontend
   image when its Nginx configuration changes; never bake private keys into it.
2. Put a host TLS proxy in front of `127.0.0.1:8080`. Keep the HTTP origin private
   and preserve Host. For this HTTPS-only deployment, set
   `proxy_set_header X-Forwarded-Proto https` in the inner Nginx configuration,
   then publish the rebuilt frontend image. Do not trust arbitrary incoming
   forwarding headers on a publicly accessible HTTP origin.

The backend trusts one proxy. Revisit this trust boundary if adding proxy hops.

## Deploy

```bash
make check-prod ENV_FILE=infra/.env.production
make deploy ENV_FILE=infra/.env.production
make status ENV_FILE=infra/.env.production
make smoke ENV_FILE=infra/.env.production
```

Deployment pulls ready-made images and explicitly disables builds. The dev
override is never selected. PostgreSQL starts, the backend image runs Alembic,
then the backend and frontend become available. A failed migration blocks startup.

`make smoke` checks the public URL. Before TLS is ready, check the private origin:

```bash
curl -f http://127.0.0.1:8080/
curl -f http://127.0.0.1:8080/readyz
```

## Update and roll back

1. Back up the database and verify that the release passed CI.
2. Fetch the deployment configuration matching that release.
3. Change APP_VERSION in the deployment env file.
4. Deploy and run the smoke checks.

To roll back application code, select the previous image version and redeploy.
This does not undo schema migrations. Use backward-compatible migrations and
review recovery plans before destructive changes. Container replacement can
briefly interrupt requests; this template is not a zero-downtime platform.

PostgreSQL major upgrades require an explicit pg_upgrade or dump/restore plan.
Configure off-server backups, disk/uptime alerts and host updates independently.
