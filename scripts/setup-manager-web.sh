#!/bin/bash

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

echo "Configurando manager en Apache..."

# Eliminar enlace simbólico si existe
echo "$SUDO_PASSWORD" | sudo -S rm -rf /Library/WebServer/Documents/manager

# Copiar directorio
echo "$SUDO_PASSWORD" | sudo -S cp -R /Users/mario/Sites/localhost/manager /Library/WebServer/Documents/

# Permisos
echo "$SUDO_PASSWORD" | sudo -S chmod -R 755 /Library/WebServer/Documents/manager

echo "✓ Manager configurado"
echo ""
echo "Accede a: http://localhost/manager"
