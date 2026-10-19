@echo off
cd /d "%~dp0"
start "" wscript.exe "%~dp0stop-silent.vbs"
exit
