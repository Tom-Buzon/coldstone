@echo off
cd /d "%~dp0"
echo ==============================================================
echo  PROJECT HOPLITE - VERIFY UAL NATIVE LAB V2
echo ==============================================================
if exist "assets\runtime\ual1\UAL1_Standard.glb" (echo [OK] UAL1 visible mannequin) else (echo [MISSING] UAL1)
if exist "assets\runtime\ual2\UAL2_Standard.glb" (echo [OK] UAL2 authored combat) else (echo [MISSING] UAL2)
echo.
echo Godot should only import these two runtime GLBs.
echo.
pause
