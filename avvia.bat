@echo off
REM avvia.bat – LIDO CODICI SBALLATI
REM Lancia avvia.ps1 tramite PowerShell (gestisce tutto in modo robusto)

chcp 65001 > nul 2>&1

REM Ottieni il percorso della cartella dove si trova questo .bat
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

powershell -ExecutionPolicy Bypass -File "%HERE%\avvia.ps1" -ScriptDir "%HERE%"
if errorlevel 1 pause
