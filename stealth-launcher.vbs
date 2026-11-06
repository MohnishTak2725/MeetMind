' MeetMind Silent Stealth Launcher
' 1. Starts server silently in background if needed
' 2. Opens index.html in default browser (http://localhost:3000/)
' 3. Launches Stealth HUD popup (stealth-hud.ps1) with SW_HIDE (0)

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
strDir = FSO.GetParentFolderName(WScript.ScriptFullName)

' 1. Start Server in background if not already listening
strServerCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""if (-not (Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue)) { Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """"" & strDir & "\server.ps1""""' -WindowStyle Hidden }"""
WshShell.Run strServerCmd, 0, True

' 2. Open browser to http://localhost:3000/
WshShell.Run "cmd.exe /c start http://localhost:3000/", 0, False

' 3. Launch Stealth HUD
strHudCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strDir & "\stealth-hud.ps1"""
WshShell.Run strHudCmd, 0, False
