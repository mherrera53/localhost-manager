#!/bin/bash

# Crear enlace simbólico al manager

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    exit 1
fi

echo "Creando enlace simbólico..."
echo "$SUDO_PASSWORD" | sudo -S ln -sf /Users/mario/Sites/localhost/manager /Library/WebServer/Documents/manager

if [ $? -eq 0 ]; then
    echo "✓ Enlace creado: http://localhost/manager"
else
    echo "✗ Error creando enlace"
    exit 1
fi

# Verificar permisos
echo "$SUDO_PASSWORD" | sudo -S chmod -R 755 /Users/mario/Sites/localhost/manager

echo "✓ Permisos configurados"
echo ""
echo "Ahora puedes acceder a: http://localhost/manager"
