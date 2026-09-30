#!/usr/bin/env sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_path=${1:-"$project_root/backups/guacamole-$(date +%Y%m%d-%H%M%S).dump"}
mkdir -p "$(dirname -- "$output_path")"
cd "$project_root"
docker compose exec -T postgres sh -c 'pg_dump --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" --clean --if-exists --format=custom' > "$output_path"
echo "Backup written to $output_path"

