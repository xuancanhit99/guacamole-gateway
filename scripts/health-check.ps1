[CmdletBinding()]
param([string]$BaseUrl)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $BaseUrl) {
    $bind = "127.0.0.1"
    $port = "8080"
    $envPath = Join-Path $projectRoot ".env"
    if (Test-Path -LiteralPath $envPath) {
        foreach ($line in [IO.File]::ReadAllLines($envPath)) {
            if ($line -match '^GATEWAY_BIND=(.+)$' -and $Matches[1] -notin @('0.0.0.0', '::')) { $bind = $Matches[1] }
            if ($line -match '^GATEWAY_PORT=(\d+)$') { $port = $Matches[1] }
        }
    }
    $BaseUrl = "http://${bind}:$port"
}

$health = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/healthz" -TimeoutSec 10
if ($health.StatusCode -ne 200 -or $health.Content.Trim() -ne "ok") {
    throw "Gateway health endpoint returned an unexpected response."
}

$login = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/guacamole/" -MaximumRedirection 5 -TimeoutSec 20
if ($login.StatusCode -ne 200 -or $login.Content -notmatch 'Guacamole') {
    throw "Guacamole login page is not healthy."
}

$requiredHeaders = @("X-Content-Type-Options", "X-Frame-Options", "Referrer-Policy", "Content-Security-Policy")
foreach ($header in $requiredHeaders) {
    if (-not $login.Headers.ContainsKey($header)) { throw "Missing security header: $header" }
}

# Xác minh auth provider PostgreSQL đã cấu hình mà không in token.
$envPath = Join-Path $projectRoot ".env"
if (Test-Path -LiteralPath $envPath) {
    $values = @{}
    foreach ($line in [IO.File]::ReadAllLines($envPath)) {
        if ($line -match '^([^#=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    if ($values.ContainsKey("GUACAMOLE_ADMIN_USERNAME") -and $values.ContainsKey("GUACAMOLE_ADMIN_PASSWORD")) {
        $tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/guacamole/api/tokens" `
            -ContentType "application/x-www-form-urlencoded" `
            -Body @{ username = $values.GUACAMOLE_ADMIN_USERNAME; password = $values.GUACAMOLE_ADMIN_PASSWORD } `
            -TimeoutSec 20
        if (-not $tokenResponse.authToken -or $tokenResponse.dataSource -ne "postgresql") {
            throw "Guacamole PostgreSQL authentication did not return a valid token."
        }
    }
}

Write-Host "Healthy: $BaseUrl/guacamole/"

