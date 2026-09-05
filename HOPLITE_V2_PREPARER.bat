@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\enemy_v2\sync_hoplite_v2_package.ps1" %*
exit /b %ERRORLEVEL%
