# MeetMind Exhaustive Clickable & Interactive Control Audit

$indexHtml = Get-Content -Raw "index.html"
$hudPs1 = Get-Content -Raw "stealth-hud.ps1"
$serverPs1 = Get-Content -Raw "server.ps1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    MEETMIND EXHAUSTIVE CLICKABLE CONTROLS AUDIT          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Extract all onclick attributes from index.html
$onclickRegex = [regex]'onclick\s*=\s*"([^"]+)"'
$onclickMatches = $onclickRegex.Matches($indexHtml)
$onclickHandlers = @()
foreach ($m in $onclickMatches) {
    $onclickHandlers += $m.Groups[1].Value
}
$uniqueOnclicks = $onclickHandlers | Sort-Object -Unique

Write-Host "`n1. Onclick Handlers in index.html ($($uniqueOnclicks.Count) unique):" -ForegroundColor Yellow
$missingFunctions = @()
foreach ($handler in $uniqueOnclicks) {
    # Extract function name before parenthesis or semicolon
    if ($handler -match '^([a-zA-Z0-9_$]+)\s*\(') {
        $fnName = $Matches[1]
        $defPattern = "function\s+$fnName\s*\("
        if (-not ($indexHtml -match $defPattern)) {
            Write-Host "  [MISSING FUNCTION!] onclick: $handler -> function $fnName not found!" -ForegroundColor Red
            $missingFunctions += $fnName
        } else {
            Write-Host "  [OK] $handler -> function $fnName defined" -ForegroundColor Green
        }
    } elseif ($handler -match 'document\.getElementById') {
        # Inline DOM click
        Write-Host "  [OK Inline DOM] $handler" -ForegroundColor Green
    } else {
        Write-Host "  [Custom Expression] $handler" -ForegroundColor Cyan
    }
}

# 2. Extract all addEventListener('click', ...) in index.html
Write-Host "`n2. addEventListener('click', ...) in index.html:" -ForegroundColor Yellow
$listenerRegex = [regex]'(?:document\.getElementById\(''([^'']+)''\)|doc\.getElementById\(''([^'']+)''\)|([a-zA-Z0-9_$]+))\.(?:addEventListener\(''click''|onclick)'
$listenerMatches = $listenerRegex.Matches($indexHtml)
Write-Host "Found $($listenerMatches.Count) addEventListener click bindings." -ForegroundColor Gray
foreach ($m in $listenerMatches) {
    Write-Host "  Binding: $($m.Value)" -ForegroundColor Green
}

