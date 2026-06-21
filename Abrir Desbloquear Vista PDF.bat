@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0Desbloquear Vista PDF.ps1"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: El script fallo con codigo %errorlevel%
    pause
)
