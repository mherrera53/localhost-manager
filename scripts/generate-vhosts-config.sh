#!/bin/bash
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

OUTPUT_FILE="$HOME/localhost-manager/conf/vhosts.conf"
HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
CERT_DIR="$HOME/localhost-manager/certs"

echo "======================================"
echo " Generador de Virtual Hosts"
echo "======================================"
echo ""

if [ ! -f "$HOSTS_JSON" ]; then
    echo "Error: No se encontró $HOSTS_JSON"
    exit 1
fi

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

/opt/homebrew/opt/php@8.4/bin/php -r '
$hostsFile = "'$HOSTS_JSON'";
$certDir = "'$CERT_DIR'";
$hosts = json_decode(file_get_contents($hostsFile), true);

foreach ($hosts as $domain => $config) {
    if (!isset($config["active"]) || $config["active"] !== true) {
        continue;
    }
    
    $stack = isset($config["stack"]) ? $config["stack"] : "frontend";
    $mode = isset($config["mode"]) ? $config["mode"] : "local";
    
    $docroot = $config["docroot"];
    $aliases = isset($config["aliases"]) && is_array($config["aliases"]) ? $config["aliases"] : [];
    
    // Aliases follow the parent: this domain is active, so serve ALL its
    // aliases (whitelabel domains all point to the same docroot). The per-alias
    // "active" flag is intentionally ignored -- the parent drives it.
    $activeAliases = [];
    foreach ($aliases as $alias) {
        if (is_string($alias) && !empty(trim($alias))) {
            $activeAliases[] = trim($alias);
        } elseif (is_array($alias) && isset($alias["value"]) && !empty(trim($alias["value"]))) {
            $activeAliases[] = trim($alias["value"]);
        }
    }
    
// Treat port 80/443 as null (those are Apache own ports, proxying to them causes loops)
    $rawPort = isset($config["port"]) ? $config["port"] : null;
    if ($rawPort == 80 || $rawPort == 443) {
        $rawPort = null;
    }

// BACKEND PROJECT with PROXY (only proxy when port is set and valid)
    if ($stack === "backend" && $rawPort !== null) {
        $port = $rawPort;
        
        // HTTP redirect to HTTPS
        echo "\n<VirtualHost *:80>\n";
        echo "    ServerName $domain\n";
        foreach ($activeAliases as $alias) {
            echo "    ServerAlias $alias\n";
        }
        echo "    Redirect permanent / https://$domain/\n";
        echo "</VirtualHost>\n";
        
        // HTTPS with proxy
        echo "\n<VirtualHost *:443>\n";
        echo "    ServerName $domain\n";
        foreach ($activeAliases as $alias) {
            echo "    ServerAlias $alias\n";
        }
        echo "\n";
        echo "    SSLEngine on\n";
        echo "    SSLCertificateFile \"$certDir/{$domain}.crt\"\n";
        echo "    SSLCertificateKeyFile \"$certDir/{$domain}.key\"\n";
        echo "\n";
        echo "    ProxyPreserveHost On\n";
        echo "    ProxyPass / http://localhost:$port/\n";
        echo "    ProxyPassReverse / http://localhost:$port/\n";
        echo "\n";
        echo "    # WebSocket support for HMR\n";
        echo "    RewriteEngine on\n";
        echo "    RewriteCond %{HTTP:Upgrade} websocket [NC]\n";
        echo "    RewriteCond %{HTTP:Connection} upgrade [NC]\n";
        echo "    RewriteRule ^/?(.*) \"ws://localhost:$port/\$1\" [P,L]\n";
        echo "</VirtualHost>\n";
        
        continue;
    }
    
    // FRONTEND/STATIC PROJECT or BACKEND without valid proxy port (traditional PHP/static)
    if ($stack === "frontend" || $stack === "static" || ($stack === "backend" && $rawPort === null)) {
        // HTTP redirect to HTTPS
        echo "\n<VirtualHost *:80>\n";
        echo "    ServerName $domain\n";
        foreach ($activeAliases as $alias) {
            echo "    ServerAlias $alias\n";
        }
        echo "    Redirect permanent / https://$domain/\n";
        echo "</VirtualHost>\n";
        
        // HTTPS with PHP-FPM
        echo "\n<VirtualHost *:443>\n";
        echo "    ServerName $domain\n";
        foreach ($activeAliases as $alias) {
            echo "    ServerAlias $alias\n";
        }
        echo "\n";
        echo "    DocumentRoot \"$docroot\"\n";
        echo "\n";
        echo "    <Directory \"$docroot\">\n";
        echo "        Options Indexes FollowSymLinks\n";
        echo "        AllowOverride All\n";
        echo "        Require all granted\n";
        echo "    </Directory>\n";
        echo "\n";
        
        $phpVersion = isset($config["php_version"]) ? $config["php_version"] : "8.3";
        $phpPort = 9000;
        
        $phpPorts = [
            "8.4" => 9000,
            "8.3" => 9000,
            "8.2" => 9002,
            "8.1" => 9001,
            "8.0" => 9003,
            "7.4" => 9004,
        ];
        
        if (isset($phpPorts[$phpVersion])) {
            $phpPort = $phpPorts[$phpVersion];
        }
        
        echo "    # PHP $phpVersion via PHP-FPM\n";
        echo "    <FilesMatch \.php$>\n";
        echo "        SetHandler \"proxy:fcgi://127.0.0.1:$phpPort\"\n";
        echo "    </FilesMatch>\n";
        echo "\n";
        echo "    SSLEngine on\n";
        echo "    SSLCertificateFile \"$certDir/{$domain}.crt\"\n";
        echo "    SSLCertificateKeyFile \"$certDir/{$domain}.key\"\n";
        echo "</VirtualHost>\n";
    }
}
' >> "$OUTPUT_FILE"

echo ""
echo "======================================"
echo " Configuración generada exitosamente"
echo "======================================"
echo "Archivo: $OUTPUT_FILE"
echo ""
