#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gateway_port=${GATEWAY_PORT:-}
if [ -z "$gateway_port" ] && [ -f "$project_root/.env" ]; then
    gateway_port=$(sed -n 's/^GATEWAY_PORT=//p' "$project_root/.env" | head -n 1)
fi
gateway_port=${gateway_port:-8080}
base_url=${BASE_URL:-"http://127.0.0.1:$gateway_port"}
headers=$(mktemp)
body=$(mktemp)
trap 'rm -f "$headers" "$body"' EXIT INT TERM

curl --fail --silent --show-error "$base_url/healthz" > "$body"
[ "$(tr -d '\r\n' < "$body")" = "ok" ]

curl --fail --silent --show-error --location --dump-header "$headers" "$base_url/guacamole/" > "$body"
grep -qi 'Guacamole' "$body"
grep -qi '^X-Content-Type-Options:' "$headers"
grep -qi '^X-Frame-Options:' "$headers"
grep -qi '^Referrer-Policy:' "$headers"
grep -qi '^Content-Security-Policy:' "$headers"

echo "Healthy: $base_url/guacamole/"

