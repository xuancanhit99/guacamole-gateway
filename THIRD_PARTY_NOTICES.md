# Third-Party Notices

This project distributes configuration and scripts. Docker images are pulled
from their upstream registries at installation/runtime and are not embedded in
the release archives.

| Component | Pinned reference | License | Use |
| --- | --- | --- | --- |
| Apache Guacamole web app | `guacamole/guacamole:1.6.0` | Apache-2.0 | Default runtime |
| Apache guacd | `guacamole/guacd:1.6.0` | Apache-2.0 | Default runtime |
| PostgreSQL | `postgres:17.11-alpine` | PostgreSQL License | Default runtime |
| Nginx | `nginx:1.28.3-alpine` | BSD-2-Clause | Default runtime |
| LinuxServer OpenSSH | `lscr.io/linuxserver/openssh-server:version-10.3_p1-r1` | GPL-3.0-only | Optional E2E test profile only |

The checked-in file `db/init/001-create-schema.sql` comes from the Apache
Guacamole 1.6.0 PostgreSQL extension and retains its upstream Apache-2.0
license header.

Before redistribution, review the current upstream notices and image contents:

- <https://guacamole.apache.org/>
- <https://www.postgresql.org/about/licence/>
- <https://nginx.org/LICENSE>
- <https://github.com/linuxserver/docker-openssh-server>

