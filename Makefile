SHELL := /bin/bash
.DEFAULT_GOAL := help

ENV_FILE ?= infra/.env
COMPOSE := docker compose --env-file $(ENV_FILE) --env-file app/backend/.env --env-file app/frontend/.env -f infra/compose/compose.yaml
COMPOSE_DEV := $(COMPOSE) -f infra/compose/compose.dev.yaml
TOOLS_IMAGE := webapp-quality:local
# In rootless Docker, container UID 0 maps to the invoking host user.
TOOLS_USER = $(shell if [[ "$$(docker info --format '{{json .SecurityOptions}}')" == *name=rootless* ]]; then printf '0:0'; else printf '%s:%s' "$$(id -u)" "$$(id -g)"; fi)
TOOLS_RUN = docker run --rm --network none --user "$(TOOLS_USER)" --cap-drop ALL --security-opt no-new-privileges --workdir /workspace

.PHONY: help init init-prod check check-prod build test test-backend test-frontend frontend-tools up dev down restart status logs smoke backup restore deploy pull tools format format-check lint migrate migration

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target> [ENV_FILE=infra/.env]\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Create local configuration and secrets (safe to repeat)
	bash scripts/init.sh infra/.env infra/.env.example

init-prod: ## Create production configuration and secrets (safe to repeat)
	bash scripts/init.sh infra/.env.production infra/.env.production.example

tools: ## Build the shared formatter/linter image (Docker cache makes repeats cheap)
	docker build --quiet -t $(TOOLS_IMAGE) scripts/tooling

format: tools ## Format Python, JS/TS, CSS, JSON, HTML, shell, YAML and Markdown
	$(TOOLS_RUN) -v "$(CURDIR):/workspace" $(TOOLS_IMAGE) format

format-check: tools ## Check formatting without changing files
	$(TOOLS_RUN) -v "$(CURDIR):/workspace:ro" $(TOOLS_IMAGE) format-check

lint: tools frontend-tools ## Check formatting, linters and frontend TypeScript types
	$(TOOLS_RUN) -v "$(CURDIR):/workspace:ro" $(TOOLS_IMAGE) lint
	docker run --rm --network none --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges --no-healthcheck webapp-frontend-tools:local npm run check

check: ## Validate the resolved Compose configuration
	@$(COMPOSE) config -q
	@$(COMPOSE_DEV) config -q

check-prod: ## Validate the production Compose configuration
	@$(COMPOSE) config -q

build: check ## Build backend and frontend production images
	$(COMPOSE) build --pull backend frontend

test: test-backend test-frontend ## Run backend and frontend tests

test-backend: ## Run pytest using the backend development image
	docker build --target development -t webapp-development:test ./app/backend
	docker run --rm --network none --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges --no-healthcheck webapp-development:test pytest

frontend-tools: ## Build the frontend development image for checks and tests
	docker build --quiet --target development -f app/frontend/Dockerfile -t webapp-frontend-tools:local .

test-frontend: frontend-tools ## Run frontend API-client and UI tests
	docker run --rm --network none --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges --no-healthcheck webapp-frontend-tools:local npm test

migrate: check-prod ## Apply Alembic migrations from the current release image
	$(COMPOSE) run --rm migrate

migration: ## Generate an Alembic revision in dev: make migration MESSAGE="add users"
	@test -n "$(MESSAGE)" || { echo 'Set MESSAGE="describe the schema change".' >&2; exit 2; }
	$(COMPOSE_DEV) exec --user "$(TOOLS_USER)" -e MIGRATION_MESSAGE="$(MESSAGE)" backend sh -c 'alembic revision --autogenerate -m "$$MIGRATION_MESSAGE"'

up: check ## Start the complete stack and wait for health checks
	$(COMPOSE) up -d --build --wait --wait-timeout 180 --remove-orphans

dev: check ## Start development stage with source hot reload
	$(COMPOSE) build backend
	$(COMPOSE_DEV) up -d --build --wait --wait-timeout 180 --remove-orphans

down: ## Stop containers while preserving persistent data
	$(COMPOSE) down --remove-orphans

restart: ## Restart frontend and backend without switching modes
	$(COMPOSE) restart backend frontend

status: ## Show container state and health
	$(COMPOSE) ps

logs: ## Follow logs from all services
	$(COMPOSE) logs --tail=100 -f

smoke: ## Verify frontend HTML, backend health and API through the public port
	bash scripts/smoke.sh "$(ENV_FILE)"

backup: ## Create a timestamped PostgreSQL backup
	ENV_FILE="$(ENV_FILE)" bash scripts/backup.sh

restore: ## Restore FILE into a new DB named TARGET=restore_name
	@test -n "$(FILE)" && test -n "$(TARGET)" || { echo "Usage: make restore FILE=backups/file.dump TARGET=restore_name" >&2; exit 2; }
	ENV_FILE="$(ENV_FILE)" bash scripts/restore.sh "$(FILE)" "$(TARGET)"

pull: check-prod ## Pull published application and infrastructure images
	$(COMPOSE) pull

deploy: check-prod ## Pull and deploy on a server without building source code
	$(COMPOSE) pull
	$(COMPOSE) up -d --no-build --wait --wait-timeout 180 --remove-orphans

