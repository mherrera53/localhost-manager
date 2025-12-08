#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Cambiar DocumentRoot de Apache a /Users/mario/Sites/localhost

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    exit 1
fi

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S $@
}

echo "Configurando DocumentRoot de Apache..."
echo ""

# Backup
run_sudo cp /etc/apache2/httpd.conf /etc/apache2/httpd.conf.backup.docroot.$(date +%Y%m%d-%H%M%S)

# Cambiar DocumentRoot
run_sudo sed -i '' 's|DocumentRoot "/Library/WebServer/Documents"|DocumentRoot "/Users/mario/Sites/localhost"|g' /etc/apache2/httpd.conf

# Cambiar Directory
run_sudo sed -i '' 's|<Directory "/Library/WebServer/Documents">|<Directory "/Users/mario/Sites/localhost">|g' /etc/apache2/httpd.conf

# Habilitar FollowSymLinks y permitir .htaccess
run_sudo sed -i '' '/<Directory "\/Users\/mario\/Sites\/localhost">/,/<\/Directory>/ {
    s/AllowOverride None/AllowOverride All/g
    s/Options Indexes FollowSymLinks/Options Indexes FollowSymLinks MultiViews/g
}' /etc/apache2/httpd.conf

echo "✓ DocumentRoot cambiado a /Users/mario/Sites/localhost"

# Verificar y reiniciar
echo ""
echo "Verificando configuración..."
run_sudo /usr/sbin/apachectl configtest

if [ $? -eq 0 ]; then
    echo "✓ Configuración válida"
    echo ""
    echo "Reiniciando Apache..."
    run_sudo /usr/sbin/apachectl restart

    if [ $? -eq 0 ]; then
        echo "✓ Apache reiniciado"
        echo ""
        echo "Ahora puedes acceder a:"
        echo "  http://localhost/manager"
        echo "  http://localhost/"
    else
        echo "✗ Error reiniciando Apache"
        exit 1
    fi
else
    echo "✗ Error en la configuración"
    exit 1
fi
