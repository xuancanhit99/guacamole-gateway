#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
scripts/release-audit.sh
scripts/build-release.sh
cd dist
sha256sum -c SHA256SUMS.txt
archive="guacamole-gateway-v$(tr -d '\r\n' < ../VERSION).tar.gz"
if tar -tf "$archive" | grep -E '/\.env$|/\.env\.e2e$|\.dump$|\.pyc$'; then
    echo 'forbidden release entry detected' >&2
    exit 1
fi
echo "PASS: release archives, checksums, and exclusions"

