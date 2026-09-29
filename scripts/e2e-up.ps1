[CmdletBinding()]
param([switch]$RunSmoke)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot ".env"))) {
    throw "Run scripts/setup.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot ".env.e2e"))) {
    & (Join-Path $PSScriptRoot "e2e-setup.ps1")
}

Push-Location $projectRoot
try {
    $compose = @("--env-file", ".env", "--env-file", ".env.e2e", "-f", "compose.yaml", "-f", "compose.e2e.yaml", "--profile", "e2e")
    docker compose @compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw "E2E compose config failed" }
    docker compose @compose up -d --wait --wait-timeout 180
    if ($LASTEXITCODE -ne 0) { throw "E2E services did not become healthy" }
    if ($RunSmoke) {
        python (Join-Path $PSScriptRoot "e2e-smoke.py")
        if ($LASTEXITCODE -ne 0) { throw "E2E tunnel smoke test failed" }
    }
}
finally {
    Pop-Location
}

