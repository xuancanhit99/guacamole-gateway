#!/usr/bin/env sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e stop e2e-ssh
docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e rm -f e2e-ssh

