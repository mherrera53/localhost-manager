# ==================================================
# Localhost Manager - Windows Installer
# Complete configuration for Apache, PHP, MySQL, SSL
# Supports: XAMPP, WAMP, Laragon
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Localhost Manager - Windows Installer" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$CertDir = "$ManagerDir\certs"
$ScriptsDir = "$ManagerDir\scripts\windows"

# Stack-specific configuration
switch ($Stack.ToLower()) {
    "xampp" {
        $BaseDir = "C:\xampp"
        $ApacheDir = "$BaseDir\apache"
        $ApacheConf = "$ApacheDir\conf\httpd.conf"
        $ApacheVhosts = "$ApacheDir\conf\extra\httpd-vhosts.conf"
        $ApacheSslConf = "$ApacheDir\conf\extra\httpd-ssl.conf"
        $ApacheBin = "$ApacheDir\bin\httpd.exe"
        $PhpDir = "$BaseDir\php"
        $PhpExe = "$PhpDir\php.exe"
        $PhpIni = "$PhpDir\php.ini"
        $MysqlDir = "$BaseDir\mysql"
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
        $SslDir = "$ApacheDir\conf\ssl"
        $ApacheService = "Apache2.4"
        $MysqlService = "mysql"
    }
    "wamp" {
        $BaseDir = "C:\wamp64"
        # WAMP has versioned directories, try to find them
        $ApacheVersions = Get-ChildItem "$BaseDir\bin\apache" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        $PhpVersions = Get-ChildItem "$BaseDir\bin\php" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        $MysqlVersions = Get-ChildItem "$BaseDir\bin\mysql" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1

        $ApacheDir = $ApacheVersions.FullName
        $ApacheConf = "$ApacheDir\conf\httpd.conf"
        $ApacheVhosts = "$ApacheDir\conf\extra\httpd-vhosts.conf"
        $ApacheSslConf = "$ApacheDir\conf\extra\httpd-ssl.conf"
        $ApacheBin = "$ApacheDir\bin\httpd.exe"
        $PhpDir = $PhpVersions.FullName
        $PhpExe = "$PhpDir\php.exe"
        $PhpIni = "$PhpDir\php.ini"
        $MysqlDir = $MysqlVersions.FullName
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
        $SslDir = "$ApacheDir\conf\ssl"
        $ApacheService = "wampapache64"
        $MysqlService = "wampmysqld64"
    }
    "laragon" {
        $BaseDir = "C:\laragon"
        $ApacheVersions = Get-ChildItem "$BaseDir\bin\apache" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        $PhpVersions = Get-ChildItem "$BaseDir\bin\php" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        $MysqlVersions = Get-ChildItem "$BaseDir\bin\mysql" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1

        $ApacheDir = $ApacheVersions.FullName
        $ApacheConf = "$ApacheDir\conf\httpd.conf"
        $ApacheVhosts = "$BaseDir\etc\apache2\sites-enabled\auto.localhost-manager.conf"
        $ApacheSslConf = "$ApacheDir\conf\extra\httpd-ssl.conf"
        $ApacheBin = "$ApacheDir\bin\httpd.exe"
        $PhpDir = $PhpVersions.FullName
        $PhpExe = "$PhpDir\php.exe"
        $PhpIni = "$PhpDir\php.ini"
        $MysqlDir = $MysqlVersions.FullName
        $MysqlExe = "$MysqlDir\bin\mysqld.exe"
        $SslDir = "$BaseDir\etc\ssl"
        $ApacheService = "Apache2.4"
        $MysqlService = "MySQL"
    }
    default {
        Write-Error "Stack no soportado: $Stack. Usa: xampp, wamp, laragon"
        exit 1
    }
}

Write-Host "Stack: $Stack" -ForegroundColor Yellow
Write-Host "Base: $BaseDir"
Write-Host ""

$ConfigChanged = $false

# ==================================================
# Step 1: Verify Installation
# ==================================================
Write-Host "Paso 1: Verificando instalacion..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

if (-not (Test-Path $BaseDir)) {
    Write-Error "$Stack no encontrado en $BaseDir"
    exit 1
}

if (Test-Path $ApacheBin) {
    Write-Host "[OK] Apache encontrado" -ForegroundColor Green
} else {
    Write-Warning "Apache no encontrado: $ApacheBin"
}

if (Test-Path $PhpExe) {
    $phpVersion = & $PhpExe -v 2>$null | Select-Object -First 1
    Write-Host "[OK] PHP encontrado: $phpVersion" -ForegroundColor Green
} else {
    Write-Warning "PHP no encontrado: $PhpExe"
}

