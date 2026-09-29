#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

for file in LICENSE THIRD_PARTY_NOTICES.md VERSION README.md compose.yaml compose.e2e.yaml .env.example db/init/001-create-schema.sql db/init/002-create-admin-user.sh; do
    [ -f "$file" ] || { echo "RELEASE AUDIT FAILED: missing $file" >&2; exit 1; }
done

version=$(tr -d '\r\n' < VERSION)
printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$'
grep -q '^MIT License' LICENSE
for component in 'Apache Guacamole' PostgreSQL Nginx 'LinuxServer OpenSSH'; do
    grep -q "$component" THIRD_PARTY_NOTICES.md
done

! grep -REn '^[[:space:]]*image:[[:space:]]*[^[:space:]]+:latest[[:space:]]*$' compose*.yaml
! grep -REn '^[[:space:]]*privileged:[[:space:]]*true' compose*.yaml

secret_regex='-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|[Bb]earer[[:space:]]+[A-Za-z0-9._-]{32,}'
matches=$(find . -type f \
    ! -path './.git/*' ! -path './dist/*' ! -path './backups/*' \
    ! -path './data/drive/*' ! -path './data/recordings/*' \
    ! -path '*/__pycache__/*' ! -name '.env' ! -name '.env.e2e' \
    ! -name '*.pyc' ! -name '*.dump' ! -name '*.gz' ! -name '*.zip' \
    -exec grep -IEn -- "$secret_regex" {} + || true)
if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
    echo 'RELEASE AUDIT FAILED: possible secret detected' >&2
    exit 1
fi

tests/test-config.sh
echo "PASS: release audit for v$version"

