# MeetMind Native WPF Stealth HUD
# Creates a native Windows window with WDA_EXCLUDEFROMCAPTURE (0x00000011) and HWND_TOPMOST.
# Because this process owns the window, Windows allows display affinity without ERROR_ACCESS_DENIED.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

$csharp = @"
using System;
using System.Runtime.InteropServices;

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("a5cd92ff-29be-454c-8d04-d82879fb3f1b")]
public interface IVirtualDesktopManager {
    int IsWindowOnCurrentVirtualDesktop(IntPtr topLevelWindow, out int onCurrentDesktop);
    int GetWindowDesktopId(IntPtr topLevelWindow, out Guid desktopId);
    int MoveWindowToDesktop(IntPtr topLevelWindow, [MarshalAs(UnmanagedType.LPStruct)] Guid desktopId);
}

[ComImport, Guid("aa509086-5ca9-4c25-8f95-589d3c07b48a")]
public class CVirtualDesktopManager {}

public class NativeAffinity {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowDisplayAffinity(IntPtr hWnd, uint dwAffinity);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOACTIVATE = 0x0010;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);

    public static bool ApplyStealth(IntPtr hWnd) {
        bool ok = SetWindowDisplayAffinity(hWnd, 0x00000011);
        if (!ok) {
            ok = SetWindowDisplayAffinity(hWnd, 0x00000001);
        }
        SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
        return ok;
    }

    public static Guid? GetCurrentDesktopGuid() {
        try {
            using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops")) {
                if (key != null) {
                    byte[] bytes = (byte[])key.GetValue("CurrentVirtualDesktop");
                    if (bytes != null && bytes.Length == 16) {
                        return new Guid(bytes);
                    }
                }
            }
        } catch {}
        return null;
    }

    public static void SyncToCurrentDesktop(IntPtr hWnd) {
        try {
            Guid? cur = GetCurrentDesktopGuid();
            if (cur.HasValue) {
                var mgr = (IVirtualDesktopManager)new CVirtualDesktopManager();
                int onCurrent = 0;
                mgr.IsWindowOnCurrentVirtualDesktop(hWnd, out onCurrent);
                if (onCurrent == 0) {
                    mgr.MoveWindowToDesktop(hWnd, cur.Value);
                }
            }
        } catch {}
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'NativeAffinity').Type) {
    Add-Type -TypeDefinition $csharp
}

$port = 3000
$url = "http://localhost:$port/"
$serverScript = Join-Path $PSScriptRoot "server.ps1"

