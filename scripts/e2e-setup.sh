#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_path="$project_root/.env.e2e"

if [ -f "$env_path" ]; then
    echo ".env.e2e already exists."
    exit 0
fi

if command -v openssl >/dev/null 2>&1; then
    password=$(openssl rand -base64 36 | tr '+/' '-_' | tr -d '=\n')
else
    password=$(dd if=/dev/urandom bs=36 count=1 2>/dev/null | base64 | tr '+/' '-_' | tr -d '=\n')
fi

umask 077
{
    echo "E2E_SSH_USER=e2e"
    echo "E2E_SSH_PASSWORD=$password"
} > "$env_path"
echo "Created $env_path with a random, test-only SSH password."

