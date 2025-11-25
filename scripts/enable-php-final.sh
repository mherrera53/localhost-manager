#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@"
}

echo "Configurando PHP 8.4 en Apache..."

# Backup
run_sudo cp /etc/apache2/httpd.conf /etc/apache2/httpd.conf.backup.php.$(date +%Y%m%d-%H%M%S)

# Cambiar DirectoryIndex
run_sudo sed -i '' 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' /etc/apache2/httpd.conf

echo "✓ DirectoryIndex actualizado"

# Agregar módulo PHP al final
echo "$SUDO_PASSWORD" | sudo -S bash -c 'cat >> /etc/apache2/httpd.conf << "PHPEOF"

# PHP 8.4 Module
LoadModule php_module /opt/homebrew/opt/php@8.4/lib/httpd/modules/libphp.so

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
PHPEOF'

echo "✓ Módulo PHP 8.4 agregado"

# Verificar
echo ""
echo "Verificando configuración..."
run_sudo /usr/sbin/apachectl configtest

if [ $? -eq 0 ]; then
    echo "✓ Configuración válida"

    # Reiniciar
    echo ""
    echo "Reiniciando Apache..."
    run_sudo /usr/sbin/apachectl restart

    echo "✓ Apache reiniciado con PHP 8.4"
    echo ""
    echo "Accede a: http://localhost/manager"
else
    echo "✗ Error en configuración"
    exit 1
fi
