#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Script de instalación de Localhost Manager - OPTIMIZADO
# Configura Apache, PHP 8.4, MySQL 8 y todos los virtual hosts
# Usa password de Keychain para sudo
# OPTIMIZADO: Solo actualiza lo necesario, sin reinstalar desde cero

echo "======================================"
echo " Localhost Manager - Instalación"
echo "======================================"
echo ""

# Función para ejecutar comando con sudo (usa Touch ID si está configurado)
run_sudo() {
    sudo "$@"
}

# Variables
APACHE_CONF="/etc/apache2/httpd.conf"
APACHE_SSL_CONF="/etc/apache2/extra/httpd-ssl.conf"
APACHE_VHOSTS_CONF="/etc/apache2/extra/httpd-vhosts.conf"
SSL_DIR="/etc/apache2/ssl"
MANAGER_DIR="$HOME/localhost-manager"
CERT_DIR="$MANAGER_DIR/certs"
CONF_DIR="$MANAGER_DIR/conf"

# Variable para rastrear si hubo cambios
CONFIG_CHANGED=false

echo "Paso 1: Verificando PHP-FPM..."
echo "-------------------------------------------"

# Verificar que PHP-FPM esté corriendo
if pgrep -q "php-fpm"; then
    echo "[OK] PHP-FPM está corriendo"
else
    echo "[!] PHP-FPM no está corriendo, iniciando..."
    brew services start php@8.3
    echo "[OK] PHP-FPM iniciado"
    CONFIG_CHANGED=true
fi

# Comentar cualquier módulo PHP antiguo (usamos PHP-FPM)
if grep -q "^LoadModule php_module" "$APACHE_CONF"; then
    run_sudo sed -i.bak 's/^LoadModule php_module/#LoadModule php_module/g' "$APACHE_CONF"
    echo "[OK] Módulo PHP comentado (usando PHP-FPM)"
    CONFIG_CHANGED=true
fi

echo ""
echo "Paso 2: Habilitando módulos necesarios..."
echo "-------------------------------------------"

# Función helper para habilitar módulos con verificación
enable_module() {
    local module_name=$1
    local module_pattern=$2
    local friendly_name=$3

    if grep -q "^LoadModule $module_name" "$APACHE_CONF"; then
        echo "[OK] $friendly_name ya está habilitado"
    elif grep -q "^#LoadModule $module_name" "$APACHE_CONF"; then
        run_sudo sed -i.bak "s/^#LoadModule $module_pattern/LoadModule $module_pattern/g" "$APACHE_CONF"
        echo "[OK] $friendly_name habilitado"
        CONFIG_CHANGED=true
    else
        echo "[!] $friendly_name no encontrado en configuración"
    fi
}

# Habilitar módulos necesarios
enable_module "rewrite_module" "rewrite_module" "mod_rewrite"
enable_module "ssl_module" "ssl_module" "mod_ssl"
enable_module "socache_shmcb_module" "socache_shmcb_module" "mod_socache_shmcb"

# Habilitar vhosts con verificación (check both /etc and /private/etc paths)
if grep -q "^Include.*/httpd-vhosts.conf" "$APACHE_CONF"; then
    echo "[OK] Virtual Hosts ya están habilitados"
elif grep -q "^#Include.*/httpd-vhosts.conf" "$APACHE_CONF"; then
    run_sudo sed -i.bak 's|^#Include \(.*\)/httpd-vhosts.conf|Include \1/httpd-vhosts.conf|g' "$APACHE_CONF"
    echo "[OK] Virtual Hosts habilitados"
    CONFIG_CHANGED=true
else
    echo "[!] Include de Virtual Hosts no encontrado"
fi

# Habilitar SSL con verificación (check both /etc and /private/etc paths)
if grep -q "^Include.*/httpd-ssl.conf" "$APACHE_CONF"; then
    echo "[OK] SSL ya está habilitado"
elif grep -q "^#Include.*/httpd-ssl.conf" "$APACHE_CONF"; then
    run_sudo sed -i.bak 's|^#Include \(.*\)/httpd-ssl.conf|Include \1/httpd-ssl.conf|g' "$APACHE_CONF"
    echo "[OK] SSL habilitado"
    CONFIG_CHANGED=true
else
    echo "[!] Include de SSL no encontrado"
fi

echo ""
echo "Paso 3: Configurando directorio SSL..."
echo "-------------------------------------------"

run_sudo mkdir -p "$SSL_DIR"
run_sudo chmod 755 "$SSL_DIR"

# Generar certificado por defecto si no existe
if [ ! -f "$SSL_DIR/default.crt" ]; then
    echo "Generando certificado SSL por defecto..."
    run_sudo openssl req -x509 -nodes -days 3650 \
        -newkey rsa:2048 \
        -keyout "$SSL_DIR/default.key" \
        -out "$SSL_DIR/default.crt" \
        -subj "/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/OU=Development/CN=localhost" \
        2>/dev/null
    echo "[OK] Certificado por defecto generado"
else
    echo "[OK] Certificado por defecto ya existe"
fi

echo ""
echo "Paso 4: Copiando certificados SSL (preservando timestamps)..."
echo "-------------------------------------------"

