' MeetMind Silent Stealth Launcher
' Launches stealth-hud.ps1 with SW_HIDE (0) so ZERO console windows or taskbar icons appear.

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
strDir = FSO.GetParentFolderName(WScript.ScriptFullName)

strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strDir & "\stealth-hud.ps1"""
WshShell.Run strCommand, 0, False
