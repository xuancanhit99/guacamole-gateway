[CmdletBinding()]
param([string]$Version)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Version) { $Version = [IO.File]::ReadAllText((Join-Path $projectRoot "VERSION")).Trim() }

& (Join-Path $PSScriptRoot "release-audit.ps1")
$packageName = "guacamole-gateway-v$Version"
$dist = Join-Path $projectRoot "dist"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("guacamole-release-" + [Guid]::NewGuid().ToString("N"))
$stage = Join-Path $temporaryRoot $packageName
[IO.Directory]::CreateDirectory($stage) | Out-Null
[IO.Directory]::CreateDirectory($dist) | Out-Null

$excludedDirectories = @(".git", "dist", "__pycache__")
$excludedFiles = @(".env", ".env.e2e")

try {
    Get-ChildItem -LiteralPath $projectRoot -Recurse -File | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($projectRoot, $_.FullName)
        $parts = $relative -split '[\\/]'
        $skip = ($parts | Where-Object { $_ -in $excludedDirectories }).Count -gt 0
        if ($relative -match '^(backups|data[\\/]drive|data[\\/]recordings)[\\/]' -and $_.Name -ne '.gitkeep') { $skip = $true }
        $skip = $skip -or $_.Name -in $excludedFiles -or $_.Extension -in @('.pyc', '.pyo', '.dump', '.gz', '.zip')
        if (-not $skip) {
            $destination = Join-Path $stage $relative
            [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $destination
        }
    }

    $manifestPath = Join-Path $stage "MANIFEST.sha256"
    $manifest = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.FullName -ne $manifestPath } | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($stage, $_.FullName).Replace('\', '/')
        "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
    }
    [IO.File]::WriteAllLines($manifestPath, $manifest, [Text.UTF8Encoding]::new($false))

    $zipPath = Join-Path $dist "$packageName.zip"
    $tarPath = Join-Path $dist "$packageName.tar.gz"
    if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    if (Test-Path $tarPath) { Remove-Item -LiteralPath $tarPath -Force }
    Compress-Archive -Path $stage -DestinationPath $zipPath -CompressionLevel Optimal
    tar -C $temporaryRoot -czf $tarPath $packageName
    if ($LASTEXITCODE -ne 0) { throw "tar archive creation failed" }

    $checksums = @($zipPath, $tarPath) | ForEach-Object {
        "{0}  {1}" -f (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant(), (Split-Path -Leaf $_)
    }
    [IO.File]::WriteAllLines((Join-Path $dist "SHA256SUMS.txt"), $checksums, [Text.UTF8Encoding]::new($false))
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}

Write-Host "Release bundles written to $dist"

