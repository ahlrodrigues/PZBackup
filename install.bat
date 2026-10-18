@echo off
REM PZ Backup installer for Windows - double-click this file.
REM (On Linux use install.sh)
chcp 65001 >nul
ver | find "Windows" >nul || (echo This installer is for Windows. On Linux run: bash install.sh & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\windows\install-windows.ps1"
