# MeetMind Process Terminator
# Gracefully and forcefully terminates all background MeetMind HUD and server instances.

$targets = @('stealth-hud', 'server.ps1')

try {
    $processes = Get-CimInstance Win32_Process | Where-Object {
        $cmd = $_.CommandLine
        if ($cmd) {
            foreach ($t in $targets) {
                if ($cmd.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    return $true
                }
            }
        }
        return $false
    }

    foreach ($proc in $processes) {
        if ($proc.ProcessId -ne $PID) {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    # Fallback to direct process stop
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowTitle -match "MeetMind"
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}
