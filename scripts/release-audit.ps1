[CmdletBinding()]
param([switch]$SkipCompose)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "RELEASE AUDIT FAILED: $Message" }
}

$required = @(
    "LICENSE", "THIRD_PARTY_NOTICES.md", "VERSION", "README.md",
    "compose.yaml", "compose.e2e.yaml", ".env.example",
    "db/init/001-create-schema.sql", "db/init/002-create-admin-user.sh"
)
foreach ($relative in $required) {
    Assert-Release (Test-Path -LiteralPath (Join-Path $projectRoot $relative)) "missing $relative"
}

$version = [IO.File]::ReadAllText((Join-Path $projectRoot "VERSION")).Trim()
Assert-Release ($version -match '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$') "VERSION must use semantic versioning"

$license = [IO.File]::ReadAllText((Join-Path $projectRoot "LICENSE"))
Assert-Release ($license -match '^MIT License') "project LICENSE must be present"
$notices = [IO.File]::ReadAllText((Join-Path $projectRoot "THIRD_PARTY_NOTICES.md"))
foreach ($component in @("Apache Guacamole", "PostgreSQL", "Nginx", "LinuxServer OpenSSH")) {
    Assert-Release ($notices.Contains($component)) "third-party notice missing $component"
}

$compose = [IO.File]::ReadAllText((Join-Path $projectRoot "compose.yaml"))
$e2eCompose = [IO.File]::ReadAllText((Join-Path $projectRoot "compose.e2e.yaml"))
Assert-Release ($compose -notmatch '(?m)^\s*image:\s*\S+:latest\s*$') "default compose uses :latest"
Assert-Release ($e2eCompose -notmatch '(?m)^\s*image:\s*\S+:latest\s*$') "E2E compose uses :latest"
Assert-Release ($compose -notmatch '(?m)^\s*privileged:\s*true') "privileged container found"
Assert-Release ($e2eCompose -notmatch '(?m)^\s*privileged:\s*true') "privileged E2E container found"

$forbiddenNames = @(".env", ".env.e2e", "id_rsa", "id_ed25519")
$scanFiles = Get-ChildItem -LiteralPath $projectRoot -Recurse -File | Where-Object {
    $relative = [IO.Path]::GetRelativePath($projectRoot, $_.FullName).Replace('\', '/')
    $_.Name -notin $forbiddenNames -and
    $relative -notmatch '^(dist|backups|data/drive|data/recordings|\.git)/' -and
    $relative -notmatch '(^|/)__pycache__/' -and
    $_.Extension -notin @('.pyc', '.pyo', '.dump', '.gz', '.zip')
}

$secretPatterns = @(
    '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
    '\bgh[pousr]_[A-Za-z0-9_]{20,}\b',
    '\bAKIA[0-9A-Z]{16}\b',
    '(?i)bearer\s+[A-Za-z0-9._-]{32,}'
)
foreach ($file in $scanFiles) {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($pattern in $secretPatterns) {
        Assert-Release ($text -notmatch $pattern) "possible secret in $([IO.Path]::GetRelativePath($projectRoot, $file.FullName))"
    }
}

Assert-Release (-not (Test-Path -LiteralPath (Join-Path $projectRoot "dist/.env"))) "dist contains .env"

if (-not $SkipCompose) {
    & (Join-Path $projectRoot "tests/test-config.ps1")
    if ($LASTEXITCODE -ne 0) { throw "static configuration tests failed" }
}

Write-Host "PASS: release audit for v$version ($($scanFiles.Count) source files scanned)"

