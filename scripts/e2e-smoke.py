#!/usr/bin/env python3
"""Create an SSH connection and prove the Guacamole tunnel reaches guacd."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from http.cookiejar import CookieJar
from typing import Dict, Optional, Tuple


def env_file(path: str) -> Dict[str, str]:
    values: Dict[str, str] = {}
    with open(path, encoding="utf-8") as stream:
        for raw in stream:
            line = raw.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key] = value
    return values


def request(opener: urllib.request.OpenerDirector, url: str, method: str = "GET",
            body: Optional[bytes] = None, headers: Optional[Dict[str, str]] = None,
            retry_429: bool = False) -> Tuple[int, bytes, Dict[str, str]]:
    max_attempts = 8 if retry_429 else 1
    for attempt in range(max_attempts):
        req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
        try:
            with opener.open(req, timeout=20) as response:
                return response.status, response.read(), dict(response.headers.items())
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == max_attempts - 1:
                raise
            # Tiện ích ban/rate-limit tùy chọn có thể tạm thời từ chối nhiều lần
            # chạy smoke test liên tiếp từ một địa chỉ; hãy chấp nhận trạng thái này.
            error.close()
            time.sleep(min(2 ** attempt, 10))
    raise RuntimeError("unreachable request retry state")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--create-only", action="store_true", help="upsert the demo connection without opening a tunnel")
    args = parser.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    main_env = env_file(os.path.join(root, ".env"))
    e2e_env = env_file(os.path.join(root, ".env.e2e"))
    base_url = os.environ.get("BASE_URL", "http://127.0.0.1:8080").rstrip("/")
    name = os.environ.get("E2E_CONNECTION_NAME", "E2E SSH target")

    required = ("GUACAMOLE_ADMIN_USERNAME", "GUACAMOLE_ADMIN_PASSWORD")
    if any(not main_env.get(key) for key in required):
        raise RuntimeError(".env is missing Guacamole administrator credentials")
    if any(not e2e_env.get(key) for key in ("E2E_SSH_USER", "E2E_SSH_PASSWORD")):
        raise RuntimeError(".env.e2e is missing test SSH credentials")

    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))
    token_body = urllib.parse.urlencode({
        "username": main_env["GUACAMOLE_ADMIN_USERNAME"],
        "password": main_env["GUACAMOLE_ADMIN_PASSWORD"],
    }).encode()
    _, raw_token, _ = request(
        opener, f"{base_url}/guacamole/api/tokens", "POST", token_body,
        {"Content-Type": "application/x-www-form-urlencoded"}, retry_429=True,
    )
    token = json.loads(raw_token)["authToken"]
    api_root = f"{base_url}/guacamole/api/session/data/postgresql"
    common_query = urllib.parse.urlencode({"token": token})

    connection = {
        "name": name,
        "parentIdentifier": None,
        "protocol": "ssh",
        "parameters": {
            "hostname": "e2e-ssh",
            "port": "2222",
            "username": e2e_env["E2E_SSH_USER"],
            "password": e2e_env["E2E_SSH_PASSWORD"],
            "server-alive-interval": "15",
            "color-scheme": "green-black",
            "font-size": "12",
        },
        "attributes": {},
    }
    _, raw_connections, _ = request(opener, f"{api_root}/connections?{common_query}")
    connections = json.loads(raw_connections)
    existing = next((item for item in connections.values() if item.get("name") == name), None)
    encoded = json.dumps(connection).encode()
    if existing:
        identifier = str(existing["identifier"])
        request(opener, f"{api_root}/connections/{urllib.parse.quote(identifier)}?{common_query}",
                "PUT", encoded, {"Content-Type": "application/json"})
    else:
        _, raw_created, _ = request(opener, f"{api_root}/connections?{common_query}",
                                    "POST", encoded, {"Content-Type": "application/json"})
        identifier = str(json.loads(raw_created)["identifier"])

    if args.create_only:
        print(identifier)
        return 0

    connect_body = urllib.parse.urlencode({
        "token": token,
        "GUAC_ID": identifier,
        "GUAC_DATA_SOURCE": "postgresql",
        "GUAC_TYPE": "c",
        "GUAC_WIDTH": "1024",
        "GUAC_HEIGHT": "768",
        "GUAC_DPI": "96",
        "GUAC_TIMEZONE": "UTC",
        "GUAC_IMAGE": "image/png",
    }).encode()
    status, raw_uuid, response_headers = request(
        opener, f"{base_url}/guacamole/tunnel?connect", "POST", connect_body,
        {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"},
    )
    if status != 200 or not raw_uuid.strip():
        raise RuntimeError(f"HTTP tunnel did not allocate (status {status})")
    tunnel_uuid = raw_uuid.decode("utf-8", errors="replace").strip()
    tunnel_token = response_headers.get("Guacamole-Tunnel-Token")
    if not tunnel_token:
        raise RuntimeError("Guacamole tunnel did not return a tunnel token")

    read_url = f"{base_url}/guacamole/tunnel?read:{urllib.parse.quote(tunnel_uuid)}"
    read_req = urllib.request.Request(
        read_url,
        headers={"Guacamole-Tunnel-Token": tunnel_token},
    )
    try:
        with opener.open(read_req, timeout=20) as response:
            data = response.read1(64 * 1024)
    finally:
        try:
            close_url = f"{base_url}/guacamole/tunnel?write:{urllib.parse.quote(tunnel_uuid)}"
            close_req = urllib.request.Request(
                close_url, data=b"10.disconnect;", method="POST",
                headers={"Guacamole-Tunnel-Token": tunnel_token,
                         "Content-Type": "application/octet-stream"},
            )
            opener.open(close_req, timeout=3).close()
        except Exception:
            pass

    text = data.decode("utf-8", errors="replace")
    if not any(instruction in text for instruction in ("size,", "img,", "sync,")):
        raise RuntimeError(f"tunnel returned no display instructions; received {text[:240]!r}")

    compose = [
        "docker", "compose", "--env-file", ".env", "--env-file", ".env.e2e",
        "-f", "compose.yaml", "-f", "compose.e2e.yaml", "--profile", "e2e",
        "logs", "--tail=200", "guacd", "e2e-ssh",
    ]
    # Docker Desktop/Engine khác nhau về độ chính xác timestamp và múi giờ của
    # `logs --since`. Kiểm tra phần log mới nhất để dòng audit SSH kịp được ghi ra.
    logs = ""
    for _ in range(20):
        logs = subprocess.run(
            compose, cwd=root, check=True, capture_output=True,
            text=True, encoding="utf-8", errors="replace",
        ).stdout or ""
        if ("SSH connection successful." in logs and
                f"Accepted password for {e2e_env['E2E_SSH_USER']}" in logs):
            break
        time.sleep(0.5)
    else:
        raise RuntimeError("guacd/SSH logs did not confirm a successful connection")

    print(f"PASS: Guacamole tunnel, guacd SSH, and target authentication (connection={identifier})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"E2E FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)

