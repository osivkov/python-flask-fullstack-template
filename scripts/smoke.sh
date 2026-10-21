#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
env_file=${1:-infra/.env}
test -f "$env_file" || {
  echo "Missing $env_file." >&2
  exit 1
}

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

bind_address=${BIND_ADDRESS:-127.0.0.1}
http_port=${HTTP_PORT:-8080}
site_address=${SITE_ADDRESS:-http://localhost}

if [[ "$site_address" == https://* ]]; then
  url="$site_address"
else
  site_host=${site_address#http://}
  url="http://${site_host:-$bind_address}:${http_port}"
fi

curl --fail --silent --show-error --retry 10 --retry-connrefused "$url/" >/dev/null
curl --fail --silent --show-error "$url/healthz" >/dev/null
curl --fail --silent --show-error "$url/readyz" >/dev/null
printf 'Smoke test passed: %s\n' "$url"