if (Test-Path $MysqlExe) {
    Write-Host "[OK] MySQL encontrado" -ForegroundColor Green
} else {
    Write-Warning "MySQL no encontrado: $MysqlExe"
}

Write-Host ""

# ==================================================
# Step 2: Enable Required Apache Modules
# ==================================================
Write-Host "Paso 2: Habilitando modulos de Apache..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

if (Test-Path $ApacheConf) {
    $apacheConfig = Get-Content $ApacheConf -Raw

    $modulesToEnable = @(
        "mod_rewrite",
        "mod_ssl",
        "mod_proxy",
        "mod_proxy_fcgi",
        "mod_socache_shmcb"
    )

    foreach ($module in $modulesToEnable) {
        $pattern = "#LoadModule ${module}_module"
        $replacement = "LoadModule ${module}_module"

        if ($apacheConfig -match "^LoadModule ${module}_module" -and $apacheConfig -notmatch "^#LoadModule ${module}_module") {
            Write-Host "[OK] $module ya habilitado" -ForegroundColor Green
        }
        elseif ($apacheConfig -match "#LoadModule ${module}_module") {
            $apacheConfig = $apacheConfig -replace "#(LoadModule ${module}_module)", '$1'
            Write-Host "[OK] $module habilitado" -ForegroundColor Green
            $ConfigChanged = $true
        }
        else {
            Write-Host "[!] $module no encontrado en configuracion" -ForegroundColor Yellow
        }
    }

    # Enable vhosts include
    if ($apacheConfig -notmatch "^Include conf/extra/httpd-vhosts.conf" -and $apacheConfig -match "#Include conf/extra/httpd-vhosts.conf") {
        $apacheConfig = $apacheConfig -replace "#(Include conf/extra/httpd-vhosts.conf)", '$1'
        Write-Host "[OK] Virtual Hosts habilitados" -ForegroundColor Green
        $ConfigChanged = $true
    } else {
        Write-Host "[OK] Virtual Hosts ya habilitados" -ForegroundColor Green
    }

    # Enable SSL include
    if ($apacheConfig -notmatch "^Include conf/extra/httpd-ssl.conf" -and $apacheConfig -match "#Include conf/extra/httpd-ssl.conf") {
        $apacheConfig = $apacheConfig -replace "#(Include conf/extra/httpd-ssl.conf)", '$1'
        Write-Host "[OK] SSL habilitado" -ForegroundColor Green
        $ConfigChanged = $true
    } else {
        Write-Host "[OK] SSL ya habilitado" -ForegroundColor Green
    }

    if ($ConfigChanged) {
        Copy-Item $ApacheConf "$ApacheConf.bak" -Force
        $apacheConfig | Out-File $ApacheConf -Encoding ASCII -Force
    }
}

Write-Host ""

# ==================================================
# Step 3: Configure SSL Directory
# ==================================================
Write-Host "Paso 3: Configurando SSL..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

# Create SSL directory
if (-not (Test-Path $SslDir)) {
    New-Item -ItemType Directory -Path $SslDir -Force | Out-Null
    Write-Host "[OK] Directorio SSL creado: $SslDir" -ForegroundColor Green
}

# Create certs directory in manager
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
}

# Generate default certificate if not exists
$defaultCert = "$CertDir\default.crt"
$defaultKey = "$CertDir\default.key"

if (-not (Test-Path $defaultCert)) {
    Write-Host "Generando certificado por defecto..."

    # Check if OpenSSL is available
    $opensslPath = "$BaseDir\apache\bin\openssl.exe"
    if (-not (Test-Path $opensslPath)) {
        $opensslPath = "openssl"
    }

    try {
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
CN = localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
"@
        $confFile = "$env:TEMP\openssl_default.cnf"
        $opensslConf | Out-File $confFile -Encoding ASCII

        & $opensslPath req -x509 -nodes -days 3650 -newkey rsa:2048 `
            -keyout $defaultKey -out $defaultCert `
            -config $confFile 2>$null

        Remove-Item $confFile -Force -ErrorAction SilentlyContinue

        Write-Host "[OK] Certificado por defecto generado" -ForegroundColor Green
    }
    catch {
        Write-Warning "No se pudo generar certificado: $_"
    }
} else {
    Write-Host "[OK] Certificado por defecto existe" -ForegroundColor Green
}

Write-Host ""

# ==================================================
# Step 4: Copy Certificates
# ==================================================
Write-Host "Paso 4: Copiando certificados..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

