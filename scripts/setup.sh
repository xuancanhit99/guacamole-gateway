#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_path="$project_root/.env"
admin_username=${1:-admin}

if [ -f "$env_path" ]; then
    echo ".env already exists; refusing to overwrite it." >&2
    exit 0
fi

case "$admin_username" in
    *[!A-Za-z0-9._-]*|'')
        echo "Admin username contains unsupported characters." >&2
        exit 1
        ;;
esac

if [ "${#admin_username}" -lt 3 ] || [ "${#admin_username}" -gt 64 ]; then
    echo "Admin username must contain between 3 and 64 characters." >&2
    exit 1
fi

new_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 36 | tr '+/' '-_' | tr -d '=\n'
    else
        dd if=/dev/urandom bs=36 count=1 2>/dev/null | base64 | tr '+/' '-_' | tr -d '=\n'
    fi
}

postgres_password=$(new_secret)
admin_password=$(new_secret)

umask 077
{
    echo "GATEWAY_BIND=127.0.0.1"
    echo "GATEWAY_PORT=8080"
    echo
    echo "POSTGRES_DB=guacamole"
    echo "POSTGRES_USER=guacamole"
    echo "POSTGRES_PASSWORD=$postgres_password"
    echo
    echo "GUACAMOLE_ADMIN_USERNAME=$admin_username"
    echo "GUACAMOLE_ADMIN_PASSWORD=$admin_password"
    echo
    echo "GUACD_LOG_LEVEL=info"
    echo "GUACAMOLE_LOG_LEVEL=info"
} > "$env_path"

echo "Created $env_path with random credentials."
echo "Initial login: $admin_username"
echo "Initial password: $admin_password"
echo "Store this password securely; bootstrap runs only for an empty database volume."

