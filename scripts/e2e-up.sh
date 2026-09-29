#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ -f "$project_root/.env" ] || { echo "Run scripts/setup.sh first." >&2; exit 1; }
[ -f "$project_root/.env.e2e" ] || "$project_root/scripts/e2e-setup.sh"

cd "$project_root"
docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e config --quiet
docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e up -d --wait --wait-timeout 180
if [ "${RUN_SMOKE:-0}" = "1" ]; then
    python3 scripts/e2e-smoke.py
fi

