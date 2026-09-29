[CmdletBinding()]
param([switch]$Runtime)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$composePath = Join-Path $projectRoot "compose.yaml"
$nginxPath = Join-Path $projectRoot "nginx/nginx.conf"
$schemaPath = Join-Path $projectRoot "db/init/001-create-schema.sql"
$bootstrapPath = Join-Path $projectRoot "db/init/002-create-admin-user.sh"
$testEnv = Join-Path $projectRoot ".env.test"
$testE2eEnv = Join-Path $projectRoot ".env.e2e.test"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$secretA = "test-only-postgres-secret-please-never-deploy"
$secretB = "test-only-admin-secret-please-never-deploy"
$envText = @"
GATEWAY_BIND=127.0.0.1
GATEWAY_PORT=18080
POSTGRES_DB=guacamole
POSTGRES_USER=guacamole
POSTGRES_PASSWORD=$secretA
GUACAMOLE_ADMIN_USERNAME=testadmin
GUACAMOLE_ADMIN_PASSWORD=$secretB
"@
[IO.File]::WriteAllText($testEnv, $envText, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($testE2eEnv, "E2E_SSH_USER=e2e`nE2E_SSH_PASSWORD=test-only-random-looking-e2e-secret-123456789`n", [Text.UTF8Encoding]::new($false))

try {
    Push-Location $projectRoot
    try {
        $rendered = docker compose --env-file $testEnv config 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) "docker compose config must render"
    }
    finally {
        Pop-Location
    }

    Assert-True (([regex]::Matches($rendered, '(?m)^\s+published:')).Count -eq 1) "only the gateway may publish a port"
    Assert-True ($rendered -match 'host_ip: 127\.0\.0\.1') "gateway must bind loopback by default"
    Assert-True ($rendered -match 'published: "18080"') "gateway test port must render"
    Assert-True ($rendered -match 'internal: true') "backend network must be internal"
    Assert-True ($rendered -match 'no-new-privileges:true') "containers must disable privilege escalation"
    Assert-True ($rendered -match 'healthcheck:') "services must define health checks"
    Assert-True ($rendered -notmatch 'latest') "images must be pinned, not latest"

    Push-Location $projectRoot
    try {
        $e2eRendered = docker compose --env-file $testEnv --env-file $testE2eEnv `
            -f compose.yaml -f compose.e2e.yaml --profile e2e config 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) "E2E compose profile must render"
    }
    finally {
        Pop-Location
    }
    Assert-True ($e2eRendered -match 'lscr\.io/linuxserver/openssh-server:version-10\.3_p1-r1') "E2E SSH image must be pinned"
    Assert-True ($e2eRendered -match 'profiles:\s*\r?\n\s*- e2e') "E2E target must require the e2e profile"
    Assert-True ($e2eRendered -match 'USER_PASSWORD: test-only-random-looking') "E2E password must be injected from an ignored env file"
    Assert-True (([regex]::Matches($e2eRendered, '(?m)^\s+published:')).Count -eq 1) "E2E target must not publish a host port"
    Assert-True ($e2eRendered -notmatch '(?m)^\s+image:.*:latest') "E2E images must not use latest"

    $compose = [IO.File]::ReadAllText($composePath)
    Assert-True ($compose -match 'guacamole/guacamole:1\.6\.0') "Guacamole version must be pinned"
    Assert-True ($compose -match 'guacamole/guacd:1\.6\.0') "guacd version must match Guacamole"
    Assert-True ($compose -match 'postgres:17\.11-alpine') "PostgreSQL patch version must be pinned"
    Assert-True ($compose -match 'nginx:1\.28\.3-alpine') "Nginx patch version must be pinned"
    Assert-True ($compose -notmatch '(?m)^\s*privileged:\s*true') "privileged containers are forbidden"

    $nginx = [IO.File]::ReadAllText($nginxPath)
    foreach ($header in @('X-Content-Type-Options', 'X-Frame-Options', 'Referrer-Policy', 'Content-Security-Policy')) {
        Assert-True ($nginx.Contains($header)) "Nginx must set $header"
    }
    Assert-True ($nginx -match 'proxy_buffering off') "Guacamole tunnel buffering must be disabled"
    Assert-True ($nginx -match 'proxy_read_timeout 3600s') "long-running remote sessions need a long read timeout"

    Assert-True ((Get-Item $schemaPath).Length -gt 10000) "the official database schema must exist"
    Assert-True (([IO.File]::ReadAllText($schemaPath)) -match 'Licensed to the Apache Software Foundation') "schema provenance must be preserved"

    $bootstrap = [IO.File]::ReadAllText($bootstrapPath)
    Assert-True ($bootstrap -match "Refusing the well-known") "bootstrap must reject default credentials"
    Assert-True ($bootstrap -match "at least 16 characters") "bootstrap must enforce a minimum password length"
    Assert-True ($bootstrap -match "pgcrypto") "bootstrap must use a cryptographic hash implementation"

    $smoke = [IO.File]::ReadAllText((Join-Path $projectRoot "scripts/e2e-smoke.py"))
    Assert-True ($smoke -match 'GUAC_TYPE') "E2E smoke test must open a real Guacamole tunnel"
    Assert-True ($smoke -match 'SSH connection successful') "E2E smoke test must verify guacd protocol success"
    Assert-True ($smoke -match 'Accepted password for') "E2E smoke test must verify target authentication"

    if ($Runtime) {
        & (Join-Path $projectRoot "scripts/health-check.ps1")
    }

    Write-Host "PASS: compose, security, proxy, database bootstrap$(if ($Runtime) { ', runtime health' })"
}
finally {
    if (Test-Path -LiteralPath $testEnv) { Remove-Item -LiteralPath $testEnv -Force }
    if (Test-Path -LiteralPath $testE2eEnv) { Remove-Item -LiteralPath $testE2eEnv -Force }
}

