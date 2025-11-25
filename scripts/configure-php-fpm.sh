#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@"
}

echo "Configurando PHP-FPM con Apache..."

# Backup
run_sudo cp /etc/apache2/httpd.conf /etc/apache2/httpd.conf.backup.fpm.$(date +%Y%m%d-%H%M%S)

# Habilitar módulos necesarios en httpd.conf
run_sudo sed -i '' 's/#LoadModule proxy_module/LoadModule proxy_module/g' /etc/apache2/httpd.conf
run_sudo sed -i '' 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/g' /etc/apache2/httpd.conf

echo "✓ Módulos proxy habilitados"

# Remover líneas de PHP si existen
run_sudo sed -i '' '/# PHP 8.4 Module/,/^$/d' /etc/apache2/httpd.conf
run_sudo sed -i '' '/LoadModule php_module/d' /etc/apache2/httpd.conf
run_sudo sed -i '' '/<FilesMatch \\\.php\$/,/<\/FilesMatch>/d' /etc/apache2/httpd.conf

# Agregar configuración PHP-FPM
echo "$SUDO_PASSWORD" | sudo -S bash -c 'cat >> /etc/apache2/httpd.conf << "PHPFPMEOF"

# PHP-FPM Configuration
<FilesMatch \.php$>
    SetHandler "proxy:fcgi://127.0.0.1:9000"
</FilesMatch>

<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>
PHPFPMEOF'

echo "✓ Configuración PHP-FPM agregada"

# Asegurar que PHP-FPM está corriendo
brew services restart php@8.4
echo "✓ PHP-FPM reiniciado"

# Verificar
echo ""
echo "Verificando configuración..."
run_sudo /usr/sbin/apachectl configtest

if [ $? -eq 0 ]; then
    echo "✓ Configuración válida"

    # Reiniciar Apache
    echo ""
    echo "Reiniciando Apache..."
    run_sudo /usr/sbin/apachectl restart

    echo "✓ Apache reiniciado con PHP-FPM"
    echo ""
    echo "Ahora puedes acceder a: http://localhost/manager"
    echo ""
    echo "Verificando PHP..."
    curl -s http://localhost/manager/ | head -5
else
    echo "✗ Error en configuración"
    exit 1
fi
