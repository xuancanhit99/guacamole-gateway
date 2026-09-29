$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $projectRoot "scripts/release-audit.ps1")
& (Join-Path $projectRoot "scripts/build-release.ps1")

$version = [IO.File]::ReadAllText((Join-Path $projectRoot "VERSION")).Trim()
$dist = Join-Path $projectRoot "dist"
$archive = Join-Path $dist "guacamole-gateway-v$version.tar.gz"
$zip = Join-Path $dist "guacamole-gateway-v$version.zip"
if (-not (Test-Path $archive) -or -not (Test-Path $zip)) { throw "release archives are missing" }

foreach ($line in [IO.File]::ReadAllLines((Join-Path $dist "SHA256SUMS.txt"))) {
    $parts = $line -split '\s+', 2
    $actual = (Get-FileHash (Join-Path $dist $parts[1]) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $parts[0]) { throw "checksum mismatch: $($parts[1])" }
}

$entries = tar -tf $archive
if ($LASTEXITCODE -ne 0) { throw "cannot list release tarball" }
$forbidden = $entries | Where-Object {
    $_ -match '/\.env$|/\.env\.e2e$|\.dump$|\.pyc$' -or
    ($_ -match '/(backups|data/drive|data/recordings)/(.+)$' -and $_ -notmatch '/\.gitkeep$')
}
if ($forbidden) { throw "forbidden release entries: $($forbidden -join ', ')" }

Write-Host "PASS: release archives, checksums, and exclusions"

