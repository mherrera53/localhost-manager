# ==================================================
# Auto-Detect Development Stack - Windows
# Localhost Manager - Stack Detection Script
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [switch]$Json,

    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

$ErrorActionPreference = "SilentlyContinue"

# Stack definitions
$Stacks = @{
    "xampp" = @{
        Name = "XAMPP"
        BasePaths = @("C:\xampp", "D:\xampp", "E:\xampp")
        ApacheRelPath = "apache\bin\httpd.exe"
        PhpRelPath = "php\php.exe"
        MysqlRelPath = "mysql\bin\mysqld.exe"
        OpenSSLRelPath = "apache\bin\openssl.exe"
        ConfPath = "apache\conf\httpd.conf"
        VhostsPath = "apache\conf\extra\httpd-vhosts.conf"
        Priority = 1
    }
    "wamp" = @{
        Name = "WAMP"
        BasePaths = @("C:\wamp64", "C:\wamp", "D:\wamp64")
        ApacheSubDir = "bin\apache"
        PhpSubDir = "bin\php"
        MysqlSubDir = "bin\mysql"
        ApacheExe = "bin\httpd.exe"
        PhpExe = "php.exe"
        MysqlExe = "bin\mysqld.exe"
        Priority = 2
    }
    "laragon" = @{
        Name = "Laragon"
        BasePaths = @("C:\laragon", "D:\laragon")
        ApacheSubDir = "bin\apache"
        PhpSubDir = "bin\php"
        MysqlSubDir = "bin\mysql"
        ApacheExe = "bin\httpd.exe"
        PhpExe = "php.exe"
        MysqlExe = "bin\mysqld.exe"
        Priority = 3
    }
}

# Detection results
$DetectedStacks = @()

# ==================== XAMPP Detection ====================
function Test-XAMPP {
    foreach ($basePath in $Stacks.xampp.BasePaths) {
        if (Test-Path $basePath) {
            $apachePath = Join-Path $basePath $Stacks.xampp.ApacheRelPath
            $phpPath = Join-Path $basePath $Stacks.xampp.PhpRelPath
            $mysqlPath = Join-Path $basePath $Stacks.xampp.MysqlRelPath

            if (Test-Path $apachePath) {
                $result = @{
                    Stack = "xampp"
                    Name = "XAMPP"
                    BasePath = $basePath
                    Apache = @{
                        Path = $apachePath
                        Version = Get-ApacheVersion $apachePath
                        Installed = $true
                    }
                    PHP = @{
                        Path = $phpPath
                        Version = if (Test-Path $phpPath) { Get-PHPVersion $phpPath } else { $null }
                        Installed = Test-Path $phpPath
                    }
                    MySQL = @{
                        Path = $mysqlPath
                        Version = if (Test-Path $mysqlPath) { Get-MySQLVersion (Join-Path $basePath "mysql\bin\mysql.exe") } else { $null }
                        Installed = Test-Path $mysqlPath
                    }
                    OpenSSL = @{
                        Path = Join-Path $basePath $Stacks.xampp.OpenSSLRelPath
                        Installed = Test-Path (Join-Path $basePath $Stacks.xampp.OpenSSLRelPath)
                    }
                    ConfigPath = Join-Path $basePath $Stacks.xampp.ConfPath
                    VhostsPath = Join-Path $basePath $Stacks.xampp.VhostsPath
                    Priority = $Stacks.xampp.Priority
                }
                return $result
            }
        }
    }
    return $null
}

