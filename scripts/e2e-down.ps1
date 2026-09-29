$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$compose = @("--env-file", ".env", "--env-file", ".env.e2e", "-f", "compose.yaml", "-f", "compose.e2e.yaml", "--profile", "e2e")
Push-Location $projectRoot
try {
    docker compose @compose stop e2e-ssh
    docker compose @compose rm -f e2e-ssh
}
finally { Pop-Location }

