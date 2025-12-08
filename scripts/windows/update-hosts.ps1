# ==================================================
# Update Windows Hosts File
# Localhost Manager - PowerShell Script
# Requires: Administrator privileges
# ==================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Paths
$ManagerDir = "$env:USERPROFILE\localhost-manager"
$ConfDir = "$ManagerDir\conf"
$HostsJson = "$ConfDir\hosts.json"
$WindowsHosts = "C:\Windows\System32\drivers\etc\hosts"
$BackupDir = "$ManagerDir\backups"

Write-Host "======================================"
Write-Host " Actualizador de Hosts - Windows"
Write-Host "======================================"
Write-Host ""

# Check hosts.json exists
if (-not (Test-Path $HostsJson)) {
    Write-Error "No se encontro: $HostsJson"
    exit 1
}

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Backup current hosts file
$backupFile = "$BackupDir\hosts_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
Copy-Item $WindowsHosts $backupFile -Force
Write-Host "[OK] Backup creado: $backupFile"

# Read current hosts file
$currentHosts = Get-Content $WindowsHosts -Raw

# Remove old Localhost Manager entries
$startMarker = "# BEGIN Localhost Manager"
$endMarker = "# END Localhost Manager"

if ($currentHosts -match "(?s)$startMarker.*?$endMarker") {
    $currentHosts = $currentHosts -replace "(?s)$startMarker.*?$endMarker\r?\n?", ""
    Write-Host "[OK] Entradas anteriores eliminadas"
}

# Read hosts.json
$hosts = Get-Content $HostsJson -Raw | ConvertFrom-Json

# Build new entries
$newEntries = @"

$startMarker
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# DO NOT EDIT - Managed by Localhost Manager

"@

$activeCount = 0

foreach ($prop in $hosts.PSObject.Properties) {
    $domain = $prop.Name
    $config = $prop.Value

    # Skip inactive hosts
    if (-not $config.active) {
        continue
    }

    $activeCount++
    $line = "127.0.0.1    $domain"

    # Add active aliases
    if ($config.aliases) {
        foreach ($alias in $config.aliases) {
            if ($alias -is [string] -and $alias.Trim()) {
                $line += "    $($alias.Trim())"
            }
            elseif ($alias.value -and $alias.active -ne $false) {
                $line += "    $($alias.value.Trim())"
            }
        }
    }

    $newEntries += "$line`n"
}

$newEntries += @"

$endMarker

"@

# Write updated hosts file
$updatedHosts = $currentHosts.TrimEnd() + $newEntries
$updatedHosts | Out-File -FilePath $WindowsHosts -Encoding ASCII -Force

Write-Host ""
Write-Host "[OK] Archivo hosts actualizado"
Write-Host "    Hosts activos: $activeCount"
Write-Host ""

# Flush DNS cache
Write-Host "Limpiando cache DNS..."
ipconfig /flushdns | Out-Null
Write-Host "[OK] Cache DNS limpiado"
Write-Host ""
