@echo off
setlocal
cd /d "%~dp0"
echo ==============================================================
echo  PROJECT HOPLITE - UAL NATIVE COMBAT LAB V2
echo ==============================================================
echo.
echo IMPORTANT: close Godot before continuing.
echo Only UAL1 + UAL2 will be installed. No Base Character pack.
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup_assets.ps1"
if errorlevel 1 (
  echo.
  echo SETUP FAILED.
  pause
  exit /b 1
)
echo.
echo SETUP COMPLETE.
pause
