#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Script para iniciar Apache usando password de Keychain

# Recuperar password de sudo desde Keychain
SERVICE_NAME="localhost-manager-sudo"
ACCOUNT_NAME="$USER"

SUDO_PASSWORD=$(security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    echo "Ejecuta: bash ~/localhost-manager/scripts/setup-keychain.sh"
    exit 1
fi

echo "Iniciando Apache..."
echo "$SUDO_PASSWORD" | sudo -S apachectl start 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Apache iniciado exitosamente"
else
    echo "ℹ️  Apache ya está corriendo o hubo un error"
fi

# Verificar estado
echo ""
echo "Estado de Apache:"
echo "$SUDO_PASSWORD" | sudo -S apachectl status 2>&1 | head -3