# ==================== WAMP Detection ====================
function Test-WAMP {
    foreach ($basePath in $Stacks.wamp.BasePaths) {
        if (Test-Path $basePath) {
            $apacheDir = Join-Path $basePath $Stacks.wamp.ApacheSubDir
            if (Test-Path $apacheDir) {
                # Get latest version directories
                $latestApache = Get-ChildItem $apacheDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                $latestPHP = Get-ChildItem (Join-Path $basePath $Stacks.wamp.PhpSubDir) -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                $latestMySQL = Get-ChildItem (Join-Path $basePath $Stacks.wamp.MysqlSubDir) -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1

                if ($latestApache) {
                    $apachePath = Join-Path $latestApache.FullName $Stacks.wamp.ApacheExe
                    $phpPath = if ($latestPHP) { Join-Path $latestPHP.FullName $Stacks.wamp.PhpExe } else { $null }
                    $mysqlPath = if ($latestMySQL) { Join-Path $latestMySQL.FullName $Stacks.wamp.MysqlExe } else { $null }

                    $result = @{
                        Stack = "wamp"
                        Name = "WAMP"
                        BasePath = $basePath
                        Apache = @{
                            Path = $apachePath
                            Version = if (Test-Path $apachePath) { Get-ApacheVersion $apachePath } else { $null }
                            Installed = Test-Path $apachePath
                            VersionDir = $latestApache.Name
                        }
                        PHP = @{
                            Path = $phpPath
                            Version = if ($phpPath -and (Test-Path $phpPath)) { Get-PHPVersion $phpPath } else { $null }
                            Installed = $phpPath -and (Test-Path $phpPath)
                            VersionDir = if ($latestPHP) { $latestPHP.Name } else { $null }
                        }
                        MySQL = @{
                            Path = $mysqlPath
                            Version = if ($latestMySQL) { Get-MySQLVersion (Join-Path $latestMySQL.FullName "bin\mysql.exe") } else { $null }
                            Installed = $mysqlPath -and (Test-Path $mysqlPath)
                            VersionDir = if ($latestMySQL) { $latestMySQL.Name } else { $null }
                        }
                        OpenSSL = @{
                            Path = if ($latestApache) { Join-Path $latestApache.FullName "bin\openssl.exe" } else { $null }
                            Installed = $latestApache -and (Test-Path (Join-Path $latestApache.FullName "bin\openssl.exe"))
                        }
                        ConfigPath = if ($latestApache) { Join-Path $latestApache.FullName "conf\httpd.conf" } else { $null }
                        VhostsPath = if ($latestApache) { Join-Path $latestApache.FullName "conf\extra\httpd-vhosts.conf" } else { $null }
                        Priority = $Stacks.wamp.Priority
                    }
                    return $result
                }
            }
        }
    }
    return $null
}

# ==================== Laragon Detection ====================
function Test-Laragon {
    foreach ($basePath in $Stacks.laragon.BasePaths) {
        if (Test-Path $basePath) {
            $apacheDir = Join-Path $basePath $Stacks.laragon.ApacheSubDir
            if (Test-Path $apacheDir) {
                # Get latest version directories
                $latestApache = Get-ChildItem $apacheDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                $latestPHP = Get-ChildItem (Join-Path $basePath $Stacks.laragon.PhpSubDir) -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                $latestMySQL = Get-ChildItem (Join-Path $basePath $Stacks.laragon.MysqlSubDir) -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1

                if ($latestApache) {
                    $apachePath = Join-Path $latestApache.FullName $Stacks.laragon.ApacheExe
                    $phpPath = if ($latestPHP) { Join-Path $latestPHP.FullName $Stacks.laragon.PhpExe } else { $null }
                    $mysqlPath = if ($latestMySQL) { Join-Path $latestMySQL.FullName $Stacks.laragon.MysqlExe } else { $null }

                    $result = @{
                        Stack = "laragon"
                        Name = "Laragon"
                        BasePath = $basePath
                        Apache = @{
                            Path = $apachePath
                            Version = if (Test-Path $apachePath) { Get-ApacheVersion $apachePath } else { $null }
                            Installed = Test-Path $apachePath
                            VersionDir = $latestApache.Name
                        }
                        PHP = @{
                            Path = $phpPath
                            Version = if ($phpPath -and (Test-Path $phpPath)) { Get-PHPVersion $phpPath } else { $null }
                            Installed = $phpPath -and (Test-Path $phpPath)
                            VersionDir = if ($latestPHP) { $latestPHP.Name } else { $null }
                        }
                        MySQL = @{
                            Path = $mysqlPath
                            Version = if ($latestMySQL) { Get-MySQLVersion (Join-Path $latestMySQL.FullName "bin\mysql.exe") } else { $null }
                            Installed = $mysqlPath -and (Test-Path $mysqlPath)
                            VersionDir = if ($latestMySQL) { $latestMySQL.Name } else { $null }
                        }
                        OpenSSL = @{
                            Path = if ($latestApache) { Join-Path $latestApache.FullName "bin\openssl.exe" } else { $null }
                            Installed = $latestApache -and (Test-Path (Join-Path $latestApache.FullName "bin\openssl.exe"))
                        }
                        ConfigPath = if ($latestApache) { Join-Path $latestApache.FullName "conf\httpd.conf" } else { $null }
                        VhostsPath = Join-Path $basePath "etc\apache2\sites-enabled\auto.localhost-manager.conf"
                        Priority = $Stacks.laragon.Priority
                    }
                    return $result
                }
            }
        }
    }
    return $null
}

