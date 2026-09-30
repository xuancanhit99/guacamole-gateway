#!/bin/sh
set -eu

if [ -z "${GUACAMOLE_ADMIN_USERNAME:-}" ] || [ -z "${GUACAMOLE_ADMIN_PASSWORD:-}" ]; then
    echo "GUACAMOLE_ADMIN_USERNAME and GUACAMOLE_ADMIN_PASSWORD are required" >&2
    exit 1
fi

if [ "${GUACAMOLE_ADMIN_USERNAME}" = "guacadmin" ] || [ "${GUACAMOLE_ADMIN_PASSWORD}" = "guacadmin" ]; then
    echo "Refusing the well-known Guacamole default credentials" >&2
    exit 1
fi

if [ "${#GUACAMOLE_ADMIN_PASSWORD}" -lt 16 ]; then
    echo "GUACAMOLE_ADMIN_PASSWORD must contain at least 16 characters" >&2
    exit 1
fi

psql --set=ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set=admin_username="$GUACAMOLE_ADMIN_USERNAME" \
    --set=admin_password="$GUACAMOLE_ADMIN_PASSWORD" <<'EOSQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

WITH new_entity AS (
    INSERT INTO guacamole_entity (name, type)
    VALUES (:'admin_username', 'USER')
    RETURNING entity_id
), salted_user AS (
    SELECT entity_id,
           gen_random_bytes(32) AS salt
    FROM new_entity
)
INSERT INTO guacamole_user (
    entity_id,
    password_hash,
    password_salt,
    password_date
)
SELECT entity_id,
       digest(convert_to(:'admin_password' || upper(encode(salt, 'hex')), 'UTF8'), 'sha256'),
       salt,
       CURRENT_TIMESTAMP
FROM salted_user;

INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, permission::guacamole_system_permission_type
FROM (
    VALUES
        (:'admin_username', 'CREATE_CONNECTION'),
        (:'admin_username', 'CREATE_CONNECTION_GROUP'),
        (:'admin_username', 'CREATE_SHARING_PROFILE'),
        (:'admin_username', 'CREATE_USER'),
        (:'admin_username', 'CREATE_USER_GROUP'),
        (:'admin_username', 'ADMINISTER'),
        (:'admin_username', 'AUDIT')
) permissions (username, permission)
JOIN guacamole_entity
  ON guacamole_entity.name = permissions.username
 AND guacamole_entity.type = 'USER';

INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT owner.entity_id,
       guacamole_user.user_id,
       permission::guacamole_object_permission_type
FROM (
    VALUES
        (:'admin_username', :'admin_username', 'READ'),
        (:'admin_username', :'admin_username', 'UPDATE'),
        (:'admin_username', :'admin_username', 'ADMINISTER')
) permissions (username, affected_username, permission)
JOIN guacamole_entity owner
  ON owner.name = permissions.username
 AND owner.type = 'USER'
JOIN guacamole_entity affected
  ON affected.name = permissions.affected_username
 AND affected.type = 'USER'
JOIN guacamole_user
  ON guacamole_user.entity_id = affected.entity_id;
EOSQL

