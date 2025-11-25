# ==================================================
# Localhost Manager - Initial Setup for Windows
# First-time configuration wizard
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [switch]$Silent,

    [Parameter(Mandatory=$false)]
    [string]$Stack = ""
)

$ErrorActionPreference = "Stop"

# ASCII Banner
$Banner = @"

  _                    _ _               _
 | |    ___   ___ __ _| | |__   ___  ___| |_
 | |   / _ \ / __/ _` | | '_ \ / _ \/ __| __|
 | |__| (_) | (_| (_| | | | | | (_) \__ \ |_
 |_____\___/ \___\__,_|_|_| |_|\___/|___/\__|

         __  __
        |  \/  | __ _ _ __   __ _  __ _  ___ _ __
        | |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '__|
        | |  | | (_| | | | | (_| | (_| |  __/ |
        |_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|
                                 |___/

"@

Write-Host $Banner -ForegroundColor Cyan
Write-Host "         Windows Setup Wizard v1.0" -ForegroundColor Yellow
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$CertDir = "$ManagerDir\certs"
$BackupDir = "$ManagerDir\backups"
$ScriptsDir = "$ManagerDir\scripts\windows"

# ==================== Step 1: Detect Stack ====================
Write-Host "[Step 1/5] Detecting development stacks..." -ForegroundColor Yellow
Write-Host ""

$DetectedStack = $null
$StackInfo = @{}

# Check XAMPP
if (Test-Path "C:\xampp\apache\bin\httpd.exe") {
    $StackInfo["xampp"] = @{
        Name = "XAMPP"
        Path = "C:\xampp"
        Apache = "C:\xampp\apache\bin\httpd.exe"
        PHP = "C:\xampp\php\php.exe"
        MySQL = "C:\xampp\mysql\bin\mysql.exe"
    }
    Write-Host "  [OK] XAMPP detected at C:\xampp" -ForegroundColor Green
    if (-not $DetectedStack) { $DetectedStack = "xampp" }
}

# Check WAMP
$wampPaths = @("C:\wamp64", "C:\wamp")
foreach ($wampPath in $wampPaths) {
    if (Test-Path "$wampPath\bin\apache") {
        $apacheDir = Get-ChildItem "$wampPath\bin\apache" -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($apacheDir) {
            $StackInfo["wamp"] = @{
                Name = "WAMP"
                Path = $wampPath
                Apache = "$($apacheDir.FullName)\bin\httpd.exe"
            }
            Write-Host "  [OK] WAMP detected at $wampPath" -ForegroundColor Green
            if (-not $DetectedStack) { $DetectedStack = "wamp" }
            break
        }
    }
}

# Check Laragon
if (Test-Path "C:\laragon\bin\apache") {
    $apacheDir = Get-ChildItem "C:\laragon\bin\apache" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($apacheDir) {
        $StackInfo["laragon"] = @{
            Name = "Laragon"
            Path = "C:\laragon"
            Apache = "$($apacheDir.FullName)\bin\httpd.exe"
        }
        Write-Host "  [OK] Laragon detected at C:\laragon" -ForegroundColor Green
        if (-not $DetectedStack) { $DetectedStack = "laragon" }
    }
}

if ($StackInfo.Count -eq 0) {
    Write-Host "  [!] No development stack detected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install one of the following:" -ForegroundColor Yellow
    Write-Host "    - XAMPP: https://www.apachefriends.org/" -ForegroundColor Cyan
    Write-Host "    - WAMP:  https://www.wampserver.com/" -ForegroundColor Cyan
    Write-Host "    - Laragon: https://laragon.org/" -ForegroundColor Cyan
    Write-Host ""

    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

Write-Host ""

# Stack selection
if ($Stack -and $StackInfo.ContainsKey($Stack.ToLower())) {
    $SelectedStack = $Stack.ToLower()
} elseif ($Silent) {
    $SelectedStack = $DetectedStack
} else {
    if ($StackInfo.Count -gt 1) {
        Write-Host "Multiple stacks detected. Please select one:" -ForegroundColor Yellow
        $i = 1
        $stackKeys = @($StackInfo.Keys)
        foreach ($key in $stackKeys) {
            $default = if ($key -eq $DetectedStack) { " (recommended)" } else { "" }
            Write-Host "  $i. $($StackInfo[$key].Name)$default"
            $i++
        }
        Write-Host ""

        do {
            $selection = Read-Host "Enter number [1-$($StackInfo.Count)]"
            $selIndex = [int]$selection - 1
        } while ($selIndex -lt 0 -or $selIndex -ge $StackInfo.Count)

        $SelectedStack = $stackKeys[$selIndex]
    } else {
        $SelectedStack = $DetectedStack
    }
}

$StackName = $StackInfo[$SelectedStack].Name
Write-Host "Selected stack: $StackName" -ForegroundColor Green
Write-Host ""

# ==================== Step 2: Create Directories ====================
Write-Host "[Step 2/5] Creating directories..." -ForegroundColor Yellow

$directories = @($ManagerDir, $ConfDir, $CertDir, $BackupDir, $ScriptsDir)
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  [OK] Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Exists: $dir" -ForegroundColor Gray
    }
}

Write-Host ""

# ==================== Step 3: Create Default Configuration ====================
Write-Host "[Step 3/5] Creating default configuration..." -ForegroundColor Yellow

# Save stack config
$stackConfFile = "$ConfDir\stack.conf"
$SelectedStack | Out-File $stackConfFile -Encoding ASCII -Force
Write-Host "  [OK] Stack configuration saved" -ForegroundColor Green

# Create hosts.json if not exists
$hostsJson = "$ConfDir\hosts.json"
if (-not (Test-Path $hostsJson)) {
    # Create sample host
    $sampleHost = @{
        "localhost.test" = @{
            docroot = "C:/Sites"
            group = "Development"
            active = $true
            ssl = $true
            type = "static"
            aliases = @()
        }
    }
    $sampleHost | ConvertTo-Json -Depth 10 | Out-File $hostsJson -Encoding UTF8 -Force
    Write-Host "  [OK] Sample hosts.json created" -ForegroundColor Green
} else {
    Write-Host "  [OK] hosts.json already exists" -ForegroundColor Gray
}

# Create settings.json
$settingsJson = "$ConfDir\settings.json"
if (-not (Test-Path $settingsJson)) {
    $settings = @{
        stack = $SelectedStack
        autostart = $false
        theme = "system"
        language = "en"
        defaultDocroot = "C:/Sites"
        created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    $settings | ConvertTo-Json | Out-File $settingsJson -Encoding UTF8 -Force
    Write-Host "  [OK] Settings created" -ForegroundColor Green
} else {
    Write-Host "  [OK] Settings already exist" -ForegroundColor Gray
}

Write-Host ""

# ==================== Step 4: Copy Scripts ====================
Write-Host "[Step 4/5] Installing scripts..." -ForegroundColor Yellow

$scriptSource = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = @(
    "generate-all.ps1",
    "generate-vhosts-config.ps1",
    "generate-certificates.ps1",
    "update-hosts.ps1",
    "install.ps1",
    "detect-stack.ps1"
)

foreach ($script in $scripts) {
    $sourcePath = "$scriptSource\$script"
    $destPath = "$ScriptsDir\$script"

    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath -Force
        Write-Host "  [OK] Installed: $script" -ForegroundColor Green
    } else {
        Write-Host "  [!] Not found: $script" -ForegroundColor Yellow
    }
}

Write-Host ""

# ==================== Step 5: Generate Initial Certificates ====================
Write-Host "[Step 5/5] Generating SSL certificates..." -ForegroundColor Yellow

$certScript = "$ScriptsDir\generate-certificates.ps1"
if (Test-Path $certScript) {
    try {
        & $certScript -Stack $SelectedStack -ErrorAction SilentlyContinue
        Write-Host "  [OK] SSL certificates generated" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Certificate generation failed: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] Certificate script not found" -ForegroundColor Yellow
}

Write-Host ""

# ==================== Summary ====================
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Stack:     $StackName"
Write-Host "  Config:    $ConfDir"
Write-Host "  Certs:     $CertDir"
Write-Host "  Scripts:   $ScriptsDir"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open Localhost Manager app"
Write-Host "  2. Add your virtual hosts"
Write-Host "  3. Click 'Generate & Apply' to configure"
Write-Host ""
Write-Host "Manual commands:" -ForegroundColor Yellow
Write-Host "  Generate configs:  .\generate-all.ps1 -Stack $SelectedStack"
Write-Host "  Apply configs:     .\install.ps1 -Stack $SelectedStack (requires admin)"
Write-Host "  Update hosts file: .\update-hosts.ps1 (requires admin)"
Write-Host ""

# Trust certificates reminder
Write-Host "IMPORTANT: To avoid SSL warnings, import certificates:" -ForegroundColor Magenta
Write-Host "  1. Open: certmgr.msc"
Write-Host "  2. Go to: Trusted Root Certification Authorities > Certificates"
Write-Host "  3. Right-click > All Tasks > Import"
Write-Host "  4. Select certificates from: $CertDir"
Write-Host ""

if (-not $Silent) {
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    Read-Host
}
