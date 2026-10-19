' MeetMind Silent Stop Launcher
' Runs stop.ps1 in the background with SW_HIDE (0) so ZERO console windows appear.

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
strDir = FSO.GetParentFolderName(WScript.ScriptFullName)

strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strDir & "\stop.ps1"""
WshShell.Run strCommand, 0, True
