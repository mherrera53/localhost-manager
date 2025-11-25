#!/bin/bash

# Script para generar certificados SSL autofirmados desde hosts.json
# Autor: Localhost Manager

CERT_DIR="$HOME/localhost-manager/certs"
HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
DAYS_VALID=3650  # 10 años

echo "======================================"
echo " Generador de Certificados SSL"
echo "======================================"
echo ""

# Verificar que existe hosts.json
if [ ! -f "$HOSTS_JSON" ]; then
    echo "Error: No se encontró $HOSTS_JSON"
    exit 1
fi

# Crear directorio de certificados si no existe
mkdir -p "$CERT_DIR"

# Generar certificado por defecto
echo "Generando certificado por defecto..."
openssl req -x509 -nodes -days $DAYS_VALID \
    -newkey rsa:2048 \
    -keyout "$CERT_DIR/default.key" \
    -out "$CERT_DIR/default.crt" \
    -subj "/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/OU=Development/CN=localhost" \
    -addext "subjectAltName = DNS:localhost,DNS:*.localhost" \
    2>/dev/null
echo "  ✓ Certificado por defecto generado"
echo ""

# Leer dominios desde hosts.json y generar certificados
php -r '
$hostsFile = "'$HOSTS_JSON'";
$hosts = json_decode(file_get_contents($hostsFile), true);

$count = 0;

foreach ($hosts as $domain => $config) {
    // Solo hosts activos
    if (!isset($config["active"]) || $config["active"] !== true) {
        continue;
    }

    $aliases = isset($config["aliases"]) && is_array($config["aliases"]) ? $config["aliases"] : [];

    // Construir Subject Alternative Names (SANs)
    $sans = ["DNS:$domain"];

    // Agregar aliases activos como SANs
    foreach ($aliases as $alias) {
        if (is_string($alias) && !empty(trim($alias))) {
            $sans[] = "DNS:" . trim($alias);
        } elseif (is_array($alias) && isset($alias["value"]) && !empty(trim($alias["value"]))) {
            $isActive = !isset($alias["active"]) || $alias["active"] === true;
            if ($isActive) {
                $sans[] = "DNS:" . trim($alias["value"]);
            }
        }
    }

    $sanString = implode(",", $sans);

    echo "Generando certificado para: $domain\n";
    echo "  SANs: $sanString\n";

    // Generar certificado con todos los SANs
    $certDir = "'$CERT_DIR'";
    $daysValid = "'$DAYS_VALID'";

    exec("openssl req -x509 -nodes -days $daysValid " .
         "-newkey rsa:2048 " .
         "-keyout \"$certDir/{$domain}.key\" " .
         "-out \"$certDir/{$domain}.crt\" " .
         "-subj \"/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/OU=Development/CN=$domain\" " .
         "-addext \"subjectAltName = $sanString\" " .
         "2>/dev/null", $output, $returnCode);

    if ($returnCode === 0) {
        echo "  ✓ Certificado generado: {$domain}.crt\n";
        echo "  ✓ Clave privada generada: {$domain}.key\n";
        $count++;
    } else {
        echo "  ✗ Error generando certificado para $domain\n";
    }
    echo "\n";
}

echo "======================================\n";
echo " Resumen\n";
echo "======================================\n";
echo "Total de certificados generados: $count\n";
echo "Ubicación: '$CERT_DIR'\n";
echo "\n";
echo "Los certificados son válidos por $DAYS_VALID días (10 años)\n";
echo "\n";
'
