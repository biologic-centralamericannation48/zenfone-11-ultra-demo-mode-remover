@echo off
setlocal
title AI2401 ADF Rescue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0asus-demo-rescue.ps1"
echo.
pause