# ==================== Version Detection Helpers ====================
function Get-ApacheVersion {
    param([string]$Path)
    try {
        $output = & $Path -v 2>&1
        if ($output -match "Apache/(\d+\.\d+\.\d+)") {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Get-PHPVersion {
    param([string]$Path)
    try {
        $output = & $Path -v 2>&1
        if ($output -match "PHP (\d+\.\d+\.\d+)") {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Get-MySQLVersion {
    param([string]$Path)
    try {
        $output = & $Path --version 2>&1
        if ($output -match "Ver (\d+\.\d+\.\d+)") {
            return $Matches[1]
        }
    } catch {}
    return $null
}

# ==================== Main Detection ====================
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Localhost Manager - Stack Detector" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Detect all stacks
$xampp = Test-XAMPP
$wamp = Test-WAMP
$laragon = Test-Laragon

if ($xampp) { $DetectedStacks += $xampp }
if ($wamp) { $DetectedStacks += $wamp }
if ($laragon) { $DetectedStacks += $laragon }

# Output results
if ($Json) {
    # JSON output for programmatic use
    $output = @{
        detected = $DetectedStacks.Count -gt 0
        stacks = $DetectedStacks
        recommended = if ($DetectedStacks.Count -gt 0) {
            ($DetectedStacks | Sort-Object { $_.Priority } | Select-Object -First 1).Stack
        } else {
            $null
        }
    }
    $output | ConvertTo-Json -Depth 10
} else {
    # Human-readable output
    if ($DetectedStacks.Count -eq 0) {
        Write-Host "[!] No development stacks detected" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Supported stacks:"
        Write-Host "  - XAMPP: https://www.apachefriends.org/"
        Write-Host "  - WAMP:  https://www.wampserver.com/"
        Write-Host "  - Laragon: https://laragon.org/"
        Write-Host ""
    } else {
        Write-Host "Detected $($DetectedStacks.Count) stack(s):" -ForegroundColor Green
        Write-Host ""

        foreach ($stack in $DetectedStacks) {
            Write-Host "[$($stack.Name)]" -ForegroundColor Cyan
            Write-Host "  Base Path: $($stack.BasePath)"

            if ($Detailed) {
                Write-Host ""
                Write-Host "  Apache:" -ForegroundColor Yellow
                Write-Host "    Path: $($stack.Apache.Path)"
                Write-Host "    Version: $(if ($stack.Apache.Version) { $stack.Apache.Version } else { 'Unknown' })"
                Write-Host "    Status: $(if ($stack.Apache.Installed) { 'Installed' } else { 'Not Found' })"

                Write-Host ""
                Write-Host "  PHP:" -ForegroundColor Yellow
                Write-Host "    Path: $($stack.PHP.Path)"
                Write-Host "    Version: $(if ($stack.PHP.Version) { $stack.PHP.Version } else { 'Unknown' })"
                Write-Host "    Status: $(if ($stack.PHP.Installed) { 'Installed' } else { 'Not Found' })"

                Write-Host ""
                Write-Host "  MySQL:" -ForegroundColor Yellow
                Write-Host "    Path: $($stack.MySQL.Path)"
                Write-Host "    Version: $(if ($stack.MySQL.Version) { $stack.MySQL.Version } else { 'Unknown' })"
                Write-Host "    Status: $(if ($stack.MySQL.Installed) { 'Installed' } else { 'Not Found' })"

                Write-Host ""
                Write-Host "  OpenSSL: $(if ($stack.OpenSSL.Installed) { 'Available' } else { 'Not Found' })"
                Write-Host "  Config: $($stack.ConfigPath)"
                Write-Host "  VHosts: $($stack.VhostsPath)"
            } else {
                $apacheVer = if ($stack.Apache.Version) { "v$($stack.Apache.Version)" } else { "?" }
                $phpVer = if ($stack.PHP.Version) { "v$($stack.PHP.Version)" } else { "?" }
                $mysqlVer = if ($stack.MySQL.Version) { "v$($stack.MySQL.Version)" } else { "?" }
                Write-Host "  Apache: $apacheVer | PHP: $phpVer | MySQL: $mysqlVer"
            }
            Write-Host ""
        }

        # Recommendation
        $recommended = $DetectedStacks | Sort-Object { $_.Priority } | Select-Object -First 1
        Write-Host "Recommended: $($recommended.Name)" -ForegroundColor Green
        Write-Host ""
    }
}

# Return recommended stack name for scripting
if (-not $Json) {
    if ($DetectedStacks.Count -gt 0) {
        $recommended = ($DetectedStacks | Sort-Object { $_.Priority } | Select-Object -First 1).Stack
        return $recommended
    }
}
