#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
version=$(tr -d '\r\n' < VERSION)
scripts/release-audit.sh

package_name="guacamole-gateway-v$version"
temporary_root=$(mktemp -d)
stage="$temporary_root/$package_name"
dist="$project_root/dist"
mkdir -p "$stage" "$dist"
trap 'rm -rf "$temporary_root"' EXIT INT TERM

tar -cf - \
    --exclude='./.git' --exclude='./dist' --exclude='./backups/*' \
    --exclude='./data/drive/*' --exclude='./data/recordings/*' \
    --exclude='./.env' --exclude='./.env.e2e' --exclude='*/__pycache__' \
    --exclude='*.pyc' --exclude='*.pyo' --exclude='*.dump' \
    --exclude='*.gz' --exclude='*.zip' . | tar -C "$stage" --strip-components=1 -xf -

mkdir -p "$stage/backups" "$stage/data/drive" "$stage/data/recordings"
: > "$stage/backups/.gitkeep"
: > "$stage/data/drive/.gitkeep"
: > "$stage/data/recordings/.gitkeep"

(
    cd "$stage"
    find . -type f ! -name MANIFEST.sha256 -print | sort | xargs sha256sum
) > "$stage/MANIFEST.sha256"

rm -f "$dist/$package_name.zip" "$dist/$package_name.tar.gz" "$dist/SHA256SUMS.txt"
tar -C "$temporary_root" -czf "$dist/$package_name.tar.gz" "$package_name"
if command -v zip >/dev/null 2>&1; then
    (cd "$temporary_root" && zip -qr "$dist/$package_name.zip" "$package_name")
elif command -v python3 >/dev/null 2>&1; then
    python3 - "$temporary_root" "$dist/$package_name.zip" "$package_name" <<'PY'
import os
import sys
import zipfile

root, output, package = sys.argv[1:]
base = os.path.join(root, package)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for current, _, files in os.walk(base):
        for name in files:
            path = os.path.join(current, name)
            archive.write(path, os.path.relpath(path, root))
PY
else
    echo "zip and python3 are unavailable; produced tar.gz only" >&2
fi

(
    cd "$dist"
    sha256sum "$package_name.tar.gz"
    [ ! -f "$package_name.zip" ] || sha256sum "$package_name.zip"
) > "$dist/SHA256SUMS.txt"
echo "Release bundles written to $dist"

