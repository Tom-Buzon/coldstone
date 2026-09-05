@echo off
chcp 65001 > nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\animation_workbench\run_pipeline.ps1" -Action Publish
if errorlevel 1 (
  echo.
  echo PUBLICATION ANNULEE - les anciennes correspondances du jeu sont conservees.
  pause
  exit /b 1
)
echo.
echo Mise a jour publiee dans le jeu.