try {
    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
} catch {
    Write-Host "[*] Starting MeetMind local server..." -ForegroundColor Cyan
    if (Test-Path $serverScript) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$serverScript`"" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 1
}

# Ensure Chrome or Edge is open to capture microphone audio
$existing = Get-Process chrome, msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match 'MeetMind' }
if (-not $existing) {
    Start-Process $url
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MeetMind Stealth HUD"
        Height="620" Width="440"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        WindowStartupLocation="Manual"
        Left="80" Top="120">

    <Border Background="#F20A0D16" CornerRadius="12" BorderBrush="#556378FF" BorderThickness="1.5">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="46"/>
                <RowDefinition Height="36"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="50"/>
            </Grid.RowDefinitions>

            <!-- Header / Drag Bar -->
            <Border Grid.Row="0" Name="HeaderBar" Background="#EE101524" CornerRadius="12,12,0,0" Cursor="Hand" BorderBrush="#22FFFFFF" BorderThickness="0,0,0,1">
                <Grid Margin="12,0,10,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="MeetMind HUD" Foreground="#FFFFFF" FontWeight="Bold" FontSize="13" VerticalAlignment="Center"/>
                        <Border Background="#2010B981" CornerRadius="10" Padding="6,2" Margin="8,0,0,0" BorderBrush="#4010B981" BorderThickness="1" VerticalAlignment="Center">
                            <TextBlock Text="[Shielded - Invisible]" Foreground="#34D399" FontSize="10" FontWeight="SemiBold"/>
                        </Border>
                    </StackPanel>

                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <ComboBox Name="OpacityCombo" Width="68" Height="24" FontSize="11" Background="#20FFFFFF" Foreground="#FFFFFF" Margin="0,0,6,0" VerticalContentAlignment="Center">
                            <ComboBoxItem Content="100%" />
                            <ComboBoxItem Content="85%" IsSelected="True"/>
                            <ComboBoxItem Content="70%"/>
                            <ComboBoxItem Content="50%"/>
                        </ComboBox>
                        <Button Name="FontBtn" Content="A+" Width="26" Height="24" Background="#20FFFFFF" Foreground="#CBD5E1" BorderThickness="0" Margin="0,0,4,0" Cursor="Hand" FontWeight="Bold" FontSize="11"/>
                        <Button Name="CloseBtn" Content="X" Width="26" Height="24" Background="#30EF4444" Foreground="#FCA5A5" BorderThickness="0" Cursor="Hand" FontWeight="Bold" FontSize="12"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- Navigation Tabs -->
            <Border Grid.Row="1" Background="#0C0F1D" BorderBrush="#15FFFFFF" BorderThickness="0,0,0,1">
                <Grid Margin="8,4">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Button Name="TabAnswers" Grid.Column="0" Content="AI Answers" Background="#256378FF" Foreground="#93C5FD" BorderBrush="#406378FF" BorderThickness="1" Margin="2,0" FontWeight="SemiBold" FontSize="11" Cursor="Hand"/>
                    <Button Name="TabTranscript" Grid.Column="1" Content="Live Transcript" Background="Transparent" Foreground="#64748B" BorderThickness="0" Margin="2,0" FontWeight="SemiBold" FontSize="11" Cursor="Hand"/>
                </Grid>
            </Border>

            <!-- Content Area -->
            <Grid Grid.Row="2" Margin="10,8">
                <!-- Answers ScrollViewer -->
                <ScrollViewer Name="AnswersScroll" VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="AnswersContainer">
                        <Border Background="#121829" CornerRadius="8" Padding="14" Margin="0,0,0,8" BorderBrush="#206378FF" BorderThickness="1">
                            <StackPanel>
                                <TextBlock Text="Stealth HUD Ready" Foreground="#60A5FA" FontWeight="Bold" FontSize="12" Margin="0,0,0,4"/>
                                <TextBlock Text="Answers generated in Chrome will appear here in real time. This HUD is 100% invisible on screen shares and screenshots!" Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>

                <!-- Transcript ScrollViewer -->
                <ScrollViewer Name="TranscriptScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
                    <StackPanel Name="TranscriptContainer">
                        <TextBlock Text="Waiting for speech from Chrome microphone..." Foreground="#64748B" FontSize="11" Margin="6" FontStyle="Italic"/>
                    </StackPanel>
                </ScrollViewer>
            </Grid>

            <!-- Footer: Quick Ask Gemini -->
            <Border Grid.Row="3" Background="#111626" CornerRadius="0,0,12,12" BorderBrush="#20FFFFFF" BorderThickness="0,1,0,0">
                <Grid Margin="10,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="65"/>
                    </Grid.ColumnDefinitions>
                    <TextBox Name="AskInput" Grid.Column="0" Background="#0C101D" Foreground="#FFFFFF" BorderBrush="#356378FF" BorderThickness="1" Padding="8,4" FontSize="12" VerticalContentAlignment="Center" Margin="0,0,6,0"/>
                    <Button Name="AskBtn" Grid.Column="1" Content="Ask" Background="#6378FF" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" BorderThickness="0" Cursor="Hand"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$win = [System.Windows.Markup.XamlReader]::Load($reader)

# Apply SetWindowDisplayAffinity when window handle is ready
$win.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($win)
    $script:hudHwnd = $helper.Handle
    $applied = [NativeAffinity]::ApplyStealth($helper.Handle)
    [NativeAffinity]::SyncToCurrentDesktop($helper.Handle)
    Write-Host "[*] Native HUD HWND: 0x$($helper.Handle.ToString('X')) | Shielded: $applied" -ForegroundColor Green
})

# Element hooks
$header = $win.FindName("HeaderBar")
$opacityCombo = $win.FindName("OpacityCombo")
$fontBtn = $win.FindName("FontBtn")
$closeBtn = $win.FindName("CloseBtn")
$tabAnswers = $win.FindName("TabAnswers")
$tabTranscript = $win.FindName("TabTranscript")
$answersScroll = $win.FindName("AnswersScroll")
$transcriptScroll = $win.FindName("TranscriptScroll")
$answersContainer = $win.FindName("AnswersContainer")
$transcriptContainer = $win.FindName("TranscriptContainer")
$askInput = $win.FindName("AskInput")
$askBtn = $win.FindName("AskBtn")

# Drag move
$header.Add_MouseDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $win.DragMove()
    }
})

# Close & Key shortcuts
$closeBtn.Add_Click({ $win.Close() })

$win.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
        $win.Close()
    }
})

$win.Add_Closed({
    try {
        Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'server.ps1' } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    [System.Windows.Application]::Current.Shutdown()
    Stop-Process -Id $PID -Force
})

# Opacity
$opacityCombo.Add_SelectionChanged({
    $val = $opacityCombo.SelectedItem.Content
    switch ($val) {
        "100%" { $win.Opacity = 1.0 }
        "85%"  { $win.Opacity = 0.85 }
        "70%"  { $win.Opacity = 0.70 }
        "50%"  { $win.Opacity = 0.50 }
    }
})
$win.Opacity = 0.85

# Font toggle
$isBigFont = $false
$fontBtn.Add_Click({
    $script:isBigFont = -not $script:isBigFont
    $newSize = if ($script:isBigFont) { 13.5 } else { 11.5 }
    $answersContainer.SetValue([System.Windows.Controls.TextBlock]::FontSizeProperty, $newSize)
    $transcriptContainer.SetValue([System.Windows.Controls.TextBlock]::FontSizeProperty, $newSize)
})

# Tab switching
$tabAnswers.Add_Click({
    $answersScroll.Visibility = [System.Windows.Visibility]::Visible
    $transcriptScroll.Visibility = [System.Windows.Visibility]::Collapsed
    $tabAnswers.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#256378FF")
    $tabAnswers.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#93C5FD")
    $tabTranscript.Background = [System.Windows.Media.Brushes]::Transparent
    $tabTranscript.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
})

$tabTranscript.Add_Click({
    $answersScroll.Visibility = [System.Windows.Visibility]::Collapsed
    $transcriptScroll.Visibility = [System.Windows.Visibility]::Visible
    $tabTranscript.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#256378FF")
    $tabTranscript.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#93C5FD")
    $tabAnswers.Background = [System.Windows.Media.Brushes]::Transparent
    $tabAnswers.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
})

# Quick ask action
$doAsk = {
    $q = $askInput.Text.Trim()
    if ($q) {
        $askInput.Text = ""
        $tabAnswers.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        try {
            $json = @{ question = $q } | ConvertTo-Json -Compress
            $null = Invoke-RestMethod -Uri "http://localhost:3000/api/ask" -Method POST -Body $json -ContentType "application/json" -TimeoutSec 2
        } catch {}
    }
}
$askBtn.Add_Click($doAsk)
$askInput.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Enter) {
        & $doAsk
    }
})

# Live Feed Polling Timer
$seenCount = 0
$feedTimer = New-Object System.Windows.Threading.DispatcherTimer
$feedTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$feedTimer.Add_Tick({
    try {
        if ($script:hudHwnd -and $script:hudHwnd -ne [IntPtr]::Zero) {
            [NativeAffinity]::SyncToCurrentDesktop($script:hudHwnd)
        }
    } catch {}

    try {
        $res = Invoke-RestMethod -Uri "http://localhost:3000/api/feed?since=$script:seenCount" -Method GET -TimeoutSec 1 -ErrorAction Stop
        if ($res.items -and $res.items.Count -gt 0) {
            foreach ($raw in $res.items) {
                $script:seenCount++
                $item = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }

                if ($item.type -eq "answer") {
                    $card = New-Object System.Windows.Controls.Border
                    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#151B2E")
                    $card.CornerRadius = New-Object System.Windows.CornerRadius(8)
                    $card.Padding = New-Object System.Windows.Thickness(12)
                    $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
                    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#306378FF")
                    $card.BorderThickness = New-Object System.Windows.Thickness(1)

                    $panel = New-Object System.Windows.Controls.StackPanel

                    # Question header
                    $qText = New-Object System.Windows.Controls.TextBlock
                    $qText.Text = "Q: " + $item.question
                    $qText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
                    $qText.FontWeight = [System.Windows.FontWeights]::Bold
                    $qText.FontSize = 12
                    $qText.TextWrapping = [System.Windows.TextWrapping]::Wrap
                    $qText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
                    [void]$panel.Children.Add($qText)

                    # Answer body
                    $ansBox = New-Object System.Windows.Controls.TextBox
                    $ansBox.Text = $item.answer
                    $ansBox.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E2E8F0")
                    $ansBox.Background = [System.Windows.Media.Brushes]::Transparent
                    $ansBox.BorderThickness = New-Object System.Windows.Thickness(0)
                    $ansBox.IsReadOnly = $true
                    $ansBox.TextWrapping = [System.Windows.TextWrapping]::Wrap
                    $ansBox.FontSize = 11.5
                    $ansBox.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
                    [void]$panel.Children.Add($ansBox)

                    # Footer with copy button
                    $footGrid = New-Object System.Windows.Controls.Grid
                    $col1 = New-Object System.Windows.Controls.ColumnDefinition
                    $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                    $col2 = New-Object System.Windows.Controls.ColumnDefinition
                    $col2.Width = [System.Windows.GridLength]::Auto
                    [void]$footGrid.ColumnDefinitions.Add($col1)
                    [void]$footGrid.ColumnDefinitions.Add($col2)

                    $timeText = New-Object System.Windows.Controls.TextBlock
                    $timeText.Text = if ($item.time) { $item.time } else { [DateTime]::Now.ToString("HH:mm:ss") }
                    $timeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
                    $timeText.FontSize = 10
                    $timeText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    [System.Windows.Controls.Grid]::SetColumn($timeText, 0)
                    [void]$footGrid.Children.Add($timeText)

                    $copyBtn = New-Object System.Windows.Controls.Button
                    $copyBtn.Content = "Copy"
                    $copyBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#20FFFFFF")
                    $copyBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBD5E1")
                    $copyBtn.FontSize = 10
                    $copyBtn.Padding = New-Object System.Windows.Thickness(8, 2, 8, 2)
                    $copyBtn.BorderThickness = New-Object System.Windows.Thickness(0)
                    $copyBtn.Cursor = [System.Windows.Input.Cursors]::Hand
                    $btnRef = $copyBtn
                    $copyBtn.Add_Click({
                        try {
                            [System.Windows.Clipboard]::SetText($ansCopy)
                            $btnRef.Content = "Copied!"
                        } catch {}
                    })
                    [System.Windows.Controls.Grid]::SetColumn($copyBtn, 1)
                    [void]$footGrid.Children.Add($copyBtn)

                    [void]$panel.Children.Add($footGrid)
                    $card.Child = $panel

                    [void]$answersContainer.Children.Add($card)
                    $answersScroll.ScrollToBottom()
                } elseif ($item.type -eq "transcript") {
                    $tBlock = New-Object System.Windows.Controls.TextBlock
                    $tBlock.Text = "- " + $item.text
                    $tBlock.Foreground = if ($item.isQuestion) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#93C5FD") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8") }
                    $tBlock.FontSize = 11.5
                    $tBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
                    $tBlock.Margin = New-Object System.Windows.Thickness(4, 2, 4, 4)
                    [void]$transcriptContainer.Children.Add($tBlock)
                    $transcriptScroll.ScrollToBottom()
                }
            }
        }
    } catch {}
})
$feedTimer.Start()

$helper = New-Object System.Windows.Interop.WindowInteropHelper($win)
$helper.EnsureHandle() | Out-Null
$script:hudHwnd = $helper.Handle
[NativeAffinity]::ApplyStealth($helper.Handle) | Out-Null
[NativeAffinity]::SyncToCurrentDesktop($helper.Handle)

$app = New-Object System.Windows.Application
$app.Run($win)
