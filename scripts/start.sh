#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ ! -f "$project_root/.env" ]; then
    "$project_root/scripts/setup.sh"
fi

cd "$project_root"
docker compose config --quiet
docker compose up -d --wait --wait-timeout "${WAIT_TIMEOUT_SECONDS:-180}"
"$project_root/scripts/health-check.sh"

