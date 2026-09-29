[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot ".env.e2e"

if ((Test-Path -LiteralPath $envPath) -and -not $Force) {
    Write-Host ".env.e2e already exists."
    exit 0
}

$bytes = New-Object byte[] 36
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) }
finally { $rng.Dispose() }
$password = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
$content = @"
E2E_SSH_USER=e2e
E2E_SSH_PASSWORD=$password
"@
[IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))
Write-Host "Created $envPath with a random, test-only SSH password."

