param(
    [switch]$NoBrowser,
    [ValidateRange(1, 65535)][int]$Port = 3000
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')
$server = $null
$statePath = $null
$startupFailed = $false
$ProgressPreference = 'SilentlyContinue'

function Get-ListenerProcess {
    param([int]$ListenPort)
    try {
        $connection = Get-NetTCPConnection -State Listen -LocalPort $ListenPort -ErrorAction Stop | Select-Object -First 1
        if ($connection) { return Get-CimInstance Win32_Process -Filter "ProcessId = $($connection.OwningProcess)" }
    } catch { }
    return $null
}

function Test-ProjectResponse {
    param([string]$Address)
    try {
        $response = Invoke-WebRequest -Uri $Address -UseBasicParsing -TimeoutSec 2
        return ($response.Content -match 'PDF to Markdown Converter')
    } catch { return $false }
}

function Test-PortOccupied {
    param([int]$ListenPort)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect([Net.IPAddress]::Loopback, $ListenPort, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(500)) { return $false }
        $client.EndConnect($pending)
        return $true
    } catch { return $false }
    finally { $client.Close() }
}

function Test-IsProjectServer {
    param([int]$ListenPort)
    $owner = Get-ListenerProcess -ListenPort $ListenPort
    if (-not $owner -or -not $owner.CommandLine) { return $false }
    $projectCli = Join-Path $script:ProjectRoot 'node_modules\next\dist\bin\next'
    if ($owner.CommandLine.IndexOf($projectCli, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    return Test-ProjectResponse -Address "http://127.0.0.1:$ListenPort"
}

function Get-FreePort {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally { $listener.Stop() }
}

try {
    Initialize-ProjectNode
    Set-Location -LiteralPath $script:ProjectRoot
    if (-not (Test-Path -LiteralPath (Join-Path $script:ProjectRoot 'node_modules') -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $script:ProjectRoot '.next\BUILD_ID') -PathType Leaf)) {
        throw 'Setup is incomplete. Double-click setup.bat first, then run Mo_chay.bat again.'
    }

    # Remember the actual port, so repeated clicks reuse a server even when 3000 was busy.
    $statePath = Join-Path $script:ProjectRoot '.local\server.json'
    if (-not $PSBoundParameters.ContainsKey('Port') -and (Test-Path -LiteralPath $statePath)) {
        try {
            $previousServer = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            $previousPort = $previousServer.port -as [int]
            if ($previousPort -ge 1 -and $previousPort -le 65535) {
                $previousOwner = Get-ListenerProcess -ListenPort $previousPort
                if ($previousOwner -and $previousOwner.ProcessId -eq $previousServer.pid -and
                    (Test-IsProjectServer -ListenPort $previousPort)) {
                    $Port = $previousPort
                }
            }
        } catch { }
    }

    $address = "http://127.0.0.1:$Port"
    $requestedPort = $Port
    $alreadyRunning = $false
    $owner = Get-ListenerProcess -ListenPort $Port
    if ($owner -or (Test-PortOccupied -ListenPort $Port)) {
        if (Test-IsProjectServer -ListenPort $Port) {
            $alreadyRunning = $true
        } else {
            $Port = Get-FreePort
            $address = "http://127.0.0.1:$Port"
            Write-Host "Port $requestedPort is in use by another app. Starting PDF2MD at $address instead."
        }
    }

    if (-not $alreadyRunning) {
        Write-Host "Starting PDF2MD at $address. Press Ctrl+C to stop it."
        $nextCli = Join-Path $script:ProjectRoot 'node_modules\next\dist\bin\next'
        $server = Start-Process -FilePath $script:NodePath `
            -ArgumentList ('"{0}" start --hostname 127.0.0.1 --port {1}' -f $nextCli, $Port) `
            -WorkingDirectory $script:ProjectRoot -PassThru -NoNewWindow

        $timer = [Diagnostics.Stopwatch]::StartNew()
        $ready = $false
        while ($timer.Elapsed.TotalSeconds -lt 120) {
            $server.Refresh()
            if ($server.HasExited) { throw "Production server exited with code $($server.ExitCode)." }
            if (Test-ProjectResponse -Address $address) { $ready = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) { throw "PDF2MD did not become ready within 120 seconds at $address." }
        New-Item -ItemType Directory -Path (Split-Path -Parent $statePath) -Force | Out-Null
        @{ pid = $server.Id; port = $Port } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    } else {
        Write-Host "PDF2MD is already running at $address."
    }

    if (-not $NoBrowser) { Start-Process -FilePath $address }
    if ($server) {
        $server.WaitForExit()
        $server.Refresh()
        if ($server.HasExited -and $null -ne $server.ExitCode -and $server.ExitCode -ne 0) {
            throw "Production server stopped with code $($server.ExitCode)."
        }
    }
} catch {
    $startupFailed = $true
    [Console]::Error.WriteLine("Could not start PDF2MD: $($_.Exception.Message)")
    exit 1
} finally {
    if ($server) {
        $server.Refresh()
        if (-not $server.HasExited) {
            & taskkill.exe /PID $server.Id /T /F 2>$null | Out-Null
        }
        if ($statePath -and (Test-Path -LiteralPath $statePath)) {
            try {
                $savedServer = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
                if ($savedServer.pid -eq $server.Id) { Remove-Item -LiteralPath $statePath -Force }
            } catch { }
        }
    }
    # Ctrl+C also enters finally: stopping a running app is a successful action.
    if (-not $startupFailed) { exit 0 }
}
