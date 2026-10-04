Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')

try {
    Initialize-ProjectNode -InstallMissing
    Set-Location -LiteralPath $script:ProjectRoot
    Write-Host "Using Node.js at $script:NodePath"
    Write-Host 'Installing project dependencies...'
    Invoke-ProjectNpm -Arguments @('ci', '--include=dev')
    Write-Host 'Building the production app...'
    Invoke-ProjectNpm -Arguments @('run', 'build')
    Write-Host 'Setup completed successfully. Double-click Mo_chay.bat to run the app.'
    exit 0
} catch {
    [Console]::Error.WriteLine("Setup failed: $($_.Exception.Message)")
    exit 1
}
