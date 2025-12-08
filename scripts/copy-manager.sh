#!/bin/bash

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

echo "$SUDO_PASSWORD" | sudo -S cp -R /Users/mario/Sites/localhost/manager /Library/WebServer/Documents/
echo "$SUDO_PASSWORD" | sudo -S chmod -R 755 /Library/WebServer/Documents/manager

echo "✓ Manager copiado a /Library/WebServer/Documents/manager"
echo "Accede a: http://localhost/manager"
