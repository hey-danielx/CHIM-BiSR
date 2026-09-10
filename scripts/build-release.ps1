# Builds the CHIM server tarball and the Skyrim MO2/Nexus zip.
[CmdletBinding()]
param(
    [string]$GitHubRepo,
    [string]$PexPath,
    [string]$Mo2PatchPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nestedPlugin = Join-Path $repoRoot 'CHIM-BiSR'
if (Test-Path -LiteralPath (Join-Path $nestedPlugin 'manifest.json')) {
    $pluginRoot = $nestedPlugin
} else {
    $pluginRoot = $repoRoot
}
$skyrimPatchRoot = Join-Path $repoRoot 'SkyrimPatch'
$pscRoot = Join-Path $skyrimPatchRoot 'Scripts\Source'
if (-not (Test-Path -LiteralPath $pscRoot)) {
    $pscRoot = Join-Path $repoRoot 'scripts\source'
}
$csvPath = Join-Path $skyrimPatchRoot 'CHIM\bisr_actions.csv'
$releaseRoot = Join-Path $repoRoot 'release'
$utf8 = New-Object System.Text.UTF8Encoding $false
$localMo2 = 'E:\Skyrim SE\wabbajack\MODs\mods\BiSR-CHIM patch'

if ([string]::IsNullOrWhiteSpace($PexPath)) {
    $fromPatch = Join-Path $skyrimPatchRoot 'Scripts'
    $fromMo2 = Join-Path $localMo2 'Scripts'
    if (Test-Path -LiteralPath (Join-Path $fromPatch 'mzinCHIM.pex')) {
        $PexPath = $fromPatch
    } elseif (Test-Path -LiteralPath $fromMo2) {
        $PexPath = $fromMo2
    } else {
        $PexPath = $fromPatch
    }
}

if ([string]::IsNullOrWhiteSpace($Mo2PatchPath) -and -not $env:GITHUB_ACTIONS -and (Test-Path -LiteralPath $localMo2)) {
    $Mo2PatchPath = $localMo2
}

$manifest = Get-Content -LiteralPath (Join-Path $pluginRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$pluginName = [string]$manifest.name
$version = [string]$manifest.version
$scriptNames = @('mzinCHIM', 'mzinBathePlayerAlias')

if (-not [string]::IsNullOrWhiteSpace($GitHubRepo)) {
    $manifest | Add-Member -NotePropertyName git_repo -NotePropertyValue $GitHubRepo -Force
    $downloadBase = "https://github.com/$GitHubRepo/releases/latest/download"
    if (-not $manifest.channels.main.PSObject.Properties['package_urls']) {
        $manifest.channels.main | Add-Member -NotePropertyName package_urls -NotePropertyValue @() -Force
    }
    $manifest.channels.main.package_urls = @(
        "$downloadBase/$pluginName.tar.gz",
        "$downloadBase/$pluginName.tar"
    )
    $manifest | Add-Member -NotePropertyName mod_download_url -NotePropertyValue "$downloadBase/BiSR-CHIM-Patch.zip" -Force
    $json = ($manifest | ConvertTo-Json -Depth 20).Trim() + "`n"
    [System.IO.File]::WriteAllText((Join-Path $pluginRoot 'manifest.json'), $json, $utf8)
}

function Copy-PluginFiles {
    param([string]$Destination)

    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    foreach ($file in @('context_pre.php', 'globals.php', 'index.php', 'preprocessing.php', 'manifest.json', 'README.md', 'dwemer-package.json')) {
        $source = Join-Path $pluginRoot $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $Destination $file)
        }
    }
    foreach ($directory in @('lib', 'migrations')) {
        $source = Join-Path $pluginRoot $directory
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $Destination -Recurse
        }
    }
}

function Invoke-TarArchive {
    param(
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$ChangeDir,
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string[]]$Flags
    )

    $tarCmd = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path -LiteralPath $tarCmd)) {
        $tarCmd = 'tar'
    }

    $archiveDir = Split-Path -Parent $ArchivePath
    $archiveName = Split-Path -Leaf $ArchivePath
    [System.IO.Directory]::CreateDirectory($archiveDir) | Out-Null

    Push-Location -LiteralPath $archiveDir
    try {
        & $tarCmd @Flags $archiveName -C $ChangeDir $SourceName
        if ($LASTEXITCODE -ne 0) {
            throw "tar failed while creating $ArchivePath (exit $LASTEXITCODE)"
        }
    }
    finally {
        Pop-Location
    }
}

function New-ZipFromDirectory {
    param(
        [string]$SourceDirectory,
        [string]$ZipPath,
        [bool]$IncludeRoot
    )

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($ZipPath)) | Out-Null
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $SourceDirectory,
        $ZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $IncludeRoot
    )
}

[System.IO.Directory]::CreateDirectory($releaseRoot) | Out-Null

$dwpkgPath = Join-Path $releaseRoot "$pluginName\$version.dwpkg"
& (Join-Path $PSScriptRoot 'build-dwpkg.ps1') -OutputPath $dwpkgPath | Out-Null

$tarStage = Join-Path ([System.IO.Path]::GetTempPath()) ('chim-bisr-tar-' + [guid]::NewGuid().ToString('N'))
$skyrimStage = Join-Path ([System.IO.Path]::GetTempPath()) ('chim-bisr-skyrim-' + [guid]::NewGuid().ToString('N'))
$githubStage = Join-Path $releaseRoot 'github-src'

