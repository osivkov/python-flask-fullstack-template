#!/usr/bin/env bash
set -euo pipefail

cd /workspace
mode=${1:-lint}

# Explicit scopes exclude real .env files, secrets, backups and generated files.
shell_files=(scripts/*.sh scripts/tooling/*.sh infra/postgres/*.sh)
document_files=(
  '*.md' 'docs/**/*.md'
  '.github/**/*.yml' 'infra/**/*.yaml'
  'app/frontend/*.{json,html,ts}'
  'app/frontend/src/**/*.{ts,tsx,css}'
)

case "$mode" in
format)
  ruff format --no-cache app/backend
  shfmt -i 2 -w "${shell_files[@]}"
  prettier --write "${document_files[@]}"
  ;;
format-check)
  ruff format --no-cache --check app/backend
  shfmt -i 2 -d "${shell_files[@]}"
  prettier --check "${document_files[@]}"
  ;;
lint)
  bash scripts/tooling/quality.sh format-check
  ruff check --no-cache app/backend
  shellcheck "${shell_files[@]}"
  # GitHub's `on` is valid YAML 1.2. Do not interpret it as a YAML 1.1 boolean.
  yamllint -d '{extends: relaxed, rules: {line-length: disable, truthy: disable}}' \
    .github infra/compose
  hadolint app/backend/Dockerfile app/frontend/Dockerfile scripts/tooling/Dockerfile
  actionlint -pyflakes= .github/workflows/*.yml
  ;;
*)
  echo 'Usage: make format | make format-check | make lint' >&2
  exit 2
  ;;
esac