$certsCopied = 0
Get-ChildItem "$CertDir\*.crt" -ErrorAction SilentlyContinue | ForEach-Object {
    $certName = $_.Name
    $keyName = $certName -replace "\.crt$", ".key"
    $destCert = "$SslDir\$certName"
    $destKey = "$SslDir\$keyName"

    if (-not (Test-Path $destCert) -or $Force) {
        Copy-Item $_.FullName $destCert -Force
        $certsCopied++
    }

    $keyPath = "$CertDir\$keyName"
    if ((Test-Path $keyPath) -and (-not (Test-Path $destKey) -or $Force)) {
        Copy-Item $keyPath $destKey -Force
    }
}

if ($certsCopied -gt 0) {
    Write-Host "[OK] $certsCopied certificado(s) copiado(s)" -ForegroundColor Green
    $ConfigChanged = $true
} else {
    Write-Host "[OK] Certificados ya actualizados" -ForegroundColor Green
}

Write-Host ""

# ==================================================
# Step 5: Configure Virtual Hosts
# ==================================================
Write-Host "Paso 5: Configurando Virtual Hosts..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

$vhostsSource = "$ConfDir\vhosts.conf"
if (Test-Path $vhostsSource) {
    $sourceHash = (Get-FileHash $vhostsSource -Algorithm MD5).Hash
    $destHash = ""

    if (Test-Path $ApacheVhosts) {
        $destHash = (Get-FileHash $ApacheVhosts -Algorithm MD5).Hash
    }

    if ($sourceHash -ne $destHash -or $Force) {
        # Ensure directory exists for Laragon
        $vhostsDir = Split-Path $ApacheVhosts -Parent
        if (-not (Test-Path $vhostsDir)) {
            New-Item -ItemType Directory -Path $vhostsDir -Force | Out-Null
        }

        Copy-Item $vhostsSource $ApacheVhosts -Force
        Write-Host "[OK] Virtual Hosts actualizados" -ForegroundColor Green
        $ConfigChanged = $true
    } else {
        Write-Host "[OK] Virtual Hosts sin cambios" -ForegroundColor Green
    }
} else {
    Write-Warning "No se encontro $vhostsSource"
    Write-Host "    Ejecuta primero: .\generate-vhosts-config.ps1"
}

Write-Host ""

# ==================================================
# Step 6: Test Apache Configuration
# ==================================================
Write-Host "Paso 6: Verificando configuracion..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

try {
    $testResult = & $ApacheBin -t 2>&1
    if ($LASTEXITCODE -eq 0 -or $testResult -match "Syntax OK") {
        Write-Host "[OK] Configuracion de Apache valida" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Error en configuracion de Apache:" -ForegroundColor Red
        Write-Host $testResult -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Warning "No se pudo verificar configuracion: $_"
}

Write-Host ""

# ==================================================
# Step 7: Restart Services
# ==================================================
Write-Host "Paso 7: Reiniciando servicios..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"

if ($ConfigChanged) {
    # Try to restart Apache service
    $apacheService = Get-Service -Name $ApacheService -ErrorAction SilentlyContinue
    if ($apacheService) {
        Write-Host "Reiniciando Apache..."
        Restart-Service -Name $ApacheService -Force
        Start-Sleep -Seconds 2

        $apacheService = Get-Service -Name $ApacheService
        if ($apacheService.Status -eq "Running") {
            Write-Host "[OK] Apache reiniciado" -ForegroundColor Green
        } else {
            Write-Warning "Apache no esta corriendo"
        }
    } else {
        # XAMPP uses control panel, try to use apache bin directly
        Write-Host "Intentando reiniciar Apache via ejecutable..."
        try {
            & "$ApacheDir\bin\httpd.exe" -k restart 2>$null
            Write-Host "[OK] Comando de reinicio enviado" -ForegroundColor Green
        } catch {
            Write-Host "[!] Reinicia Apache manualmente desde el panel de control de $Stack" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[OK] Sin cambios, no es necesario reiniciar" -ForegroundColor Green
}

Write-Host ""

# ==================================================
# Summary
# ==================================================
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Instalacion Completada" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Stack: $Stack"
Write-Host "Cambios aplicados: $(if ($ConfigChanged) { 'Si' } else { 'No' })"
Write-Host ""
Write-Host "Proximos pasos:"
Write-Host "  1. Ejecuta .\update-hosts.ps1 para actualizar hosts"
Write-Host "  2. Reinicia $Stack si es necesario"
Write-Host "  3. Accede a tus sitios via HTTPS"
Write-Host ""
