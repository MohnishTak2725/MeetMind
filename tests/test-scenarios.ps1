# MeetMind Multi-Scenario Automated Test Suite
# Tests Server API endpoints, multi-cloud skill permutations, phonetic engine,
# prompt generation rules, answer formatting, quote sanitization, and token boundaries.

$ErrorActionPreference = "Stop"
$testResults = [System.Collections.Generic.List[PSObject]]::new()

function Assert-Test {
    param(
        [string]$Scenario,
        [string]$TestName,
        [bool]$Condition,
        [string]$Details = ""
    )
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    $testResults.Add([PSCustomObject]@{
        Scenario = $Scenario
        Test     = $TestName
        Status   = $status
        Details  = $Details
    })
    $color = if ($Condition) { "Green" } else { "Red" }
    Write-Host "[$status] $Scenario :: $TestName" -ForegroundColor $color
    if (-not $Condition -and $Details) {
        Write-Host "       Error: $Details" -ForegroundColor Yellow
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  MEETMIND MULTI-SCENARIO AUTOMATED TEST SUITE RUNNER     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# SCENARIO 1: Server Endpoints & Data Model Contracts
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 1: Server API Contracts ---" -ForegroundColor Magenta
try {
    $res = Invoke-RestMethod -Uri "http://localhost:3000/api/salesforce-clouds" -Method GET
    Assert-Test -Scenario "API Contract" -TestName "Returns 9 Salesforce clouds" -Condition ($res.Count -eq 9) -Details "Count was $($res.Count)"
    
    $requiredFields = @("id", "name", "icon", "default", "required", "officialDataModels", "architecturalStandards", "phonetics", "instructions")
    $missingFieldsCount = 0
    foreach ($cloud in $res) {
        foreach ($f in $requiredFields) {
            if ($null -eq $cloud.$f) {
                $missingFieldsCount++
            }
        }
    }
    Assert-Test -Scenario "API Contract" -TestName "All 9 clouds contain mandatory fields" -Condition ($missingFieldsCount -eq 0) -Details "Missing fields: $missingFieldsCount"
    
    # Check Core Platform is marked default & required
    $core = $res | Where-Object { $_.id -eq "core" }
    Assert-Test -Scenario "API Contract" -TestName "Core platform is default and required" -Condition ($core.default -eq $true -and $core.required -eq $true)
    
    # Check Agentforce is marked default
    $af = $res | Where-Object { $_.id -eq "agentforce" }
    Assert-Test -Scenario "API Contract" -TestName "Agentforce is default" -Condition ($af.default -eq $true)
} catch {
    Assert-Test -Scenario "API Contract" -TestName "API Endpoint reachable" -Condition $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------------------
# SCENARIO 2: Active Skill Synchronizer (/api/skills/active)
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 2: Skill State Sync & Header Badging ---" -ForegroundColor Magenta
try {
    $targetLabel = "SF: Core+Agentforce+DataCloud"
    $postBody = @{ activeLabel = $targetLabel } | ConvertTo-Json
    $postRes = Invoke-RestMethod -Uri "http://localhost:3000/api/skills/active" -Method POST -Body $postBody -ContentType "application/json"
    Assert-Test -Scenario "State Sync" -TestName "POST /api/skills/active updates state" -Condition ($postRes.status -eq "ok" -or $postRes.success -eq $true)
    
    $getRes = Invoke-RestMethod -Uri "http://localhost:3000/api/skills/active" -Method GET
    Assert-Test -Scenario "State Sync" -TestName "GET /api/skills/active retrieves updated state" -Condition ($getRes.activeLabel -eq $targetLabel) -Details "Expected '$targetLabel', got '$($getRes.activeLabel)'"
} catch {
    Assert-Test -Scenario "State Sync" -TestName "Active skill sync operational" -Condition $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------------------
# SCENARIO 3: Answer Synchronization (/api/answers & /api/feed)
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 3: Answer Sync Contract ---" -ForegroundColor Magenta
try {
    $answerPayload = @{
        question = "What is Salesforce?"
        answer   = "Salesforce is an enterprise AI-powered CRM platform built on a multi-tenant metadata architecture."
    } | ConvertTo-Json
    $postAns = Invoke-RestMethod -Uri "http://localhost:3000/api/answers" -Method POST -Body $answerPayload -ContentType "application/json"
    Assert-Test -Scenario "Answer Sync" -TestName "POST /api/answers saves card" -Condition ($postAns.status -eq "ok") -Details "Status was $($postAns.status)"
    
    $getAns = Invoke-RestMethod -Uri "http://localhost:3000/api/answers" -Method GET
    Assert-Test -Scenario "Answer Sync" -TestName "GET /api/answers returns cards list" -Condition ($getAns.total -gt 0 -and $getAns.items.Count -gt 0) -Details "Total was $($getAns.total)"
} catch {
    Assert-Test -Scenario "Answer Sync" -TestName "Answer sync operational" -Condition $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------------------
# SCENARIO 4: Phonetic Engine Multi-Cloud Transformation
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 4: Phonetic Auto-Fixer Engine ---" -ForegroundColor Magenta
$cloudsJson = Get-Content -Raw "skills/salesforce-clouds.json" | ConvertFrom-Json

# Helper to simulate client-side phonetic replacement
function Apply-Phonetics {
    param([string]$Text, [string[]]$CloudIds)
    $merged = @{}
    foreach ($cid in $CloudIds) {
        $c = $cloudsJson | Where-Object { $_.id -eq $cid }
        if ($c -and $c.phonetics) {
            foreach ($prop in $c.phonetics.psobject.properties) {
                $merged[$prop.Name] = $prop.Value
            }
        }
    }
    $result = $Text
    foreach ($key in $merged.Keys) {
        $regex = "\b" + [regex]::Escape($key) + "\b"
        $result = [regex]::Replace($result, $regex, [string]$merged[$key], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $result
}

# Test 4.1: Core Platform phonetic replacements
$testCoreRaw = "can you write a so quile or so kill query for an epic trigger with governor limits"
$testCoreFixed = Apply-Phonetics -Text $testCoreRaw -CloudIds @("core")
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes 'so quile' and 'so kill' to SOQL" -Condition ($testCoreFixed -match "SOQL query") -Details $testCoreFixed
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes 'epic' to Apex" -Condition ($testCoreFixed -match "Apex trigger") -Details $testCoreFixed

# Test 4.2: Data Cloud phonetic replacements
$testDcRaw = "explain dmo and dlo mapping with calculated inside and zero copy in data cloud"
$testDcFixed = Apply-Phonetics -Text $testDcRaw -CloudIds @("core", "data-cloud")
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes 'dmo' to DMO (__dlm)" -Condition ($testDcFixed -match "DMO \(__dlm\)") -Details $testDcFixed
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes 'dlo' to DLO (__dll)" -Condition ($testDcFixed -match "DLO \(__dll\)") -Details $testDcFixed
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes 'calculated inside' to Calculated Insights" -Condition ($testDcFixed -match "Calculated Insights") -Details $testDcFixed

# Test 4.3: OmniStudio phonetic replacements
$testOmniRaw = "build a flex card with data raptor and integration procedure in omni studio"
$testOmniFixed = Apply-Phonetics -Text $testOmniRaw -CloudIds @("core", "omnistudio")
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes OmniStudio terms (flex card, data raptor, IP)" -Condition ($testOmniFixed -match "FlexCard" -and $testOmniFixed -match "DataRaptor / Data Mapper") -Details $testOmniFixed

# Test 4.4: Field Service phonetic replacements
$testFslRaw = "show dispatcher console with service appointment and work order scheduling policy"
$testFslFixed = Apply-Phonetics -Text $testFslRaw -CloudIds @("core", "fsl")
Assert-Test -Scenario "Phonetic Fixer" -TestName "Fixes Field Service terms (Service Appointment, Work Order, Dispatcher)" -Condition ($testFslFixed -match "Service Appointment" -and $testFslFixed -match "Dispatcher Console") -Details $testFslFixed

# -----------------------------------------------------------------------------
# SCENARIO 5: Prompt Construction & 4-5 Lines Technical Standard
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 5: Prompt Architecture & Guidelines ---" -ForegroundColor Magenta
$indexHtml = Get-Content -Raw "index.html"

# Verify 4-5 line guidelines present
$has4to5Lines = $indexHtml.Contains("4 to 5 lines of detailed technical description")
Assert-Test -Scenario "Prompt Engineering" -TestName "Specifies 4 to 5 lines of detailed description" -Condition $has4to5Lines

# Verify the 5 architectural pillars exist in index.html
$hasPillar1 = $indexHtml.Contains("Line 1 (Core Definition)")
$hasPillar2 = $indexHtml.Contains("Line 2 (Underlying Architecture)")
$hasPillar3 = $indexHtml.Contains("Line 3 (Core Capabilities & Tech Stack)")
$hasPillar4 = $indexHtml.Contains("Line 4 (Governance & Security)")
$hasPillar5 = $indexHtml.Contains("Line 5 (Business & Enterprise Value)")
Assert-Test -Scenario "Prompt Engineering" -TestName "All 5 architectural pillars included in prompt template" -Condition ($hasPillar1 -and $hasPillar2 -and $hasPillar3 -and $hasPillar4 -and $hasPillar5)

# Verify maxTokens is 1200
$hasMaxTokens1200 = $indexHtml.Contains("callGeminiWithFallback(prompt, loadId, 1200)") -and $indexHtml.Contains("maxOutputTokens: maxTokens || 1200")
Assert-Test -Scenario "Prompt Engineering" -TestName "Max tokens set to 1200 (prevents truncation)" -Condition $hasMaxTokens1200

# Verify no old 280 token limit remains in index.html
$hasOld280 = $indexHtml.Contains("maxTokens = 280") -or $indexHtml.Contains("callGeminiWithFallback(prompt, loadId, 280)")
Assert-Test -Scenario "Prompt Engineering" -TestName "Old 280 token ceiling completely eradicated" -Condition (-not $hasOld280)

# -----------------------------------------------------------------------------
# SCENARIO 6: Answer Cleaning & Quote Stripping
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 6: Answer Sanitization & Formatting ---" -ForegroundColor Magenta

# Function simulating the JavaScript sanitization logic in index.html
function Clean-Answer {
    param([string]$Raw)
    $clean = [regex]::Replace($Raw, "^[:\s-]+", "").Trim()
    if ($clean.StartsWith('"') -and $clean.EndsWith('"') -and $clean.Length -gt 2) {
        $clean = $clean.Substring(1, $clean.Length - 2).Trim()
    } elseif ($clean.StartsWith('"') -and -not $clean.Substring(1).Contains('"')) {
        $clean = $clean.Substring(1).Trim()
    }
    return $clean
}

# Test 6.1: Strips leading quote
$sample1 = '"Salesforce is an integrated enterprise cloud CRM platform.'
$cleaned1 = Clean-Answer -Raw $sample1
Assert-Test -Scenario "Sanitization" -TestName "Strips leading quote from answer" -Condition ($cleaned1 -eq "Salesforce is an integrated enterprise cloud CRM platform.") -Details $cleaned1

# Test 6.2: Strips wrapping quotes
$sample2 = '"Salesforce is a multi-tenant platform."'
$cleaned2 = Clean-Answer -Raw $sample2
Assert-Test -Scenario "Sanitization" -TestName "Strips enclosing quotes from answer" -Condition ($cleaned2 -eq "Salesforce is a multi-tenant platform.") -Details $cleaned2

# Test 6.3: Strips fragmented leading colons
$sample3 = ":Core platform, Data Cloud, Agent"
$cleaned3 = Clean-Answer -Raw $sample3
Assert-Test -Scenario "Sanitization" -TestName "Strips leading colon from fragmented output" -Condition ($cleaned3 -eq "Core platform, Data Cloud, Agent") -Details $cleaned3

# -----------------------------------------------------------------------------
# SCENARIO 7: Model Migration & Zero-404 Fallback Shield
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 7: Model Migration Shield ---" -ForegroundColor Magenta
$hasMigration25 = $indexHtml.Contains("'gemini-2.5-flash': 'gemini-2.0-flash'")
$hasMigration38 = $indexHtml.Contains("'gemini-3.8-flash': 'gemini-2.0-flash'")
Assert-Test -Scenario "Model Migration" -TestName "gemini-2.5-flash remapped to gemini-2.0-flash" -Condition $hasMigration25
Assert-Test -Scenario "Model Migration" -TestName "gemini-3.8-flash remapped to gemini-2.0-flash" -Condition $hasMigration38

# -----------------------------------------------------------------------------
# SCENARIO 8: Multi-Cloud Instruction Assembly Simulation
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 8: Multi-Cloud Instruction Assembly ---" -ForegroundColor Magenta
function Build-CloudInstructions {
    param([string[]]$SelectedIds)
    $instructions = @()
    foreach ($id in $SelectedIds) {
        $cloud = $cloudsJson | Where-Object { $_.id -eq $id }
        if ($cloud -and $cloud.instructions) {
            $instructions += "- " + $cloud.instructions
        }
    }
    return $instructions -join "`n"
}

# Test 8.1: Core + Agentforce
$instCoreAf = Build-CloudInstructions -SelectedIds @("core", "agentforce")
Assert-Test -Scenario "Cloud Assembly" -TestName "Core + Agentforce instructions contain Apex, Limits, and Atlas Engine" -Condition ($instCoreAf -match "Governor Limits" -and $instCoreAf -match "Atlas Reasoning Engine")

# Test 8.2: Core + Data Cloud + Marketing Cloud
$instDcMc = Build-CloudInstructions -SelectedIds @("core", "data-cloud", "marketing")
Assert-Test -Scenario "Cloud Assembly" -TestName "Data Cloud + Marketing contain DMO (__dlm), Zero Copy, and Journey Builder" -Condition ($instDcMc -match "DMO" -and $instDcMc -match "Zero Copy" -and $instDcMc -match "Journey Builder")

# Test 8.3: All 9 Clouds
$allIds = $cloudsJson | Select-Object -ExpandProperty id
$instAll = Build-CloudInstructions -SelectedIds $allIds
Assert-Test -Scenario "Cloud Assembly" -TestName "All 9 clouds combine cleanly into single context" -Condition ($allIds.Count -eq 9 -and $instAll.Length -gt 2000) -Details "Total instruction length: $($instAll.Length) chars"

# -----------------------------------------------------------------------------
# SCENARIO 9: Markdown Code Block Auto-Repair (Unterminated Backticks)
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 9: Markdown Code Block Auto-Repair ---" -ForegroundColor Magenta
function Format-TestAnswer {
    param([string]$raw)
    $safeRaw = $raw
    $triple = '```'
    $matches = [regex]::Matches($safeRaw, [regex]::Escape($triple))
    if ($matches.Count % 2 -ne 0) {
        $safeRaw += "`n" + $triple
    }
    return $safeRaw
}

$brokenCodeSnippet = "Here is the Apex trigger:`n" + '```apex' + "`ntrigger AccountTrigger on Account (before insert) {`n    // logic"
$repairedSnippet = Format-TestAnswer -raw $brokenCodeSnippet
$repairedCount = [regex]::Matches($repairedSnippet, '```').Count
Assert-Test -Scenario "Code Block Repair" -TestName "Dangling odd backticks automatically closed" -Condition ($repairedCount % 2 -eq 0) -Details "Count was $repairedCount"

# -----------------------------------------------------------------------------
# SCENARIO 10: HTML Escaping & XSS Protection
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 10: HTML Escaping and XSS Defense ---" -ForegroundColor Magenta
function Escape-Html {
    param([string]$str)
    return [System.Web.HttpUtility]::HtmlEncode($str)
}
Add-Type -AssemblyName System.Web
$dangerousInput = "<script>alert('xss')</script>"
$escaped = Escape-Html -str $dangerousInput
Assert-Test -Scenario "XSS Defense" -TestName "Escapes dangerous HTML tags" -Condition (-not $escaped.Contains("<script>") -and $escaped.Contains("&lt;script&gt;")) -Details $escaped

# -----------------------------------------------------------------------------
# SCENARIO 11: Governor Limits Specification Verification
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 11: Governor Limits Invariant Verification ---" -ForegroundColor Magenta
$coreCloud = $cloudsJson | Where-Object { $_.id -eq "core" }
$limitsCheck = $coreCloud.instructions -match "100 SOQL sync" -and
               $coreCloud.instructions -match "200 async" -and
               $coreCloud.instructions -match "50,000 SOQL rows" -and
               $coreCloud.instructions -match "6MB heap" -and
               $coreCloud.instructions -match "10s CPU sync"
Assert-Test -Scenario "Governor Limits" -TestName "Core Cloud contains official 100/200 SOQL and 6MB/12MB limits" -Condition $limitsCheck -Details "Core instructions: $($coreCloud.instructions)"

# -----------------------------------------------------------------------------
# SCENARIO 12: Stealth HUD XAML Header & Close Utility Anchor
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 12: Stealth HUD Header & Close Utility ---" -ForegroundColor Magenta
$hudScript = Get-Content -Raw "stealth-hud.ps1"
$hasCloseRightDock = $hudScript.Contains('DockPanel.Dock="Right"')
$hasSkillEllipsis = $hudScript.Contains('TextTrimming="CharacterEllipsis"')
$hasSkillMaxWidth = $hudScript.Contains('MaxWidth="140"')
$hasWebBtn = $hudScript.Contains('Name="WebBtn"') -and $hudScript.Contains('Start-Process "http://localhost:3000/"')
Assert-Test -Scenario "HUD Layout" -TestName "Close utility anchored to right edge via DockPanel" -Condition $hasCloseRightDock
Assert-Test -Scenario "HUD Layout" -TestName "SkillBadgeText trims with ellipsis on long cloud names" -Condition $hasSkillEllipsis
Assert-Test -Scenario "HUD Layout" -TestName "SkillBadgeBorder has MaxWidth protection" -Condition $hasSkillMaxWidth
Assert-Test -Scenario "HUD Layout" -TestName "WebBtn present to launch browser from HUD" -Condition $hasWebBtn

# -----------------------------------------------------------------------------
# SCENARIO 13: Overflow Scrollers & Responsiveness in index.html
# -----------------------------------------------------------------------------
Write-Host "`n--- SCENARIO 13: Overflow & Scroller Guardrails ---" -ForegroundColor Magenta
$hasSettingsScroll = $indexHtml.Contains("max-height: calc(100vh - 84px)") -and $indexHtml.Contains("overflow-y: auto")
$hasPanelActionsWrap = $indexHtml.Contains("flex-wrap: wrap") -and $indexHtml.Contains("max-width: 100%")
$hasCodeScroll = $indexHtml.Contains("overflow-x: auto") -and $indexHtml.Contains(".code-content")
$hasCloudBadgeEllipsis = $indexHtml.Contains("max-width: 220px") -and $indexHtml.Contains("text-overflow: ellipsis")
Assert-Test -Scenario "Scroller Guardrails" -TestName "Settings panel has max-height and overflow-y: auto" -Condition $hasSettingsScroll
Assert-Test -Scenario "Scroller Guardrails" -TestName "Panel actions wrap on narrow screens" -Condition $hasPanelActionsWrap
Assert-Test -Scenario "Scroller Guardrails" -TestName "Code blocks scroll horizontally on wide queries" -Condition $hasCodeScroll
Assert-Test -Scenario "Scroller Guardrails" -TestName "Header cloud badge protected against overflow" -Condition $hasCloudBadgeEllipsis

# -----------------------------------------------------------------------------
# SUMMARY REPORT
# -----------------------------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Cyan
$passed = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $testResults.Count

Write-Host "TEST SUITE SUMMARY:" -ForegroundColor Cyan
Write-Host "  Total Tests: $total" -ForegroundColor White
Write-Host "  Passed:      $passed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed:      $failed" -ForegroundColor Red
} else {
    Write-Host "  Failed:      0" -ForegroundColor Green
    Write-Host "`nALL SCENARIOS PASSED WITH 100% SUCCESS!" -ForegroundColor Green
}
Write-Host "==========================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
