# ==================================================
# Localhost Manager - Restart Apache (Windows)
# Supports: XAMPP, WAMP, Laragon, Standalone
# ==================================================

$ErrorActionPreference = "SilentlyContinue"

# Read configured stack
$stackFile = "$env:USERPROFILE\localhost-manager\conf\stack.conf"
$stack = "xampp"
if (Test-Path $stackFile) {
    $stack = (Get-Content $stackFile -Raw).Trim()
}

Write-Host "Restarting Apache ($stack)..." -ForegroundColor Cyan

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Stop Apache
& "$scriptDir\stop-apache.ps1"
Start-Sleep -Seconds 2

# Start Apache
& "$scriptDir\start-apache.ps1"

Write-Host "[OK] Apache restarted" -ForegroundColor Green
