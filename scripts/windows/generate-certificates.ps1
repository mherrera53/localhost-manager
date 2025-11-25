# ==================================================
# Generate SSL Certificates for Windows
# Localhost Manager - PowerShell Script
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp",

    [Parameter(Mandatory=$false)]
    [string]$Domain = ""
)

$ErrorActionPreference = "Stop"

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$CertDir = "$ManagerDir\certs"
$HostsJson = "$ConfDir\hosts.json"

# Find OpenSSL
switch ($Stack.ToLower()) {
    "xampp" { $OpenSSL = "C:\xampp\apache\bin\openssl.exe" }
    "wamp" {
        $apacheDir = Get-ChildItem "C:\wamp64\bin\apache" -Directory | Sort-Object Name -Descending | Select-Object -First 1
        $OpenSSL = "$($apacheDir.FullName)\bin\openssl.exe"
    }
    "laragon" {
        $apacheDir = Get-ChildItem "C:\laragon\bin\apache" -Directory | Sort-Object Name -Descending | Select-Object -First 1
        $OpenSSL = "$($apacheDir.FullName)\bin\openssl.exe"
    }
    default { $OpenSSL = "openssl" }
}

Write-Host "======================================"
Write-Host " Generador de Certificados SSL"
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
        Write-Error "OpenSSL no encontrado. Instala OpenSSL o usa un stack como XAMPP."
        exit 1
    }
}

# Create cert directory
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
}

# Function to generate certificate
function New-SelfSignedCert {
    param(
        [string]$Domain,
        [string[]]$Aliases = @()
    )

    $certFile = "$CertDir\$Domain.crt"
    $keyFile = "$CertDir\$Domain.key"

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
        $output = & $OpenSSL req -x509 -nodes -days 3650 -newkey rsa:2048 `
            -keyout $keyFile -out $certFile `
            -config $confFile 2>&1

        if (Test-Path $certFile) {
            Write-Host "[OK] $Domain" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] $Domain - No se genero certificado" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] $Domain - $_" -ForegroundColor Red
        return $false
    }
    finally {
        Remove-Item $confFile -Force -ErrorAction SilentlyContinue
    }
}

# Generate default certificate
Write-Host "Generando certificado por defecto..."
New-SelfSignedCert -Domain "default" -Aliases @("localhost", "*.localhost")

# If specific domain requested
if ($Domain) {
    Write-Host ""
    Write-Host "Generando certificado para: $Domain"
    New-SelfSignedCert -Domain $Domain
    exit 0
}

# Read hosts.json and generate certificates for active hosts
if (Test-Path $HostsJson) {
    Write-Host ""
    Write-Host "Generando certificados para hosts activos..."
    Write-Host ""

    $hosts = Get-Content $HostsJson -Raw | ConvertFrom-Json
    $generated = 0

    foreach ($prop in $hosts.PSObject.Properties) {
        $domain = $prop.Name
        $config = $prop.Value

        # Skip inactive hosts
        if (-not $config.active) {
            continue
        }

        # Get aliases
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

        # Generate certificate
        if (New-SelfSignedCert -Domain $domain -Aliases $aliases) {
            $generated++
        }
    }

    Write-Host ""
    Write-Host "[OK] $generated certificados generados" -ForegroundColor Green
}

Write-Host ""
Write-Host "Certificados guardados en: $CertDir"
Write-Host ""
Write-Host "NOTA: Para evitar advertencias del navegador,"
Write-Host "      importa los certificados al almacen de Windows:"
Write-Host "      certmgr.msc -> Trusted Root Certification Authorities"
Write-Host ""
