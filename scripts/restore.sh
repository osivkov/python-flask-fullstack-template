#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 backups/FILE.dump restore_database" >&2
  exit 2
fi

env_file=${ENV_FILE:-infra/.env}
app_env_file=app/backend/.env
backup_file=$1
target=$2

test -f "$env_file" || {
  echo "Missing $env_file." >&2
  exit 1
}
test -s "$backup_file" || {
  echo "Backup is missing or empty: $backup_file" >&2
  exit 1
}

if [[ ! "$target" =~ ^restore_[a-z0-9_]+$ ]]; then
  echo "Target must start with restore_ and contain lowercase letters, digits and underscores only." >&2
  exit 2
fi

if [[ -f "${backup_file}.sha256" ]]; then
  sha256sum --check "${backup_file}.sha256"
fi

compose=(docker compose --env-file "$env_file" --env-file "$app_env_file" -f infra/compose/compose.yaml)
"${compose[@]}" exec -T postgres createdb -U postgres -T template0 "$target"

if ! "${compose[@]}" exec -T postgres pg_restore -U postgres -d "$target" \
  --no-owner --no-privileges --single-transaction <"$backup_file"; then
  echo "Restore failed. Removing incomplete database $target." >&2
  "${compose[@]}" exec -T postgres dropdb -U postgres --if-exists "$target"
  exit 1
fi

echo "Restored into $target. The running application database was not changed."
