@echo off
title MeetMind Server
cd /d "%~dp0"
echo ===================================================
echo   MeetMind - AI Meeting and Interview Assistant
echo   Running at http://localhost:3000/
echo ===================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
