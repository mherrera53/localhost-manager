#!/bin/bash
# Script de instalación de Localhost Manager
# Ejecuta TODO con un solo Touch ID usando osascript

# Capturar el HOME del usuario ANTES de ejecutar como root
USER_HOME="$HOME"

echo "======================================"
echo " Localhost Manager - Instalación"
echo "======================================"
echo ""
echo "Solicitando permisos de administrador (Touch ID una sola vez)..."

# Crear script temporal con todas las operaciones que necesitan sudo
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << SUDO_SCRIPT
#!/bin/bash
set -e

# Variables - USER_HOME se expande aquí, las demás en runtime
USER_HOME="$USER_HOME"
APACHE_CONF="/etc/apache2/httpd.conf"
APACHE_SSL_CONF="/etc/apache2/extra/httpd-ssl.conf"
APACHE_VHOSTS_CONF="/etc/apache2/extra/httpd-vhosts.conf"
SSL_DIR="/etc/apache2/ssl"
MANAGER_DIR="\${USER_HOME}/localhost-manager"
CERT_DIR="\${MANAGER_DIR}/certs"
CONF_DIR="\${MANAGER_DIR}/conf"

echo "[1/8] Configurando módulos Apache para PHP-FPM..."

# Comentar TODOS los módulos PHP (mod_php) ya que usamos PHP-FPM
sed -i.bak 's/^LoadModule php_module/#LoadModule php_module/g' "\${APACHE_CONF}" 2>/dev/null || true

# Solo dejar mpm_event activo (mejor para PHP-FPM)
sed -i.bak 's/^LoadModule mpm_prefork_module/#LoadModule mpm_prefork_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^LoadModule mpm_worker_module/#LoadModule mpm_worker_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^#LoadModule mpm_event_module/LoadModule mpm_event_module/g' "\${APACHE_CONF}" 2>/dev/null || true

# Habilitar módulos necesarios para PHP-FPM
sed -i.bak 's/^#LoadModule rewrite_module/LoadModule rewrite_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^#LoadModule ssl_module/LoadModule ssl_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^#LoadModule proxy_module/LoadModule proxy_module/g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's/^#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/g' "\${APACHE_CONF}" 2>/dev/null || true

echo "[2/8] Habilitando vhosts y SSL..."
sed -i.bak 's|^#Include.*/httpd-vhosts.conf|Include /private/etc/apache2/extra/httpd-vhosts.conf|g' "\${APACHE_CONF}" 2>/dev/null || true
sed -i.bak 's|^#Include.*/httpd-ssl.conf|Include /private/etc/apache2/extra/httpd-ssl.conf|g' "\${APACHE_CONF}" 2>/dev/null || true

echo "[3/8] Configurando directorio SSL..."
mkdir -p "\${SSL_DIR}"
chmod 755 "\${SSL_DIR}"

echo "[4/8] Generando certificado por defecto si no existe..."
if [ ! -f "\${SSL_DIR}/default.crt" ]; then
    openssl req -x509 -nodes -days 3650 \
        -newkey rsa:2048 \
        -keyout "\${SSL_DIR}/default.key" \
        -out "\${SSL_DIR}/default.crt" \
        -subj "/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/OU=Development/CN=localhost" \
        2>/dev/null
fi

echo "[5/8] Copiando certificados SSL..."
if [ -d "\${CERT_DIR}" ]; then
    cp -p "\${CERT_DIR}"/*.crt "\${SSL_DIR}/" 2>/dev/null || true
    cp -p "\${CERT_DIR}"/*.key "\${SSL_DIR}/" 2>/dev/null || true
    chmod 644 "\${SSL_DIR}"/*.crt 2>/dev/null || true
    chmod 600 "\${SSL_DIR}"/*.key 2>/dev/null || true
fi

echo "[6/8] Aplicando configuración de Virtual Hosts..."
if [ -f "\${CONF_DIR}/vhosts.conf" ]; then
    cp -f "\${CONF_DIR}/vhosts.conf" "\${APACHE_VHOSTS_CONF}"
fi

echo "[7/8] Actualizando /etc/hosts..."
cp /etc/hosts /etc/hosts.backup 2>/dev/null || true
sed -i.bak '/# Localhost Manager/,/# End Localhost Manager/d' /etc/hosts 2>/dev/null || true

HOSTS_JSON="\${USER_HOME}/localhost-manager/conf/hosts.json"
if [ -f "\${HOSTS_JSON}" ]; then
    echo "# Localhost Manager" >> /etc/hosts
    /usr/bin/jq -r 'to_entries[] | select(.value.active == true) | .key' "\${HOSTS_JSON}" 2>/dev/null | while read -r domain; do
        echo "127.0.0.1    \${domain}" >> /etc/hosts
        /usr/bin/jq -r --arg d "\${domain}" '.[\$d].aliases[]? | select(.active == true) | .value' "\${HOSTS_JSON}" 2>/dev/null | while read -r alias; do
            [ -n "\${alias}" ] && echo "127.0.0.1    \${alias}" >> /etc/hosts
        done
    done
    echo "# End Localhost Manager" >> /etc/hosts
fi

echo "[8/8] Verificando y reiniciando Apache..."
/usr/sbin/apachectl configtest 2>&1 | grep -v "fully qualified domain name" || true
/usr/sbin/apachectl stop 2>/dev/null || true
sleep 1
/usr/sbin/apachectl start

echo ""
echo "[OK] Instalación completada"
SUDO_SCRIPT

chmod +x "$TEMP_SCRIPT"

# Ejecutar TODO con un solo Touch ID usando osascript
osascript -e "do shell script \"$TEMP_SCRIPT\" with administrator privileges" 2>&1

# Limpiar
rm -f "$TEMP_SCRIPT"

echo ""
echo "======================================"
echo " Instalación Completada"
echo "======================================"
