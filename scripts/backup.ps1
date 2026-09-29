[CmdletBinding()]
param([string]$OutputPath)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path $projectRoot "backups/guacamole-$stamp.dump"
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path -Parent $outputFullPath
[IO.Directory]::CreateDirectory($outputDir) | Out-Null

Push-Location $projectRoot
try {
    $command = 'pg_dump --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" --clean --if-exists --format=custom'
    docker compose exec -T postgres sh -c $command > $outputFullPath
    if ($LASTEXITCODE -ne 0) { throw "Database backup failed" }
}
finally {
    Pop-Location
}

Write-Host "Backup written to $outputFullPath"

