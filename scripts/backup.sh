#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
umask 077

env_file=${ENV_FILE:-infra/.env}
app_env_file=app/backend/.env
test -f "$env_file" || {
  echo "Missing $env_file." >&2
  exit 1
}

mkdir -p backups
partial=$(mktemp backups/.dump-XXXXXXXX)
trap 'rm -f "$partial"' EXIT

docker compose --env-file "$env_file" --env-file "$app_env_file" -f infra/compose/compose.yaml exec -T postgres \
  sh -c 'exec pg_dump -U postgres -d "$APP_DB_NAME" --format=custom --no-owner --no-privileges' >"$partial"

test -s "$partial"
destination="backups/$(date -u +%Y%m%dT%H%M%SZ)-app.dump"
mv "$partial" "$destination"
sha256sum "$destination" >"${destination}.sha256"
echo "Backup created: $destination"
echo "Checksum: ${destination}.sha256"
