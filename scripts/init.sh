#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target_env=${1:-infra/.env}
example_env=${2:-infra/.env.example}

command -v docker >/dev/null || {
  echo "Docker is required." >&2
  exit 1
}
command -v openssl >/dev/null || {
  echo "OpenSSL is required." >&2
  exit 1
}
docker compose version >/dev/null || {
  echo "Docker Compose v2 is required." >&2
  exit 1
}
test -f "$example_env" || {
  echo "Missing $example_env." >&2
  exit 1
}

if [[ ! -e "$target_env" ]]; then
  cp "$example_env" "$target_env"
  chmod 600 "$target_env"
  echo "Created $target_env from $example_env."
else
  echo "Preserved existing $target_env."
fi

for app_dir in app/backend app/frontend; do
  if [[ ! -e "$app_dir/.env" ]]; then
    cp "$app_dir/.env.example" "$app_dir/.env"
    chmod 600 "$app_dir/.env"
    echo "Created $app_dir/.env."
  else
    echo "Preserved existing $app_dir/.env."
  fi
done

mkdir -p secrets backups
chmod 700 secrets backups

for name in db_admin_password db_app_password; do
  path="secrets/${name}.txt"
  if [[ ! -e "$path" ]]; then
    value=$(openssl rand -base64 36 | tr -d '\n')
    printf '%s\n' "$value" >"$path"
    # Compose bind-mounts secret files without remapping container UIDs.
    # The owner-only parent directory protects them on the host; 0644 lets
    # the explicitly selected non-root container users read their mounts.
    chmod 644 "$path"
    echo "Created $path."
  else
    chmod 644 "$path"
    echo "Preserved existing $path."
  fi
done

echo "Initialization complete. Review $target_env before starting the stack."
