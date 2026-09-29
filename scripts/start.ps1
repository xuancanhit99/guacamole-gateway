[CmdletBinding()]
param([int]$WaitTimeoutSeconds = 180)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot ".env"))) {
    & (Join-Path $PSScriptRoot "setup.ps1")
}

Push-Location $projectRoot
try {
    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw "docker compose config failed" }

    docker compose up -d --wait --wait-timeout $WaitTimeoutSeconds
    if ($LASTEXITCODE -ne 0) { throw "Services did not become healthy within $WaitTimeoutSeconds seconds" }

    & (Join-Path $PSScriptRoot "health-check.ps1")
}
finally {
    Pop-Location
}

