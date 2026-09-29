$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (Test-Path -LiteralPath ".env.e2e") {
        docker compose --env-file .env --env-file .env.e2e -f compose.yaml -f compose.e2e.yaml --profile e2e ps
    }
    else { docker compose ps }
    if ($LASTEXITCODE -ne 0) { throw "docker compose ps failed" }
}
finally { Pop-Location }

