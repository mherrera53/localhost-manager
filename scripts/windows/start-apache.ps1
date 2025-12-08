# ==================================================
# Localhost Manager - Start Apache (Windows)
# Supports: XAMPP, WAMP, Laragon, Standalone
# ==================================================

$ErrorActionPreference = "SilentlyContinue"

# Read configured stack
$stackFile = "$env:USERPROFILE\localhost-manager\conf\stack.conf"
$stack = "xampp"
if (Test-Path $stackFile) {
    $stack = (Get-Content $stackFile -Raw).Trim()
}

Write-Host "Starting Apache ($stack)..." -ForegroundColor Cyan

switch ($stack) {
    "xampp" {
        # XAMPP Apache
        if (Test-Path "C:\xampp\apache\bin\httpd.exe") {
            Start-Process -FilePath "C:\xampp\xampp_start.exe" -WindowStyle Hidden
            Write-Host "[OK] XAMPP Apache started" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] XAMPP not found at C:\xampp" -ForegroundColor Red
            exit 1
        }
    }
    "wamp" {
        # WAMP Apache
        $wampPath = if (Test-Path "C:\wamp64") { "C:\wamp64" } else { "C:\wamp" }
        if (Test-Path "$wampPath\wampmanager.exe") {
            Start-Process -FilePath "$wampPath\wampmanager.exe" -WindowStyle Hidden
            Write-Host "[OK] WAMP started" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] WAMP not found" -ForegroundColor Red
            exit 1
        }
    }
    "laragon" {
        # Laragon
        if (Test-Path "C:\laragon\laragon.exe") {
            Start-Process -FilePath "C:\laragon\laragon.exe" -ArgumentList "start" -WindowStyle Hidden
            Write-Host "[OK] Laragon started" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Laragon not found at C:\laragon" -ForegroundColor Red
            exit 1
        }
    }
    default {
        # Try Windows Service
        try {
            Start-Service -Name "Apache2.4" -ErrorAction Stop
            Write-Host "[OK] Apache service started" -ForegroundColor Green
        } catch {
            # Try httpd directly
            $apachePaths = @(
                "C:\Apache24\bin\httpd.exe",
                "C:\Program Files\Apache24\bin\httpd.exe",
                "C:\Program Files (x86)\Apache24\bin\httpd.exe"
            )
            foreach ($path in $apachePaths) {
                if (Test-Path $path) {
                    Start-Process -FilePath $path -WindowStyle Hidden
                    Write-Host "[OK] Apache started from $path" -ForegroundColor Green
                    exit 0
                }
            }
            Write-Host "[ERROR] Apache not found" -ForegroundColor Red
            exit 1
        }
    }
}
