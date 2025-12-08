#!/bin/bash

# Script para aplicar configuración automáticamente
# Usa sudo con password desde macOS Keychain

# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Recuperar password de sudo desde Keychain
SERVICE_NAME="localhost-manager-sudo"
ACCOUNT_NAME="$USER"

SUDO_PASSWORD=$(security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    echo "Ejecuta primero: bash ~/localhost-manager/scripts/setup-keychain.sh"
    exit 1
fi
CONF_DIR="$HOME/localhost-manager/conf"
CERT_DIR="$HOME/localhost-manager/certs"
SSL_DIR="/etc/apache2/ssl"
APACHE_VHOSTS="/etc/apache2/extra/httpd-vhosts.conf"
ETC_HOSTS="/etc/hosts"

echo "======================================"
echo " Aplicando Configuración"
echo "======================================"
echo ""

# Función para ejecutar comando con sudo
run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S $@
}

# 1. Copiar certificados SSL
echo "Paso 1: Copiando certificados SSL..."
run_sudo mkdir -p "$SSL_DIR"
run_sudo cp -f "$CERT_DIR"/*.crt "$SSL_DIR/" 2>/dev/null || true
run_sudo cp -f "$CERT_DIR"/*.key "$SSL_DIR/" 2>/dev/null || true
run_sudo chmod 644 "$SSL_DIR"/*.crt 2>/dev/null || true
run_sudo chmod 600 "$SSL_DIR"/*.key 2>/dev/null || true
echo "✓ Certificados copiados"
echo ""

# 2. Aplicar configuración de Virtual Hosts
if [ -f "$CONF_DIR/vhosts.conf" ]; then
    echo "Paso 2: Aplicando configuración de Virtual Hosts..."
    run_sudo cp -f "$CONF_DIR/vhosts.conf" "$APACHE_VHOSTS"
    echo "✓ Virtual Hosts configurados"
    echo ""
else
    echo "⚠️  Archivo vhosts.conf no encontrado. Genera la configuración desde la interfaz web."
    echo ""
fi

# 3. Actualizar /etc/hosts
if [ -f "$CONF_DIR/hosts.txt" ]; then
    echo "Paso 3: Actualizando /etc/hosts..."

    # Backup del archivo hosts
    run_sudo cp "$ETC_HOSTS" "${ETC_HOSTS}.backup.$(date +%Y%m%d-%H%M%S)"

    # Eliminar entradas antiguas de Localhost Manager
    run_sudo sed -i '' '/# Localhost Manager/,/##/d' "$ETC_HOSTS" 2>/dev/null || true

    # Agregar nuevas entradas
    cat "$CONF_DIR/hosts.txt" | run_sudo tee -a "$ETC_HOSTS" > /dev/null

    echo "✓ /etc/hosts actualizado"
    echo ""
else
    echo "⚠️  Archivo hosts.txt no encontrado. Genera el archivo desde la interfaz web."
    echo ""
fi

# 4. Verificar configuración de Apache
echo "Paso 4: Verificando configuración de Apache..."
run_sudo apachectl configtest

if [ $? -eq 0 ]; then
    echo "✓ Configuración válida"
    echo ""
else
    echo "✗ Error en la configuración de Apache"
    exit 1
fi

# 5. Reiniciar Apache
echo "Paso 5: Reiniciando Apache..."
run_sudo apachectl restart

if [ $? -eq 0 ]; then
    echo "✓ Apache reiniciado"
    echo ""
else
    echo "✗ Error reiniciando Apache"
    exit 1
fi

echo "======================================"
echo " ✓ Configuración Aplicada"
echo "======================================"
echo ""
echo "Todos los cambios han sido aplicados exitosamente."
echo ""
