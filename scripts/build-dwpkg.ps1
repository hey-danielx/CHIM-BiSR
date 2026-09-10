# Builds the versioned .dwpkg CHIM copies from Data/CHIM/server-plugins into HerikaServer.
[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nestedPlugin = Join-Path $repoRoot 'CHIM-BiSR'
if (Test-Path -LiteralPath (Join-Path $nestedPlugin 'manifest.json')) {
    $pluginRoot = $nestedPlugin
} else {
    $pluginRoot = $repoRoot
}
$legacyManifestPath = Join-Path $pluginRoot 'manifest.json'
$packageTemplatePath = Join-Path $pluginRoot 'dwemer-package.json'

$legacyManifest = Get-Content -LiteralPath $legacyManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$packageManifest = Get-Content -LiteralPath $packageTemplatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$packageManifest.version = [string]$legacyManifest.version
$pluginName = [string]$legacyManifest.name
$version = [string]$packageManifest.version

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "release\$pluginName\$version.dwpkg"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($OutputPath)) | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding $false
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('chim-bisr-dwpkg-' + [guid]::NewGuid().ToString('N'))
$serverStage = Join-Path $stageRoot 'server'

try {
    [System.IO.Directory]::CreateDirectory($serverStage) | Out-Null

    foreach ($file in @('context_pre.php', 'globals.php', 'index.php', 'preprocessing.php', 'manifest.json', 'README.md', 'dwemer-package.json')) {
        $source = Join-Path $pluginRoot $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $serverStage $file)
        }
    }
    foreach ($directory in @('lib', 'migrations')) {
        $source = Join-Path $pluginRoot $directory
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $serverStage -Recurse
        }
    }

    $manifestJson = ($packageManifest | ConvertTo-Json -Depth 20).Trim() + "`n"
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'manifest.json'), $manifestJson, $utf8)

    $checksumLines = foreach ($file in Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Sort-Object FullName) {
        if ($file.Name -eq 'checksums.sha256') { continue }
        $relative = $file.FullName.Substring($stageRoot.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash $relative"
    }
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'checksums.sha256'), (($checksumLines -join "`n") + "`n"), $utf8)

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    $archiveStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($file in Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Sort-Object FullName) {
                $relative = $file.FullName.Substring($stageRoot.Length + 1).Replace('\', '/')
                $entry = $archive.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                $inputStream = [System.IO.File]::OpenRead($file.FullName)
                try {
                    $inputStream.CopyTo($entryStream)
                }
                finally {
                    $inputStream.Dispose()
                    $entryStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $archiveStream.Dispose()
    }

    Write-Output $OutputPath
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
