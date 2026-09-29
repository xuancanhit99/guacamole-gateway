[CmdletBinding()]
param([int]$WaitTimeoutSeconds = 180)

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "scripts/start.ps1") -WaitTimeoutSeconds $WaitTimeoutSeconds

