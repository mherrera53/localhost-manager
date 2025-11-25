#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Iniciar Apache nativo de macOS

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    exit 1
fi

echo "Iniciando Apache nativo de macOS..."
echo "$SUDO_PASSWORD" | sudo -S /usr/sbin/apachectl start 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Apache iniciado"
else
    echo "ℹ️  Apache ya está corriendo o hubo un error"
fi

echo ""
echo "Verificando estado..."
echo "$SUDO_PASSWORD" | sudo -S /usr/sbin/apachectl status 2>&1 | head -3
