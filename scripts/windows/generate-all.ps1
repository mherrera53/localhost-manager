# ==================================================
# Generate All Configurations - Windows
# Localhost Manager - Master Script
# ==================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Stack = "xampp"
)

$ErrorActionPreference = "Stop"

$ScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Localhost Manager - Generador" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Stack: $Stack"
Write-Host ""

# Step 1: Generate Virtual Hosts
Write-Host "[1/3] Generando Virtual Hosts..." -ForegroundColor Yellow
try {
    & "$ScriptsDir\generate-vhosts-config.ps1" -Stack $Stack
    Write-Host "[OK] Virtual Hosts generados" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Error generando Virtual Hosts: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Generate SSL Certificates
Write-Host "[2/3] Generando Certificados SSL..." -ForegroundColor Yellow
try {
    & "$ScriptsDir\generate-certificates.ps1" -Stack $Stack -ErrorAction SilentlyContinue
    Write-Host "[OK] Certificados generados" -ForegroundColor Green
} catch {
    Write-Host "[!] Certificados: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Update Hosts File (requires admin)
Write-Host "[3/3] Actualizando archivo hosts..." -ForegroundColor Yellow

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    try {
        & "$ScriptsDir\update-hosts.ps1"
        Write-Host "[OK] Archivo hosts actualizado" -ForegroundColor Green
    } catch {
        Write-Host "[!] Error actualizando hosts: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] Se requieren permisos de administrador para actualizar hosts" -ForegroundColor Yellow
    Write-Host "    Ejecuta manualmente: .\update-hosts.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Configuracion Generada" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Proximo paso:"
Write-Host "  .\install.ps1 -Stack $Stack" -ForegroundColor Yellow
Write-Host ""