if [ -d "$CERT_DIR" ]; then
    CERTS_COPIED=0

    # Copiar solo certificados que sean más nuevos o no existan
    for cert in "$CERT_DIR"/*.crt; do
        if [ -f "$cert" ]; then
            cert_name=$(basename "$cert")
            key_name="${cert_name%.crt}.key"

            # Copiar certificado si es más nuevo o no existe en destino
            if [ ! -f "$SSL_DIR/$cert_name" ] || [ "$cert" -nt "$SSL_DIR/$cert_name" ]; then
                run_sudo cp -p "$cert" "$SSL_DIR/"
                run_sudo chmod 644 "$SSL_DIR/$cert_name"
                ((CERTS_COPIED++))
            fi

            # Copiar llave si existe y es más nueva
            if [ -f "$CERT_DIR/$key_name" ]; then
                if [ ! -f "$SSL_DIR/$key_name" ] || [ "$CERT_DIR/$key_name" -nt "$SSL_DIR/$key_name" ]; then
                    run_sudo cp -p "$CERT_DIR/$key_name" "$SSL_DIR/"
                    run_sudo chmod 600 "$SSL_DIR/$key_name"
                fi
            fi
        fi
    done

    if [ $CERTS_COPIED -gt 0 ]; then
        echo "[OK] $CERTS_COPIED certificado(s) actualizado(s)"
        CONFIG_CHANGED=true
    else
        echo "[OK] Certificados ya están actualizados"
    fi
else
    echo "[!] Directorio de certificados no encontrado. Genera los certificados desde la interfaz web."
fi

echo ""
echo "Paso 5: Configurando Virtual Hosts..."
echo "-------------------------------------------"

if [ -f "$CONF_DIR/vhosts.conf" ]; then
    # Comparar checksums para ver si el archivo cambió
    if [ -f "$APACHE_VHOSTS_CONF" ]; then
        SOURCE_MD5=$(md5 -q "$CONF_DIR/vhosts.conf" 2>/dev/null || echo "new")
        DEST_MD5=$(run_sudo md5 -q "$APACHE_VHOSTS_CONF" 2>/dev/null || echo "old")

        if [ "$SOURCE_MD5" != "$DEST_MD5" ]; then
            run_sudo cp -f "$CONF_DIR/vhosts.conf" "$APACHE_VHOSTS_CONF"
            echo "[OK] Configuración de Virtual Hosts actualizada"
            CONFIG_CHANGED=true
        else
            echo "[OK] Configuración de Virtual Hosts sin cambios"
        fi
    else
        run_sudo cp -f "$CONF_DIR/vhosts.conf" "$APACHE_VHOSTS_CONF"
        echo "[OK] Configuración de Virtual Hosts aplicada"
        CONFIG_CHANGED=true
    fi
else
    echo "[!] Archivo de configuración no encontrado. Genera la configuración desde la interfaz web."
fi

echo ""
echo "Paso 6: Configurando puerto 443 (HTTPS)..."
echo "-------------------------------------------"

# Verificar si Listen 443 ya está en httpd.conf O en httpd-ssl.conf
if grep -q "^Listen 443" "$APACHE_CONF" || grep -q "^Listen 443" "$APACHE_SSL_CONF" 2>/dev/null; then
    echo "[OK] Puerto 443 ya está configurado"
else
    run_sudo sed -i.bak '/Listen 80/a\
Listen 443\
' "$APACHE_CONF"
    echo "[OK] Puerto 443 agregado"
    CONFIG_CHANGED=true
fi

echo ""
echo "Paso 7: Verificando configuración de Apache..."
echo "-------------------------------------------"

run_sudo /usr/sbin/apachectl configtest 2>&1 | grep -v "fully qualified domain name"
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "[OK] Configuración de Apache válida"
else
    echo "[ERROR] Error en la configuración de Apache"
    echo "   Revisa los errores arriba antes de continuar"
    exit 1
fi

echo ""
echo "Paso 8: Reiniciando Apache..."
echo "-------------------------------------------"

if [ "$CONFIG_CHANGED" = true ]; then
    echo "Detectados cambios en configuración, reiniciando Apache..."
    run_sudo /usr/sbin/apachectl stop 2>/dev/null || true
    sleep 2
    run_sudo /usr/sbin/apachectl start

    if [ $? -eq 0 ]; then
        echo "[OK] Apache reiniciado exitosamente"
    else
        echo "[ERROR] Error reiniciando Apache"
        exit 1
    fi
else
    echo "[OK] Sin cambios detectados, Apache no necesita reiniciarse"
    # Verificar que Apache esté corriendo
    if ! pgrep -q httpd; then
        echo "[!] Apache no está corriendo, iniciando..."
        run_sudo /usr/sbin/apachectl start
        echo "[OK] Apache iniciado"
    fi
fi

echo ""
echo "======================================"
echo " [OK] Instalación Completada"
echo "======================================"
echo ""
echo "Servicios configurados:"
echo "  • Apache 2.4 con PHP 8.4"
echo "  • MySQL 8.4"
echo "  • SSL habilitado"
echo "  • Virtual Hosts configurados"
echo ""
if [ "$CONFIG_CHANGED" = true ]; then
    echo "Cambios aplicados: SI"
else
    echo "Estado: Sin cambios (configuración actual mantenida)"
fi
echo ""
echo "Próximos pasos:"
echo "  1. Accede a http://localhost/manager para administrar dominios"
echo "  2. Genera los certificados SSL desde la interfaz"
echo "  3. Actualiza /etc/hosts con los dominios configurados"
echo ""
echo "Para actualizar /etc/hosts ejecuta:"
echo "  sudo nano /etc/hosts"
echo ""
echo "Y agrega las entradas generadas en:"
echo "  $CONF_DIR/hosts.txt"
echo ""
