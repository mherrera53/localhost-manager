# ==================================================
# Configure Services for Windows
# Localhost Manager - Windows PowerShell Script
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp"
)

$ErrorActionPreference = "Stop"

Write-Host "================================"
Write-Host " Localhost Manager - Windows"
Write-Host "================================"
Write-Host ""

# Detect Windows version
$WinVersion = [System.Environment]::OSVersion.Version
Write-Host "Windows Version: $($WinVersion.Major).$($WinVersion.Minor)"
Write-Host "Stack: $Stack"
Write-Host ""

# Define base paths based on stack
switch ($Stack.ToLower()) {
    "xampp" {
        $ApacheDir = "C:\xampp\apache"
        $PhpDir = "C:\xampp\php"
        $MysqlDir = "C:\xampp\mysql"
        $HtdocsDir = "C:\xampp\htdocs"
        $ApacheExe = "$ApacheDir\bin\httpd.exe"
        $PhpExe = "$PhpDir\php.exe"
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
    }
    "wamp" {
        $ApacheDir = "C:\wamp64\bin\apache\apache2.4.46"
        $PhpDir = "C:\wamp64\bin\php\php7.4.9"
        $MysqlDir = "C:\wamp64\bin\mysql\mysql8.0.21"
        $HtdocsDir = "C:\wamp64\www"
        $ApacheExe = "$ApacheDir\bin\httpd.exe"
        $PhpExe = "$PhpDir\php.exe"
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
    }
    "laragon" {
        $ApacheDir = "C:\laragon\bin\apache\httpd-2.4.47-win64-VS16"
        $PhpDir = "C:\laragon\bin\php\php-7.4.19-Win32-vc15-x64"
        $MysqlDir = "C:\laragon\bin\mysql\mysql-5.7.33-winx64"
        $HtdocsDir = "C:\laragon\www"
        $ApacheExe = "$ApacheDir\bin\httpd.exe"
        $PhpExe = "$PhpDir\php.exe"
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
    }
    default {
        Write-Error "Unknown stack: $Stack. Supported: xampp, wamp, laragon"
        exit 1
    }
}

# Check if paths exist
Write-Host "Checking installation..."
if (-not (Test-Path $ApacheExe)) {
    Write-Warning "Apache not found at: $ApacheExe"
}
if (-not (Test-Path $PhpExe)) {
    Write-Warning "PHP not found at: $PhpExe"
}
if (-not (Test-Path $MysqlExe)) {
    Write-Warning "MySQL not found at: $MysqlExe"
}

# Get service status
Write-Host ""
Write-Host "Service Status:"
Write-Host "---------------"

function Get-ServiceStatus {
    param([string]$ServiceName)

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "$ServiceName : $($service.Status)" -ForegroundColor $(
                if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' }
            )
            return $service.Status
        } else {
            Write-Host "$ServiceName : Not Installed" -ForegroundColor Gray
            return "NotInstalled"
        }
    } catch {
        Write-Host "$ServiceName : Error checking status" -ForegroundColor Red
        return "Error"
    }
}

# Check common service names
$ApacheStatus = Get-ServiceStatus "Apache2.4"
if ($ApacheStatus -eq "NotInstalled") {
    $ApacheStatus = Get-ServiceStatus "wampapache64"
}
if ($ApacheStatus -eq "NotInstalled") {
    $ApacheStatus = Get-ServiceStatus "apacheLaragon"
}

$MysqlStatus = Get-ServiceStatus "MySQL"
if ($MysqlStatus -eq "NotInstalled") {
    $MysqlStatus = Get-ServiceStatus "wampmysqld64"
}
if ($MysqlStatus -eq "NotInstalled") {
    $MysqlStatus = Get-ServiceStatus "mysqlLaragon"
}

Write-Host ""
Write-Host "Configuration complete!"
Write-Host ""
Write-Host "Paths:"
Write-Host "  Apache: $ApacheDir"
Write-Host "  PHP: $PhpDir"
Write-Host "  MySQL: $MysqlDir"
Write-Host "  Document Root: $HtdocsDir"
Write-Host ""
