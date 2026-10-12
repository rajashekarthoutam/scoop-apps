@echo off
setlocal EnableDelayedExpansion
:: -----------------------------------------------------------------------------
:: Rajashekar's Secure Scoop Package Management Bootstrap Launcher
:: Bypasses default Windows PowerShell execution policy restriction safely
:: -----------------------------------------------------------------------------

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-fresh-pc.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Setup failed with error code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

endlocal
