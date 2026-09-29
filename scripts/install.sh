#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
start=0
e2e=0
for arg in "$@"; do
    case "$arg" in
        --start) start=1 ;;
        --e2e) e2e=1 ;;
        *) echo "Usage: $0 [--start] [--e2e]" >&2; exit 2 ;;
    esac
done

command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null
cd "$project_root"
[ -f .env ] || scripts/setup.sh
docker compose config --quiet

if [ "$e2e" -eq 1 ]; then
    [ -f .env.e2e ] || scripts/e2e-setup.sh
    docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e config --quiet
fi

if [ "$start" -eq 1 ]; then
    if [ "$e2e" -eq 1 ]; then scripts/e2e-up.sh
    else scripts/start.sh
    fi
fi
echo "Installed Guacamole Gateway files at $project_root"