try {
    $pluginStage = Join-Path $tarStage $pluginName
    Copy-PluginFiles -Destination $pluginStage

    $tarGz = Join-Path $releaseRoot "$pluginName.tar.gz"
    $tar = Join-Path $releaseRoot "$pluginName.tar"
    foreach ($archive in @($tarGz, $tar)) {
        if (Test-Path -LiteralPath $archive) {
            Remove-Item -LiteralPath $archive -Force
        }
    }
    Invoke-TarArchive -ArchivePath $tar -ChangeDir $tarStage -SourceName $pluginName -Flags @('-cf')
    Invoke-TarArchive -ArchivePath $tarGz -ChangeDir $tarStage -SourceName $pluginName -Flags @('-czf')

    [System.IO.Directory]::CreateDirectory($skyrimStage) | Out-Null
    $scriptsOut = Join-Path $skyrimStage 'Scripts'
    $sourceOut = Join-Path $scriptsOut 'Source'
    $chimOut = Join-Path $skyrimStage 'CHIM'
    $pluginBundleOut = Join-Path $chimOut "server-plugins\$pluginName"
    [System.IO.Directory]::CreateDirectory($sourceOut) | Out-Null
    [System.IO.Directory]::CreateDirectory($pluginBundleOut) | Out-Null

    foreach ($name in $scriptNames) {
        $psc = Join-Path $pscRoot "$name.psc"
        if (-not (Test-Path -LiteralPath $psc)) {
            throw "Missing Papyrus source $psc"
        }
        Copy-Item -LiteralPath $psc -Destination (Join-Path $sourceOut "$name.psc")

        $pex = Join-Path $PexPath "$name.pex"
        if (-not (Test-Path -LiteralPath $pex)) {
            throw "Missing compiled script $pex"
        }
        Copy-Item -LiteralPath $pex -Destination (Join-Path $scriptsOut "$name.pex")
    }

    if (-not (Test-Path -LiteralPath $csvPath)) {
        throw "Missing actions CSV $csvPath"
    }
    Copy-Item -LiteralPath $csvPath -Destination (Join-Path $chimOut 'bisr_actions.csv')
    Copy-Item -LiteralPath $dwpkgPath -Destination (Join-Path $pluginBundleOut "$version.dwpkg")

    $skyrimZip = Join-Path $releaseRoot 'BiSR-CHIM-Patch.zip'
    New-ZipFromDirectory -SourceDirectory $skyrimStage -ZipPath $skyrimZip -IncludeRoot $false

    if (Test-Path -LiteralPath $githubStage) {
        Remove-Item -LiteralPath $githubStage -Recurse -Force
    }
    Copy-PluginFiles -Destination $githubStage
    $githubScripts = Join-Path $githubStage 'scripts'
    [System.IO.Directory]::CreateDirectory($githubScripts) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build-dwpkg.ps1') -Destination (Join-Path $githubScripts 'build-dwpkg.ps1')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build-release.ps1') -Destination (Join-Path $githubScripts 'build-release.ps1')
    $skyrimPatchSrc = Join-Path $githubStage 'SkyrimPatch'
    Copy-Item -LiteralPath $skyrimStage -Destination $skyrimPatchSrc -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination (Join-Path $githubStage 'README.md') -Force
    $workflowSrc = Join-Path $repoRoot '.github\workflows\package-release.yml'
    if (Test-Path -LiteralPath $workflowSrc) {
        $workflowDest = Join-Path $githubStage '.github\workflows'
        [System.IO.Directory]::CreateDirectory($workflowDest) | Out-Null
        Copy-Item -LiteralPath $workflowSrc -Destination (Join-Path $workflowDest 'package-release.yml')
    }

    $ignore = @"
release/
*.dwpkg
*.tar
*.tar.gz
*.zip
Thumbs.db
"@
    [System.IO.File]::WriteAllText((Join-Path $githubStage '.gitignore'), $ignore.Replace("`n", "`r`n"), $utf8)

    if (-not [string]::IsNullOrWhiteSpace($Mo2PatchPath)) {
        [System.IO.Directory]::CreateDirectory($Mo2PatchPath) | Out-Null
        $mo2Scripts = Join-Path $Mo2PatchPath 'Scripts'
        $mo2Source = Join-Path $mo2Scripts 'Source'
        $mo2Chim = Join-Path $Mo2PatchPath 'CHIM'
        $mo2Bundle = Join-Path $mo2Chim "server-plugins\$pluginName"
        [System.IO.Directory]::CreateDirectory($mo2Source) | Out-Null
        [System.IO.Directory]::CreateDirectory($mo2Bundle) | Out-Null
        foreach ($name in $scriptNames) {
            Copy-Item -LiteralPath (Join-Path $pscRoot "$name.psc") -Destination (Join-Path $mo2Source "$name.psc") -Force
            Copy-Item -LiteralPath (Join-Path $PexPath "$name.pex") -Destination (Join-Path $mo2Scripts "$name.pex") -Force
        }
        Copy-Item -LiteralPath $csvPath -Destination (Join-Path $mo2Chim 'bisr_actions.csv') -Force
        Copy-Item -LiteralPath $dwpkgPath -Destination (Join-Path $mo2Bundle "$version.dwpkg") -Force
    }

    Write-Output "Server plugin: $tarGz"
    Write-Output "Server tar:    $tar"
    Write-Output "Skyrim zip:    $skyrimZip"
    Write-Output "Bundled dwpkg: $dwpkgPath"
    Write-Output "GitHub tree:   $githubStage"
}
finally {
    foreach ($temp in @($tarStage, $skyrimStage)) {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Recurse -Force
        }
    }
}