# 3. Check all buttons in index.html
Write-Host "`n3. All <button> elements in index.html:" -ForegroundColor Yellow
$btnRegex = [regex]'<button\b([^>]*)>(.*?)</button>'
$btnMatches = $btnRegex.Matches($indexHtml)
Write-Host "Total <button> tags: $($btnMatches.Count)" -ForegroundColor Gray
$unwiredButtons = 0
foreach ($b in $btnMatches) {
    $attrs = $b.Groups[1].Value
    $inner = $b.Groups[2].Value.Trim()
    $hasOnclick = $attrs -match 'onclick'
    $hasId = $attrs -match 'id="([^"]+)"'
    $id = if ($hasId) { $Matches[1] } else { "" }
    
    # Check if wired via addEventListener
    $hasListener = $false
    if ($id) {
        $hasListener = ($indexHtml -match "getElementById\(['`"]$id['`"]\)\.addEventListener\(['`"]click['`"]") -or
                       ($indexHtml -match "getElementById\(['`"]$id['`"]\)\.onclick")
    }
    
    if (-not $hasOnclick -and -not $hasListener) {
        Write-Host "  [POTENTIALLY UNWIRED BUTTON] ID: '$id' Content: '$inner' Attrs: $attrs" -ForegroundColor Red
        $unwiredButtons++
    } else {
        $wireType = if ($hasOnclick) { "onclick" } else { "listener (#$id)" }
        Write-Host "  [WIRED - $wireType] ID: '$id' Text: '$inner'" -ForegroundColor Green
    }
}

# 4. Check all <select>, <input>, and toggles in index.html
Write-Host "`n4. Form Inputs, Selects & Toggles in index.html:" -ForegroundColor Yellow
$inputs = [regex]::Matches($indexHtml, '<(input|select|textarea)\b([^>]*)>')
Write-Host "Total Form Controls: $($inputs.Count)" -ForegroundColor Gray
foreach ($inp in $inputs) {
    $tag = $inp.Groups[1].Value
    $attrs = $inp.Groups[2].Value
    $idMatch = [regex]::Match($attrs, 'id="([^"]+)"')
    $id = if ($idMatch.Success) { $idMatch.Groups[1].Value } else { "(no-id)" }
    $typeMatch = [regex]::Match($attrs, 'type="([^"]+)"')
    $type = if ($typeMatch.Success) { $typeMatch.Groups[1].Value } else { $tag }
    Write-Host "  Control: <$tag> ID: #$id (type: $type)" -ForegroundColor Gray
}

# 5. Check all Stealth HUD elements and event bindings in stealth-hud.ps1
Write-Host "`n5. Stealth HUD (WPF) Clickable Elements in stealth-hud.ps1:" -ForegroundColor Yellow
$xamlBtns = [regex]::Matches($hudPs1, '<Button\s+Name="([^"]+)"\s+Content="([^"]+)"')
Write-Host "Total XAML Buttons in HUD: $($xamlBtns.Count)" -ForegroundColor Gray
$unwiredHudBtns = 0
foreach ($xb in $xamlBtns) {
    $name = $xb.Groups[1].Value
    $content = $xb.Groups[2].Value
    $wired = $hudPs1 -match "\$$([a-z0-9_]*$name[a-z0-9_]*)\.Add_Click" -or 
             $hudPs1 -match "\$$name\.Add_Click" -or
             $hudPs1 -match "FindName\(['`"]$name['`"]\)"
    if ($wired) {
        Write-Host "  [WIRED HUD BUTTON] Name: $name (Content: '$content')" -ForegroundColor Green
    } else {
        Write-Host "  [UNWIRED HUD BUTTON] Name: $name (Content: '$content')" -ForegroundColor Red
        $unwiredHudBtns++
    }
}

# 6. Check all ComboBox & KeyDown handlers in stealth-hud.ps1
$hasOpacitySelect = $hudPs1.Contains('$opacityCombo.Add_SelectionChanged')
$hasFontBtnClick = $hudPs1.Contains('$fontBtn.Add_Click')
$hasClearBtnClick = $hudPs1.Contains('$clearBtn.Add_Click')
$hasCloseBtnClick = $hudPs1.Contains('$closeBtn.Add_Click')
$hasWebBtnClick = $hudPs1.Contains('$webBtn.Add_Click')
$hasTabAnswers = $hudPs1.Contains('$tabAnswers.Add_Click')
$hasTabTranscript = $hudPs1.Contains('$tabTranscript.Add_Click')
$hasAskBtn = $hudPs1.Contains('$askBtn.Add_Click')
$hasEscKey = $hudPs1.Contains('Key -eq [System.Windows.Input.Key]::Escape')
$hasEnterKey = $hudPs1.Contains('Key -eq [System.Windows.Input.Key]::Enter')

Write-Host "  HUD Opacity Selector Wired: $hasOpacitySelect" -ForegroundColor Green
Write-Host "  HUD Font Button Wired:      $hasFontBtnClick" -ForegroundColor Green
Write-Host "  HUD Clear Button Wired:     $hasClearBtnClick" -ForegroundColor Green
Write-Host "  HUD Close Button Wired:     $hasCloseBtnClick" -ForegroundColor Green
Write-Host "  HUD Web Browser Btn Wired:  $hasWebBtnClick" -ForegroundColor Green
Write-Host "  HUD Tab Answers Wired:      $hasTabAnswers" -ForegroundColor Green
Write-Host "  HUD Tab Transcript Wired:   $hasTabTranscript" -ForegroundColor Green
Write-Host "  HUD Ask Button Wired:       $hasAskBtn" -ForegroundColor Green
Write-Host "  HUD Escape Key Wired:       $hasEscKey" -ForegroundColor Green
Write-Host "  HUD Enter Key in Ask Wired: $hasEnterKey" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "AUDIT SUMMARY:" -ForegroundColor Cyan
Write-Host "  Missing Functions in HTML: $($missingFunctions.Count)" -ForegroundColor $(if ($missingFunctions.Count -eq 0) { "Green" } else { "Red" })
Write-Host "  Unwired HTML Buttons:      $unwiredButtons" -ForegroundColor $(if ($unwiredButtons -eq 0) { "Green" } else { "Red" })
Write-Host "  Unwired HUD Buttons:       $unwiredHudBtns" -ForegroundColor $(if ($unwiredHudBtns -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan
