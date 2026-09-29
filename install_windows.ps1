# ==============================================================================
# ColorSync / Color Management Helper Installer for Windows
# Isolated Firefox profile builder, hardened preferences, and decoy WinForms launcher.
# ==============================================================================

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# Path configuration
$ProfileDir = "$env:LOCALAPPDATA\.font-renderer-data"
$DownloadsDir = "$ProfileDir\Downloads"
$TargetDir = "$env:APPDATA\ColorManagementHelper"
$LauncherPs1 = "$TargetDir\launcher.ps1"
$LauncherVbs = "$TargetDir\ColorManagementHelper.vbs"
$DesktopShortcut = "$env:USERPROFILE\Desktop\Color Management Utility.lnk"
$StartMenuShortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Color Management Utility.lnk"
$TargetUrl = "https://www.instagram.com"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   Setting up Color Management Helper for Windows... " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Locate or install Firefox
$FirefoxBin = $null
$StandardPaths = @(
    "C:\Program Files\Mozilla Firefox\firefox.exe",
    "C:\Program Files (x86)\Mozilla Firefox\firefox.exe",
    "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe"
)

foreach ($path in $StandardPaths) {
    if (Test-Path $path) {
        $FirefoxBin = $path
        break
    }
}

if (-not $FirefoxBin) {
    Write-Host "[1/5] Firefox not found. Downloading official installer from Mozilla..." -ForegroundColor Yellow
    $InstallerPath = "$env:TEMP\FirefoxSetup_$([guid]::NewGuid().ToString('N')).exe"
    
    $DownloadUrl = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    
    # Download with WebClient
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DownloadUrl, $InstallerPath)
    
    Write-Host "[+] Installing Firefox silently..." -ForegroundColor Yellow
    Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
    
    foreach ($path in $StandardPaths) {
        if (Test-Path $path) {
            $FirefoxBin = $path
            break
        }
    }
    
    if (-not $FirefoxBin) {
        Write-Host "[!] Error: Failed to locate Firefox after silent installation." -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Firefox installed successfully at $FirefoxBin." -ForegroundColor Green
} else {
    Write-Host "[1/5] Firefox runtime verified at $FirefoxBin." -ForegroundColor Green
}

# 2. Create isolated storage directory & private downloads
Write-Host "[2/5] Initializing isolated profile storage..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

# 3. Inject hardened browser preferences (user.js)
Write-Host "[3/5] Configuring stealth profile preferences..." -ForegroundColor Yellow
$EscapedDownloadsDir = $DownloadsDir.Replace("\", "\\")
$UserJsContent = @"
user_pref("dom.webnotifications.enabled", false);
user_pref("permissions.default.desktop-notification", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "$EscapedDownloadsDir");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "$TargetUrl");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("signon.rememberSignons", true);
"@

Set-Content -Path "$ProfileDir\user.js" -Value $UserJsContent -Encoding UTF8

# 4. Create WinForms Decoy GUI Launcher
Write-Host "[4/5] Building native WinForms decoy launcher..." -ForegroundColor Yellow

$LauncherContent = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

`$ProfileDir = "$ProfileDir"
`$TargetUrl = "$TargetUrl"
`$FirefoxBin = "$FirefoxBin"

`$form = New-Object System.Windows.Forms.Form
`$form.Text = "Color Management"
`$form.Size = New-Object System.Drawing.Size(420, 180)
`$form.StartPosition = "CenterScreen"
`$form.FormBorderStyle = "FixedDialog"
`$form.MaximizeBox = `$false
`$form.MinimizeBox = `$false
`$form.TopMost = `$true

