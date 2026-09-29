#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_env=$(mktemp)
test_e2e_env=$(mktemp)
rendered=$(mktemp)
e2e_rendered=$(mktemp)
trap 'rm -f "$test_env" "$test_e2e_env" "$rendered" "$e2e_rendered"' EXIT INT TERM

cat > "$test_env" <<'EOF'
GATEWAY_BIND=127.0.0.1
GATEWAY_PORT=18080
POSTGRES_DB=guacamole
POSTGRES_USER=guacamole
POSTGRES_PASSWORD=test-only-postgres-secret-please-never-deploy
GUACAMOLE_ADMIN_USERNAME=testadmin
GUACAMOLE_ADMIN_PASSWORD=test-only-admin-secret-please-never-deploy
EOF
cat > "$test_e2e_env" <<'EOF'
E2E_SSH_USER=e2e
E2E_SSH_PASSWORD=test-only-random-looking-e2e-secret-123456789
EOF

cd "$project_root"
docker compose --env-file "$test_env" config > "$rendered"

grep -q 'host_ip: 127.0.0.1' "$rendered"
grep -q 'published: "18080"' "$rendered"
[ "$(grep -c 'published:' "$rendered")" -eq 1 ]
grep -q 'internal: true' "$rendered"
grep -q 'no-new-privileges:true' "$rendered"
grep -q 'guacamole/guacamole:1.6.0' "$rendered"
grep -q 'guacamole/guacd:1.6.0' "$rendered"
grep -q 'postgres:17.11-alpine' "$rendered"
grep -q 'nginx:1.28.3-alpine' "$rendered"
! grep -q ':latest' "$rendered"
! grep -q 'privileged: true' "$rendered"

docker compose --env-file "$test_env" --env-file "$test_e2e_env" \
    -f compose.yaml -f compose.e2e.yaml --profile e2e config > "$e2e_rendered"
grep -q 'lscr.io/linuxserver/openssh-server:version-10.3_p1-r1' "$e2e_rendered"
grep -q 'USER_PASSWORD: test-only-random-looking' "$e2e_rendered"
[ "$(grep -c 'published:' "$e2e_rendered")" -eq 1 ]
! grep -q 'image:.*:latest' "$e2e_rendered"

grep -q 'X-Content-Type-Options' nginx/nginx.conf
grep -q 'Content-Security-Policy' nginx/nginx.conf
grep -q 'proxy_buffering off' nginx/nginx.conf
grep -q 'Refusing the well-known' db/init/002-create-admin-user.sh
grep -q 'at least 16 characters' db/init/002-create-admin-user.sh
grep -q 'pgcrypto' db/init/002-create-admin-user.sh
grep -q 'GUAC_TYPE' scripts/e2e-smoke.py
grep -q 'SSH connection successful' scripts/e2e-smoke.py
grep -q 'Accepted password for' scripts/e2e-smoke.py

if [ "${1:-}" = "--runtime" ]; then
    scripts/health-check.sh
fi

echo "PASS: compose, security, proxy, database bootstrap"

