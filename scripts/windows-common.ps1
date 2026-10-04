Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-NodeMajorVersion {
    param([string]$NodePath)
    try {
        $versionText = (& $NodePath --version 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0 -or $versionText -notmatch '^v?(\d+)\.') { return 0 }
        return [int]$Matches[1]
    } catch { return 0 }
}

function Install-PortableNode {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][ValidateSet('win-x64', 'win-arm64')][string]$NodeArchitecture,
        [string]$ExistingArchive
    )
    $root = (Resolve-Path -LiteralPath $RootPath).Path
    $nodeArch = $NodeArchitecture
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing
    $release = $null
    foreach ($item in $index) {
        if ($item.lts -and [version]($item.version.TrimStart('v')) -ge [version]'22.0' -and
            $item.files -contains "$nodeArch-zip") {
            $release = $item
            break
        }
    }
    if (-not $release) { throw "Could not find a Node.js LTS release for $nodeArch." }

    $version = $release.version
    $archiveName = "node-$version-$nodeArch.zip"
    $baseUri = "https://nodejs.org/dist/$version"
    $toolsDir = Join-Path $root '.tools'
    $stageDir = Join-Path $toolsDir ("node-download-" + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $stageDir $archiveName
    $checksumsPath = Join-Path $stageDir 'SHASUMS256.txt'
    if (-not (Test-Path -LiteralPath $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }
    New-Item -ItemType Directory -Path $stageDir | Out-Null

    if ($ExistingArchive) {
        if ([IO.Path]::GetFileName($ExistingArchive) -ne $archiveName -or -not (Test-Path -LiteralPath $ExistingArchive -PathType Leaf)) {
            throw "Existing archive must be the Node.js release ZIP named $archiveName."
        }
        $archivePath = (Resolve-Path -LiteralPath $ExistingArchive).Path
    } else {
        Write-Host "Downloading Node.js $version for $nodeArch..."
        Invoke-WebRequest -Uri "$baseUri/$archiveName" -OutFile $archivePath -UseBasicParsing
    }
    Invoke-WebRequest -Uri "$baseUri/SHASUMS256.txt" -OutFile $checksumsPath -UseBasicParsing
    $checksumLine = Get-Content -LiteralPath $checksumsPath | Where-Object { $_ -match "\s+$([regex]::Escape($archiveName))$" } | Select-Object -First 1
    if (-not $checksumLine -or $checksumLine -notmatch '^([0-9a-fA-F]{64})\s+') {
        throw "Node.js checksum entry was not found for $archiveName."
    }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw 'Node.js ZIP checksum verification failed.' }

    # Keep extraction paths short: Node's bundled npm has deeply nested paths
    # that can exceed the legacy Windows path limit in a long source folder.
    $extractStage = Join-Path $toolsDir ("n" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $extractDir = Join-Path $extractStage 'expanded'
    New-Item -ItemType Directory -Path $extractDir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $extractDir)
    $sourceDir = Join-Path $extractDir "node-$version-$nodeArch"
    $destination = Join-Path $toolsDir 'node'
    $resolvedTools = [IO.Path]::GetFullPath($toolsDir).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    foreach ($movePath in @($sourceDir, $destination, $extractStage)) {
        $resolvedMovePath = [IO.Path]::GetFullPath($movePath)
        if (-not $resolvedMovePath.StartsWith($resolvedTools, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to move a Node.js folder outside the project tools directory.'
        }
    }
    if (Test-Path -LiteralPath $destination) {
        $backup = Join-Path $toolsDir ("node-old-" + [guid]::NewGuid().ToString('N'))
        $resolvedBackup = [IO.Path]::GetFullPath($backup)
        if (-not $resolvedBackup.StartsWith($resolvedTools, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to move a Node.js backup outside the project tools directory.'
        }
        Move-Item -LiteralPath $destination -Destination $backup
    }
    Move-Item -LiteralPath $sourceDir -Destination $destination
    foreach ($cleanupPath in @($extractStage, $stageDir)) {
        $resolvedCleanup = [IO.Path]::GetFullPath($cleanupPath)
        if (-not $resolvedCleanup.StartsWith($resolvedTools, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove an unexpected setup directory.' }
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
    $nodePath = Join-Path $destination 'node.exe'
    $npmPath = Join-Path $destination 'npm.cmd'
    return [pscustomobject]@{ NodePath = $nodePath; NpmPath = $npmPath }
}

function Initialize-ProjectNode {
    param([switch]$InstallMissing)
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $nodePath = $null
    $npmPath = $null

    $installed = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($installed -and (Get-NodeMajorVersion $installed.Source) -ge 22) {
        $candidateNpm = Join-Path (Split-Path -Parent $installed.Source) 'npm.cmd'
        if (Test-Path -LiteralPath $candidateNpm -PathType Leaf) {
            $nodePath = $installed.Source
            $npmPath = $candidateNpm
        }
    }

    if (-not $nodePath) {
        $localNode = Join-Path $root '.tools\node\node.exe'
        $localNpm = Join-Path $root '.tools\node\npm.cmd'
        if ((Test-Path -LiteralPath $localNode -PathType Leaf) -and
            (Get-NodeMajorVersion $localNode) -ge 22 -and
            (Test-Path -LiteralPath $localNpm -PathType Leaf)) {
            $nodePath = $localNode
            $npmPath = $localNpm
        }
    }

    if (-not $nodePath -and $InstallMissing) {
        $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        if ($architecture -eq 'X64') { $nodeArch = 'win-x64' }
        elseif ($architecture -eq 'Arm64') { $nodeArch = 'win-arm64' }
        else { throw "Unsupported Windows architecture: $architecture. Use 64-bit Windows x64 or ARM64." }
        $portable = Install-PortableNode -RootPath $root -NodeArchitecture $nodeArch
        $nodePath = $portable.NodePath
        $npmPath = $portable.NpmPath
    }
    if (-not $nodePath) { throw 'Node.js 22 or newer was not found. Run setup.bat to install the app runtime.' }

    if (-not (Test-Path -LiteralPath $npmPath -PathType Leaf)) { throw "npm.cmd was not found beside Node.js at $npmPath." }
    $env:PATH = "$(Split-Path -Parent $nodePath);$env:PATH"
    $script:ProjectRoot = $root
    $script:NodePath = $nodePath
    $script:NpmPath = $npmPath
}

function Invoke-ProjectNpm {
    param([string[]]$Arguments)
    & $script:NpmPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "npm $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
}
