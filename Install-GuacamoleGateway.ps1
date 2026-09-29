[CmdletBinding()]
param([switch]$Start, [switch]$E2E)

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "scripts/install.ps1") -Start:$Start -E2E:$E2E

