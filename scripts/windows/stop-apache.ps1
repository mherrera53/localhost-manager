# ==================================================
# Localhost Manager - Stop Apache (Windows)
# Supports: XAMPP, WAMP, Laragon, Standalone
# ==================================================

$ErrorActionPreference = "SilentlyContinue"

# Read configured stack
$stackFile = "$env:USERPROFILE\localhost-manager\conf\stack.conf"
$stack = "xampp"
if (Test-Path $stackFile) {
    $stack = (Get-Content $stackFile -Raw).Trim()
}

Write-Host "Stopping Apache ($stack)..." -ForegroundColor Cyan

switch ($stack) {
    "xampp" {
        # XAMPP Apache
        if (Test-Path "C:\xampp\apache\bin\httpd.exe") {
            Start-Process -FilePath "C:\xampp\xampp_stop.exe" -WindowStyle Hidden
            # Also try to kill httpd directly
            Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] XAMPP Apache stopped" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] XAMPP not found at C:\xampp" -ForegroundColor Red
            exit 1
        }
    }
    "wamp" {
        # WAMP Apache - Stop via taskkill
        Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "wampmanager" -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] WAMP stopped" -ForegroundColor Green
    }
    "laragon" {
        # Laragon
        if (Test-Path "C:\laragon\laragon.exe") {
            Start-Process -FilePath "C:\laragon\laragon.exe" -ArgumentList "stop" -WindowStyle Hidden
            Write-Host "[OK] Laragon stopped" -ForegroundColor Green
        } else {
            Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Apache stopped" -ForegroundColor Green
        }
    }
    default {
        # Try Windows Service
        try {
            Stop-Service -Name "Apache2.4" -Force -ErrorAction Stop
            Write-Host "[OK] Apache service stopped" -ForegroundColor Green
        } catch {
            # Kill httpd process directly
            Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Apache process stopped" -ForegroundColor Green
        }
    }
}
