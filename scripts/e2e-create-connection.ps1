[CmdletBinding()]
param(
    [string]$BaseUrl = "http://127.0.0.1:8080",
    [string]$ConnectionName = "E2E SSH target"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Read-Env([string]$Path) {
    $values = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^([^#=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

$mainEnv = Read-Env (Join-Path $projectRoot ".env")
$e2eEnv = Read-Env (Join-Path $projectRoot ".env.e2e")
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/guacamole/api/tokens" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{ username = $mainEnv.GUACAMOLE_ADMIN_USERNAME; password = $mainEnv.GUACAMOLE_ADMIN_PASSWORD }
$token = $tokenResponse.authToken
$escapedToken = [Uri]::EscapeDataString($token)
$apiRoot = "$BaseUrl/guacamole/api/session/data/postgresql"

$payload = @{
    name = $ConnectionName
    parentIdentifier = $null
    protocol = "ssh"
    parameters = @{
        hostname = "e2e-ssh"
        port = "2222"
        username = $e2eEnv.E2E_SSH_USER
        password = $e2eEnv.E2E_SSH_PASSWORD
        "server-alive-interval" = "15"
        "color-scheme" = "green-black"
        "font-size" = "12"
    }
    attributes = @{}
} | ConvertTo-Json -Depth 6

$connections = Invoke-RestMethod -Uri "$apiRoot/connections?token=$escapedToken"
$existing = $connections.PSObject.Properties.Value | Where-Object { $_.name -eq $ConnectionName } | Select-Object -First 1

if ($existing) {
    Invoke-RestMethod -Method Put -Uri "$apiRoot/connections/$($existing.identifier)?token=$escapedToken" `
        -ContentType "application/json" -Body $payload | Out-Null
    $connectionId = $existing.identifier
}
else {
    $created = Invoke-RestMethod -Method Post -Uri "$apiRoot/connections?token=$escapedToken" `
        -ContentType "application/json" -Body $payload
    $connectionId = $created.identifier
}

Write-Output $connectionId

