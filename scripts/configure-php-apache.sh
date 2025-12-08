#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Configurar PHP 8.4 en Apache

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "⚠️  Password no encontrado en Keychain."
    exit 1
fi

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S $@
}

echo "Configurando PHP 8.4 en Apache..."
echo ""

# Backup de httpd.conf
run_sudo cp /etc/apache2/httpd.conf /etc/apache2/httpd.conf.backup.$(date +%Y%m%d-%H%M%S)

# Agregar módulo PHP 8.4 al final del archivo
cat << 'EOF' | run_sudo tee -a /etc/apache2/httpd.conf > /dev/null

# PHP 8.4 Configuration
LoadModule php_module /opt/homebrew/opt/php@8.4/lib/httpd/modules/libphp.so

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>

<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>
EOF

echo "✓ Módulo PHP 8.4 agregado a Apache"

# Habilitar mod_rewrite
run_sudo sed -i '' 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf
echo "✓ mod_rewrite habilitado"

# Verificar configuración
echo ""
echo "Verificando configuración..."
run_sudo apachectl configtest

if [ $? -eq 0 ]; then
    echo "✓ Configuración válida"

    # Reiniciar Apache
    echo ""
    echo "Reiniciando Apache..."
    run_sudo apachectl restart

    if [ $? -eq 0 ]; then
        echo "✓ Apache reiniciado exitosamente"
        echo ""
        echo "PHP 8.4 está ahora configurado en Apache"
        echo "Accede a: http://localhost/manager"
    else
        echo "✗ Error reiniciando Apache"
        exit 1
    fi
else
    echo "✗ Error en la configuración"
    exit 1
fi
