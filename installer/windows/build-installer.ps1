# ==================================================
# Localhost Manager - Windows Installer Builder
# Builds Tauri app and creates NSIS installer
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,

    [Parameter(Mandatory=$false)]
    [switch]$Debug,

    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Localhost Manager - Installer Builder" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version: $Version"
Write-Host ""

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$DesktopAppDir = "$ProjectRoot\desktop-app"
$InstallerDir = "$ProjectRoot\installer\windows"
$OutputDir = "$InstallerDir\output"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ==================== Step 1: Check Prerequisites ====================
Write-Host "[Step 1/5] Checking prerequisites..." -ForegroundColor Yellow

# Check Rust
try {
    $rustVersion = & rustc --version 2>&1
    Write-Host "  [OK] Rust: $rustVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Rust not found. Install from: https://rustup.rs/" -ForegroundColor Red
    exit 1
}

# Check Node.js
try {
    $nodeVersion = & node --version 2>&1
    Write-Host "  [OK] Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Node.js not found. Install from: https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Check NSIS
$nsisPath = $null
$nsisPaths = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:LOCALAPPDATA\Programs\NSIS\makensis.exe"
)

foreach ($path in $nsisPaths) {
    if (Test-Path $path) {
        $nsisPath = $path
        break
    }
}

# Also check PATH
if (-not $nsisPath) {
    try {
        $nsisPath = (Get-Command makensis -ErrorAction SilentlyContinue).Source
    } catch {}
}

if ($nsisPath) {
    Write-Host "  [OK] NSIS: $nsisPath" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] NSIS not found. Download from: https://nsis.sourceforge.io/" -ForegroundColor Yellow
    Write-Host "           Installer will not be created, but Tauri bundle will be built." -ForegroundColor Yellow
}

Write-Host ""

# ==================== Step 2: Install Dependencies ====================
Write-Host "[Step 2/5] Installing dependencies..." -ForegroundColor Yellow

Push-Location $DesktopAppDir

# npm install if node_modules doesn't exist
if (-not (Test-Path "node_modules")) {
    Write-Host "  Installing npm packages..."
    & npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] npm install failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}
Write-Host "  [OK] Dependencies installed" -ForegroundColor Green

Pop-Location
Write-Host ""

# ==================== Step 3: Build Tauri Application ====================
if (-not $SkipBuild) {
    Write-Host "[Step 3/5] Building Tauri application..." -ForegroundColor Yellow

    Push-Location $DesktopAppDir

    $buildArgs = @("tauri", "build")
    if ($Debug) {
        $buildArgs += "--debug"
    }

    Write-Host "  Running: npm run $($buildArgs -join ' ')"
    & npm run @buildArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Tauri build failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "  [OK] Tauri build complete" -ForegroundColor Green
    Pop-Location
} else {
    Write-Host "[Step 3/5] Skipping build (--SkipBuild)" -ForegroundColor Yellow
}

Write-Host ""

# ==================== Step 4: Download Runtime Dependencies ====================
Write-Host "[Step 4/5] Preparing runtime dependencies..." -ForegroundColor Yellow

# Check/Download VC++ Redistributable
$vcRedistPath = "$InstallerDir\vc_redist.x64.exe"
if (-not (Test-Path $vcRedistPath)) {
    Write-Host "  Downloading VC++ Redistributable..."
    try {
        $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistPath -UseBasicParsing
        Write-Host "  [OK] VC++ Redistributable downloaded" -ForegroundColor Green
    } catch {
        Write-Host "  [WARNING] Could not download VC++ Redistributable: $_" -ForegroundColor Yellow
        Write-Host "           Users may need to install it manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] VC++ Redistributable exists" -ForegroundColor Green
}

# Check/Download WebView2 Bootstrapper
$webview2Path = "$InstallerDir\MicrosoftEdgeWebview2Setup.exe"
if (-not (Test-Path $webview2Path)) {
    Write-Host "  Downloading WebView2 Runtime..."
    try {
        $webview2Url = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
        Invoke-WebRequest -Uri $webview2Url -OutFile $webview2Path -UseBasicParsing
        Write-Host "  [OK] WebView2 Runtime downloaded" -ForegroundColor Green
    } catch {
        Write-Host "  [WARNING] Could not download WebView2 Runtime: $_" -ForegroundColor Yellow
        Write-Host "           Users may need to install it manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] WebView2 Runtime exists" -ForegroundColor Green
}

Write-Host ""

# ==================== Step 5: Create NSIS Installer ====================
Write-Host "[Step 5/5] Creating installer..." -ForegroundColor Yellow

if ($nsisPath) {
    $nsiScript = "$InstallerDir\localhost-manager.nsi"

    if (Test-Path $nsiScript) {
        Write-Host "  Running NSIS..."

        # Update version in NSI file
        $nsiContent = Get-Content $nsiScript -Raw
        $nsiContent = $nsiContent -replace '!define PRODUCT_VERSION ".*"', "!define PRODUCT_VERSION `"$Version`""
        $nsiContent | Set-Content $nsiScript -Encoding UTF8

        Push-Location $InstallerDir

        & $nsisPath /V3 $nsiScript

        if ($LASTEXITCODE -eq 0) {
            $installerFile = "LocalhostManager-Setup-$Version.exe"
            if (Test-Path $installerFile) {
                Move-Item $installerFile $OutputDir -Force
                Write-Host "  [OK] Installer created: $OutputDir\$installerFile" -ForegroundColor Green
            }
        } else {
            Write-Host "  [ERROR] NSIS compilation failed" -ForegroundColor Red
        }

        Pop-Location
    } else {
        Write-Host "  [ERROR] NSI script not found: $nsiScript" -ForegroundColor Red
    }
} else {
    Write-Host "  [SKIP] NSIS not available, using Tauri bundle only" -ForegroundColor Yellow

    # Copy Tauri MSI/EXE to output
    $tauriOutput = "$DesktopAppDir\src-tauri\target\release\bundle"
    if (Test-Path "$tauriOutput\msi\*.msi") {
        Copy-Item "$tauriOutput\msi\*.msi" $OutputDir -Force
        Write-Host "  [OK] MSI copied to output" -ForegroundColor Green
    }
    if (Test-Path "$tauriOutput\nsis\*.exe") {
        Copy-Item "$tauriOutput\nsis\*.exe" $OutputDir -Force
        Write-Host "  [OK] NSIS bundle copied to output" -ForegroundColor Green
    }
}

Write-Host ""

# ==================== Summary ====================
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Build Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output directory: $OutputDir"
Write-Host ""
Write-Host "Files:"
Get-ChildItem $OutputDir | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name) ($size MB)"
}
Write-Host ""
