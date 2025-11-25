# ==================================================
# Generate Virtual Hosts Configuration for Windows
# Localhost Manager - PowerShell Script
# Supports: XAMPP, WAMP, Laragon
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp"
)

$ErrorActionPreference = "Stop"

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$CertDir = "$ManagerDir\certs"
$HostsJson = "$ConfDir\hosts.json"
$OutputFile = "$ConfDir\vhosts.conf"

# Stack-specific paths
switch ($Stack.ToLower()) {
    "xampp" {
        $ApacheConfDir = "C:\xampp\apache\conf\extra"
        $DefaultCertPath = "C:\xampp\apache\conf\ssl.crt"
        $DefaultKeyPath = "C:\xampp\apache\conf\ssl.key"
    }
    "wamp" {
        $ApacheConfDir = "C:\wamp64\bin\apache\apache2.4.54\conf\extra"
        $DefaultCertPath = "C:\wamp64\bin\apache\apache2.4.54\conf\ssl.crt"
        $DefaultKeyPath = "C:\wamp64\bin\apache\apache2.4.54\conf\ssl.key"
    }
    "laragon" {
        $ApacheConfDir = "C:\laragon\etc\apache2\sites-enabled"
        $DefaultCertPath = "C:\laragon\etc\ssl\laragon.crt"
        $DefaultKeyPath = "C:\laragon\etc\ssl\laragon.key"
    }
    default {
        $ApacheConfDir = "C:\xampp\apache\conf\extra"
        $DefaultCertPath = "$CertDir\default.crt"
        $DefaultKeyPath = "$CertDir\default.key"
    }
}

Write-Host "======================================"
Write-Host " Generador de Virtual Hosts - Windows"
Write-Host "======================================"
Write-Host ""
Write-Host "Stack: $Stack"
Write-Host ""

# Check hosts.json exists
if (-not (Test-Path $HostsJson)) {
    Write-Error "No se encontro: $HostsJson"
    exit 1
}

# Create conf directory if not exists
if (-not (Test-Path $ConfDir)) {
    New-Item -ItemType Directory -Path $ConfDir -Force | Out-Null
}

# Read hosts.json
$hosts = Get-Content $HostsJson -Raw | ConvertFrom-Json

# Start building vhosts config
$vhostsConfig = @"
# Virtual Hosts - Generated $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Stack: $Stack
# Localhost Manager for Windows

# Default SSL VirtualHost (catch-all)
<VirtualHost *:443>
    ServerName _default_
    SSLEngine on
    SSLCertificateFile "$CertDir/default.crt"
    SSLCertificateKeyFile "$CertDir/default.key"
    Redirect 404 /
</VirtualHost>

SSLStrictSNIVHostCheck off

"@

$activeCount = 0

# Process each host
foreach ($prop in $hosts.PSObject.Properties) {
    $domain = $prop.Name
    $config = $prop.Value

    # Skip inactive hosts
    if (-not $config.active) {
        continue
    }

    $activeCount++
    $docroot = $config.docroot

    # Convert Unix paths to Windows if needed
    if ($docroot -match "^/Users/") {
        $docroot = $docroot -replace "^/Users/", "C:\Users\"
        $docroot = $docroot -replace "/", "\"
    }

    # Build aliases list
    $aliases = @()
    if ($config.aliases) {
        foreach ($alias in $config.aliases) {
            if ($alias -is [string] -and $alias.Trim()) {
                $aliases += $alias.Trim()
            }
            elseif ($alias.value -and $alias.active -ne $false) {
                $aliases += $alias.value.Trim()
            }
        }
    }

    $aliasLines = ""
    foreach ($alias in $aliases) {
        $aliasLines += "    ServerAlias $alias`n"
    }

    # HTTP VirtualHost (redirect to HTTPS)
    $vhostsConfig += @"

# $domain
<VirtualHost *:80>
    ServerName $domain
$aliasLines    Redirect permanent / https://$domain/
</VirtualHost>

"@

    # HTTPS VirtualHost
    $vhostsConfig += @"
<VirtualHost *:443>
    ServerName $domain
$aliasLines
    DocumentRoot "$docroot"

    <Directory "$docroot">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:9000"
    </FilesMatch>

    SSLEngine on
    SSLCertificateFile "$CertDir/$domain.crt"
    SSLCertificateKeyFile "$CertDir/$domain.key"
</VirtualHost>

"@
}

# Write output file
$vhostsConfig | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

Write-Host "[OK] Virtual Hosts generados: $activeCount hosts activos"
Write-Host ""
Write-Host "Archivo: $OutputFile"
Write-Host ""
Write-Host "Para aplicar, ejecuta:"
Write-Host "  .\install.ps1 -Stack $Stack"
Write-Host ""
