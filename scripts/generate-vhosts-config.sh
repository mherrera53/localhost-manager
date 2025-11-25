#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Script para generar configuración de Virtual Hosts de Apache desde hosts.json
# Autor: Localhost Manager

OUTPUT_FILE="$HOME/localhost-manager/conf/vhosts.conf"
HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
CERT_DIR="$HOME/localhost-manager/certs"

echo "======================================"
echo " Generador de Virtual Hosts"
echo "======================================"
echo ""

# Verificar que existe hosts.json
if [ ! -f "$HOSTS_JSON" ]; then
    echo "Error: No se encontró $HOSTS_JSON"
    exit 1
fi

# Crear archivo de configuración
cat > "$OUTPUT_FILE" <<EOF
# Virtual Hosts - Generated $(date +"%Y-%m-%d %H:%M:%S")

<VirtualHost *:443>
    ServerName _default_
    SSLEngine on
    SSLCertificateFile "$CERT_DIR/default.crt"
    SSLCertificateKeyFile "$CERT_DIR/default.key"
    Redirect 404 /
</VirtualHost>

SSLStrictSNIVHostCheck off

EOF

# Procesar cada host del JSON usando PHP para parsear
# Usar PHP de Homebrew explícitamente (no el alias de MAMP)
/opt/homebrew/opt/php@8.3/bin/php -r '
$hostsFile = "'$HOSTS_JSON'";
$certDir = "'$CERT_DIR'";
$hosts = json_decode(file_get_contents($hostsFile), true);

foreach ($hosts as $domain => $config) {
    // Solo hosts activos
    if (!isset($config["active"]) || $config["active"] !== true) {
        continue;
    }

    $docroot = $config["docroot"];
    $aliases = isset($config["aliases"]) && is_array($config["aliases"]) ? $config["aliases"] : [];

    // Construir lista de aliases activos
    $activeAliases = [];
    foreach ($aliases as $alias) {
        if (is_string($alias) && !empty(trim($alias))) {
            $activeAliases[] = $alias;
        } elseif (is_array($alias) && isset($alias["value"]) && !empty(trim($alias["value"]))) {
            $isActive = !isset($alias["active"]) || $alias["active"] === true;
            if ($isActive) {
                $activeAliases[] = $alias["value"];
            }
        }
    }

    // VirtualHost HTTP (puerto 80) - Redirige a HTTPS
    echo "\n<VirtualHost *:80>\n";
    echo "    ServerName $domain\n";
    foreach ($activeAliases as $alias) {
        echo "    ServerAlias $alias\n";
    }
    echo "    Redirect permanent / https://$domain/\n";
    echo "</VirtualHost>\n";

    // VirtualHost HTTPS (puerto 443)
    echo "\n<VirtualHost *:443>\n";
    echo "    ServerName $domain\n";
    foreach ($activeAliases as $alias) {
        echo "    ServerAlias $alias\n";
    }

    echo "    DocumentRoot \"$docroot\"\n";
    echo "\n";
    echo "    <Directory \"$docroot\">\n";
    echo "        Options Indexes FollowSymLinks\n";
    echo "        AllowOverride All\n";
    echo "        Require all granted\n";
    echo "    </Directory>\n";
    echo "\n";
    echo "    <FilesMatch \.php$>\n";
    echo "        SetHandler \"proxy:fcgi://127.0.0.1:9000\"\n";
    echo "    </FilesMatch>\n";
    echo "\n";
    echo "    SSLEngine on\n";
    echo "    SSLCertificateFile \"$certDir/{$domain}.crt\"\n";
    echo "    SSLCertificateKeyFile \"$certDir/{$domain}.key\"\n";
    echo "</VirtualHost>\n";
}
' >> "$OUTPUT_FILE"

echo ""
echo "======================================"
echo " Configuración generada exitosamente"
echo "======================================"
echo "Archivo: $OUTPUT_FILE"
echo ""
echo "Para aplicar la configuración ejecuta:"
echo "  bash ~/localhost-manager/scripts/install.sh"
echo ""