`$lblTitle = New-Object System.Windows.Forms.Label
`$lblTitle.Location = New-Object System.Drawing.Point(20, 20)
`$lblTitle.Size = New-Object System.Drawing.Size(360, 20)
`$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
`$lblTitle.Text = "Display Profile: Generic PnP Monitor (Calibrated)"
`$form.Controls.Add(`$lblTitle)

`$lblSub = New-Object System.Windows.Forms.Label
`$lblSub.Location = New-Object System.Drawing.Point(20, 12)
`$lblSub.Size = New-Object System.Drawing.Size(360, 20)
`$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
`$lblSub.ForeColor = [System.Drawing.Color]::Gray
`$lblSub.Text = "All Windows color management profiles are up to date."
`$form.Controls.Add(`$lblSub)

`$btnUpdate = New-Object System.Windows.Forms.Button
`$btnUpdate.Location = New-Object System.Drawing.Point(20, 85)
`$btnUpdate.Size = New-Object System.Drawing.Size(140, 32)
`$btnUpdate.Text = "Check for Updates"
`$btnUpdate.Font = New-Object System.Drawing.Font("Segoe UI", 9)
`$btnUpdate.Add_Click({
    `$modifiers = [System.Windows.Forms.Control]::ModifierKeys
    `$isShift = (`$modifiers -band [System.Windows.Forms.Keys]::Shift) -ne 0
    `$isAlt = (`$modifiers -band [System.Windows.Forms.Keys]::Alt) -ne 0
    
    if (`$isShift -or `$isAlt) {
        # Secret Trigger: Launch isolated Firefox instance
        `$form.Close()
        Start-Process -FilePath `$FirefoxBin -ArgumentList @("--profile", "`$ProfileDir", "--no-remote", "`$TargetUrl")
        [System.Environment]::Exit(0)
    } else {
        # Decoy Trigger: Fake Windows Update check
        [System.Windows.Forms.MessageBox]::Show(
            "Checking Windows Color Management update catalog...`n`nNo newer profile versions available for this display.",
            "Color Management",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        `$form.Close()
        [System.Environment]::Exit(0)
    }
})
`$form.Controls.Add(`$btnUpdate)

`$btnOk = New-Object System.Windows.Forms.Button
`$btnOk.Location = New-Object System.Drawing.Point(280, 85)
`$btnOk.Size = New-Object System.Drawing.Size(100, 32)
`$btnOk.Text = "OK"
`$btnOk.Font = New-Object System.Drawing.Font("Segoe UI", 9)
`$btnOk.Add_Click({
    `$form.Close()
    [System.Environment]::Exit(0)
})
`$form.Controls.Add(`$btnOk)

[System.Windows.Forms.Application]::Run(`$form)
"@

Set-Content -Path $LauncherPs1 -Value $LauncherContent -Encoding UTF8

# Create silent VBS wrapper to run PowerShell windowless
$VbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""$LauncherPs1""", 0, False
"@
Set-Content -Path $LauncherVbs -Value $VbsContent -Encoding ASCII

# 5. Create Desktop & Start Menu Shortcuts with native system icon
Write-Host "[5/5] Creating Windows Start Menu & Desktop shortcuts..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell

$Shortcut = $WshShell.CreateShortcut($StartMenuShortcut)
$Shortcut.TargetPath = "wscript.exe"
$Shortcut.Arguments = "`"$LauncherVbs`""
$Shortcut.IconLocation = "$env:SystemRoot\System32\colorcpl.exe,0"
$Shortcut.Description = "Color Management and Display Calibration Utility"
$Shortcut.Save()

# Also save to Desktop
$DeskShortcut = $WshShell.CreateShortcut($DesktopShortcut)
$DeskShortcut.TargetPath = "wscript.exe"
$DeskShortcut.Arguments = "`"$LauncherVbs`""
$DeskShortcut.IconLocation = "$env:SystemRoot\System32\colorcpl.exe,0"
$DeskShortcut.Description = "Color Management and Display Calibration Utility"
$DeskShortcut.Save()

Write-Host "=====================================================" -ForegroundColor Green
Write-Host "   Setup Successfully Verified & Ready on Windows!   " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "How to Use on Windows:"
Write-Host "1. Double-click 'Color Management Utility' on Desktop or Start Menu."
Write-Host "2. Hold 'Shift' (or 'Alt') and click 'Check for Updates'."
Write-Host "3. It opens directly to your private Instagram session."
Write-Host "4. Press Ctrl + Q (or close the browser) when done."
Write-Host ""
Write-Host "Innocent Decoy Behavior:"
Write-Host "- Clicking 'OK' closes the window cleanly."
Write-Host "- Normal click on 'Check for Updates' shows innocent 'up to date' alert."
Write-Host "=====================================================" -ForegroundColor Green
