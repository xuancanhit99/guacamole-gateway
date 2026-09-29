[CmdletBinding()]
param(
    [string]$AdminUsername = "admin",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot ".env"

if ((Test-Path -LiteralPath $envPath) -and -not $Force) {
    Write-Host ".env already exists. Use -Force only when intentionally replacing it."
    exit 0
}

if ($AdminUsername -notmatch '^[A-Za-z0-9._-]{3,64}$') {
    throw "AdminUsername must be 3-64 characters using letters, digits, dot, underscore, or hyphen."
}

function New-Secret {
    $bytes = New-Object byte[] 36
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) }
    finally { $rng.Dispose() }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$postgresPassword = New-Secret
$adminPassword = New-Secret

$content = @"
GATEWAY_BIND=127.0.0.1
GATEWAY_PORT=8080

POSTGRES_DB=guacamole
POSTGRES_USER=guacamole
POSTGRES_PASSWORD=$postgresPassword

GUACAMOLE_ADMIN_USERNAME=$AdminUsername
GUACAMOLE_ADMIN_PASSWORD=$adminPassword

GUACD_LOG_LEVEL=info
GUACAMOLE_LOG_LEVEL=info
"@

[IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))

Write-Host "Created $envPath with random credentials."
Write-Host "Initial login: $AdminUsername"
Write-Host "Initial password: $adminPassword"
Write-Warning "Store this password securely. The bootstrap account is created only when the database volume is empty."

