#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S $@
}

echo "Arreglando permisos..."

# Permisos del directorio
run_sudo chmod -R 755 /Library/WebServer/Documents/manager
run_sudo chown -R _www:_www /Library/WebServer/Documents/manager

# Crear archivo de configuración para el directorio
cat << 'EOF' | run_sudo tee /etc/apache2/other/manager.conf > /dev/null
<Directory "/Library/WebServer/Documents/manager">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
</Directory>
EOF

echo "✓ Permisos configurados"
echo "✓ Configuración de directorio creada"

# Reiniciar Apache
echo ""
echo "Reiniciando Apache..."
run_sudo /usr/sbin/apachectl restart

echo "✓ Apache reiniciado"
echo ""
echo "Accede a: http://localhost/manager"
