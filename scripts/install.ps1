[CmdletBinding()]
param([switch]$Start, [switch]$E2E)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker was not found. Install Docker Desktop or Docker Engine with Compose v2."
}
$composeVersion = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) { throw "Docker Compose v2 is required: $composeVersion" }

Push-Location $projectRoot
try {
    if (-not (Test-Path -LiteralPath ".env")) { & (Join-Path $PSScriptRoot "setup.ps1") }
    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw "The generated Compose configuration is invalid." }

    if ($E2E) {
        if (-not (Test-Path -LiteralPath ".env.e2e")) { & (Join-Path $PSScriptRoot "e2e-setup.ps1") }
        docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e config --quiet
        if ($LASTEXITCODE -ne 0) { throw "The E2E Compose configuration is invalid." }
    }

    if ($Start) {
        if ($E2E) { & (Join-Path $PSScriptRoot "e2e-up.ps1") }
        else { & (Join-Path $PSScriptRoot "start.ps1") }
    }
}
finally { Pop-Location }

Write-Host "Installed Guacamole Gateway files at $projectRoot"
Write-Host "Run .\scripts\start.ps1 to start the default profile."

