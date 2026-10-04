@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
if errorlevel 1 (
    echo.
    echo Application could not start. Run setup.bat first if setup is incomplete.
    pause
    exit /b 1
)
