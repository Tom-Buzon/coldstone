@echo off
setlocal
cd /d "%~dp0"
echo PROJECT HOPLITE - CC0 AUDIO SETUP
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\FETCH_CC0_SFX.ps1"
if errorlevel 1 (
  echo.
  echo Audio download failed. The bundled fallback SFX are still usable.
  pause
  exit /b 1
)
echo.
echo Audio setup complete.
pause
