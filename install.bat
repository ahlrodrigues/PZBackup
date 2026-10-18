@echo off
REM Instalador do PZ Backup para Windows - de dois cliques neste arquivo.
REM (No Linux use o instalar.sh)
chcp 65001 >nul
ver | find "Windows" >/dev/null || (echo Este instalador e para Windows. No Linux use: bash instalar.sh & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arquivos\windows\instalar-windows.ps1"
