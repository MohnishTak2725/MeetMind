# MeetMind Local Server with Stealth Bridge API
$port = 3000
$prefix = "http://localhost:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host "MeetMind server running at $prefix"
} catch {
    Write-Host "Port $port in use, trying 3001..."
    $port = 3001
    $prefix = "http://localhost:$port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
    Write-Host "MeetMind server running at $prefix"
}

$dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# In-memory stores for Native Stealth HUD bridge
$feedItems = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
$askQueue = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $urlPath = $request.Url.LocalPath

        # API: /api/feed (GET to read feed, POST to publish items)
        if ($urlPath -eq "/api/feed") {
            $response.ContentType = "application/json; charset=utf-8"
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

            if ($request.HttpMethod -eq "OPTIONS") {
                $response.StatusCode = 200
                $response.Close()
                continue
            }

            if ($request.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                $body = $reader.ReadToEnd()
                $reader.Close()
                if ($body) {
                    [void]$feedItems.Add($body)
                    if ($feedItems.Count -gt 200) {
                        $feedItems.RemoveRange(0, 50)
                    }
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
                continue
            } else {
                # GET
                $since = 0
                if ($request.QueryString["since"]) {
                    [int]::TryParse($request.QueryString["since"], [ref]$since) | Out-Null
                }
                $list = @()
                for ($i = $since; $i -lt $feedItems.Count; $i++) {
                    $list += $feedItems[$i]
                }
                $json = '{"total":' + $feedItems.Count + ',"items":[' + ($list -join ",") + ']}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
                continue
            }
        }

        # API: /api/ask (HUD posts questions, Chrome polls and answers them)
        if ($urlPath -eq "/api/ask") {
            $response.ContentType = "application/json; charset=utf-8"
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            if ($request.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                $body = $reader.ReadToEnd()
                $reader.Close()
                if ($body) {
                    [void]$askQueue.Add($body)
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"queued"}')
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
                continue
            } else {
                # GET next question in queue
                $item = $null
                if ($askQueue.Count -gt 0) {
                    $item = $askQueue[0]
                    $askQueue.RemoveAt(0)
                }
                $json = if ($item) { $item } else { 'null' }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
                continue
            }
        }

        # API: /api/clear
        if ($urlPath -eq "/api/clear") {
            $feedItems.Clear()
            $response.ContentType = "application/json; charset=utf-8"
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"cleared"}')
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        # Static file handling
        if ($urlPath -eq "/" -or [string]::IsNullOrWhiteSpace($urlPath)) {
            $urlPath = "/index.html"
        }

        $filePath = Join-Path $dir ($urlPath.TrimStart('/'))

        if (Test-Path $filePath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            if ($filePath.EndsWith(".html")) {
                $response.ContentType = "text/html; charset=utf-8"
            } elseif ($filePath.EndsWith(".js")) {
                $response.ContentType = "application/javascript"
            } elseif ($filePath.EndsWith(".css")) {
                $response.ContentType = "text/css"
            } else {
                $response.ContentType = "application/octet-stream"
            }
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.Close()
    } catch {
        # continue loop
    }
}
