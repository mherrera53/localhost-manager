# ==================================================
# Generate SSL Certificates for Windows - Optimized
# Localhost Manager - PowerShell Script
# ==================================================
# Features:
# - Certificate caching (skip valid certs)
# - Expiration validation
# - Wildcard & IP SAN support
# - Better error handling
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp",

    [Parameter(Mandatory=$false)]
    [string]$Domain = "",

    [Parameter(Mandatory=$false)]
    [int]$DaysValid = 3650,

    [Parameter(Mandatory=$false)]
    [int]$MinDaysRemaining = 30
)

$ErrorActionPreference = "Stop"

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$CertDir = "$ManagerDir\certs"
$HostsJson = "$ConfDir\hosts.json"

# Counters
$script:Generated = 0
$script:Skipped = 0
$script:Failed = 0

# Find OpenSSL
switch ($Stack.ToLower()) {
    "xampp" { $OpenSSL = "C:\xampp\apache\bin\openssl.exe" }
    "wamp" {
        $apacheDir = Get-ChildItem "C:\wamp64\bin\apache" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($apacheDir) {
            $OpenSSL = "$($apacheDir.FullName)\bin\openssl.exe"
        } else {
            $OpenSSL = "openssl"
        }
    }
    "laragon" {
        $apacheDir = Get-ChildItem "C:\laragon\bin\apache" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($apacheDir) {
            $OpenSSL = "$($apacheDir.FullName)\bin\openssl.exe"
        } else {
            $OpenSSL = "openssl"
        }
    }
    default { $OpenSSL = "openssl" }
}

Write-Host "======================================"
Write-Host " SSL Certificate Generator"
Write-Host "======================================"
Write-Host ""
Write-Host "OpenSSL: $OpenSSL"
Write-Host ""

# Verify OpenSSL exists
if (-not (Test-Path $OpenSSL)) {
    # Try system OpenSSL
    try {
        $null = & openssl version 2>$null
        $OpenSSL = "openssl"
    } catch {
        Write-Error "OpenSSL not found. Install OpenSSL or use a stack like XAMPP."
        exit 1
    }
}

# Create cert directory
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
}

# Function to check if certificate is still valid
function Test-CertificateValid {
    param(
        [string]$CertFile,
        [int]$MinDays = $MinDaysRemaining
    )

    if (-not (Test-Path $CertFile)) {
        return $false
    }

    try {
        # Get certificate expiration date using OpenSSL
        $output = & $OpenSSL x509 -enddate -noout -in $CertFile 2>$null
        if (-not $output) {
            return $false
        }

        # Parse "notAfter=Mon DD HH:MM:SS YYYY GMT"
        $dateStr = $output -replace "notAfter=", ""
        $expiryDate = [DateTime]::Parse($dateStr)
        $minDate = (Get-Date).AddDays($MinDays)

        return $expiryDate -gt $minDate
    }
    catch {
        return $false
    }
}

# Function to generate certificate
function New-SelfSignedCert {
    param(
        [string]$Domain,
        [string[]]$Aliases = @(),
        [switch]$Force
    )

    $certFile = "$CertDir\$Domain.crt"
    $keyFile = "$CertDir\$Domain.key"

    # Check if certificate already exists and is valid
    if (-not $Force -and (Test-CertificateValid -CertFile $certFile)) {
        Write-Host "[SKIP] $Domain (valid, not expiring)" -ForegroundColor Yellow
        $script:Skipped++
        return $true
    }

    # Build SAN list
    $sanList = @("DNS.1 = $Domain")
    $sanIndex = 2

    foreach ($alias in $Aliases) {
        if ($alias -and $alias.Trim()) {
            $sanList += "DNS.$sanIndex = $($alias.Trim())"
            $sanIndex++
        }
    }

    # Add wildcard
    $sanList += "DNS.$sanIndex = *.$Domain"

    $sanConfig = $sanList -join "`n"

    # OpenSSL config
    $opensslConf = @"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Development
L = LocalDev
O = Localhost Manager
OU = Development
CN = $Domain

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
$sanConfig
IP.1 = 127.0.0.1
"@

    $confFile = "$env:TEMP\openssl_$Domain.cnf"
    $opensslConf | Out-File $confFile -Encoding ASCII

    try {
        # Generate certificate
        $output = & $OpenSSL req -x509 -nodes -days $DaysValid -newkey rsa:2048 `
            -keyout $keyFile -out $certFile `
            -config $confFile 2>&1

        if (Test-Path $certFile) {
            Write-Host "[OK] $Domain" -ForegroundColor Green
            $script:Generated++
            return $true
        } else {
            Write-Host "[ERROR] $Domain - Certificate not generated" -ForegroundColor Red
            $script:Failed++
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] $Domain - $_" -ForegroundColor Red
        $script:Failed++
        return $false
    }
    finally {
        Remove-Item $confFile -Force -ErrorAction SilentlyContinue
    }
}

# Generate default certificate
Write-Host "[1/2] Generating default certificate..."
New-SelfSignedCert -Domain "default" -Aliases @("localhost", "*.localhost")

# If specific domain requested
if ($Domain) {
    Write-Host ""
    Write-Host "Generating certificate for: $Domain"
    New-SelfSignedCert -Domain $Domain
    exit 0
}

# Read hosts.json and generate certificates for active hosts
if (Test-Path $HostsJson) {
    Write-Host ""
    Write-Host "[2/2] Processing hosts..."
    Write-Host ""

    try {
        $hostsContent = Get-Content $HostsJson -Raw -ErrorAction Stop
        $hosts = $hostsContent | ConvertFrom-Json

        foreach ($prop in $hosts.PSObject.Properties) {
            $domain = $prop.Name
            $config = $prop.Value

            # Skip inactive hosts (treat null as active)
            if ($null -ne $config.active -and -not $config.active) {
                continue
            }

            # Get aliases
            $aliases = @()
            if ($config.aliases) {
                foreach ($alias in $config.aliases) {
                    if ($alias -is [string] -and $alias.Trim()) {
                        $aliases += $alias.Trim()
                    }
                    elseif ($alias.value -and ($null -eq $alias.active -or $alias.active)) {
                        $aliases += $alias.value.Trim()
                    }
                }
            }

            # Generate certificate
            New-SelfSignedCert -Domain $domain -Aliases $aliases | Out-Null
        }
    }
    catch {
        Write-Host "[ERROR] Failed to parse hosts.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "[INFO] No hosts.json found at $HostsJson" -ForegroundColor Yellow
    Write-Host "[INFO] Only default certificate was generated" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "======================================"
Write-Host " Summary"
Write-Host "======================================"
Write-Host "  Generated: $script:Generated" -ForegroundColor Green
Write-Host "  Skipped:   $script:Skipped" -ForegroundColor Yellow
Write-Host "  Failed:    $script:Failed" -ForegroundColor Red
Write-Host ""
Write-Host "Location: $CertDir"
Write-Host "Validity: $DaysValid days"
Write-Host ""
Write-Host "NOTE: To avoid browser warnings,"
Write-Host "      import certificates to Windows store:"
Write-Host "      certmgr.msc -> Trusted Root Certification Authorities"
Write-Host ""

# Exit with error if any failed
if ($script:Failed -gt 0) {
    exit 1
}
exit 0
