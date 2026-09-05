@echo off
chcp 65001 > nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\animation_workbench\run_pipeline.ps1" -Action OpenBlender
if errorlevel 1 (
  echo.
  echo ECHEC - consultez le message ci-dessus.
  pause
  exit /b 1
)
