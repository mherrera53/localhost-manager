#!/bin/bash

# Script para actualizar /etc/hosts desde hosts.json
# Ejecutar con: sudo bash update-hosts.sh

HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"

if [ "$EUID" -ne 0 ]; then
    echo "Por favor ejecuta con sudo: sudo bash update-hosts.sh"
    exit 1
fi

if [ ! -f "$HOSTS_JSON" ]; then
    echo "Error: No se encontró $HOSTS_JSON"
    exit 1
fi

# Backup del archivo hosts original
cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)

# Eliminar entradas antiguas de Localhost Manager
sed -i '' '/# Localhost Manager/,/# End Localhost Manager/d' /etc/hosts 2>/dev/null || true

# Generar nuevas entradas dinámicamente desde hosts.json
echo "##" >> /etc/hosts
echo "# Localhost Manager - Hosts Configuration" >> /etc/hosts
echo "# Generado: $(date +"%Y-%m-%d %H:%M:%S")" >> /etc/hosts
echo "##" >> /etc/hosts
echo "" >> /etc/hosts

# Usar PHP para parsear hosts.json y generar entradas
/opt/homebrew/opt/php@8.3/bin/php -r '
$hostsFile = "'$HOSTS_JSON'";
$hosts = json_decode(file_get_contents($hostsFile), true);

foreach ($hosts as $domain => $config) {
    // Solo hosts activos
    if (!isset($config["active"]) || $config["active"] !== true) {
        continue;
    }

    $aliases = isset($config["aliases"]) && is_array($config["aliases"]) ? $config["aliases"] : [];

    // Crear línea con dominio principal
    $line = "127.0.0.1    $domain";

    // Agregar aliases activos
    foreach ($aliases as $alias) {
        // Soporte para aliases como strings o como objetos con estado
        if (is_string($alias) && !empty(trim($alias))) {
            $line .= "    " . trim($alias);
        } elseif (is_array($alias) && isset($alias["value"]) && !empty(trim($alias["value"]))) {
            // Solo agregar si está activo (por defecto true si no está definido)
            $isActive = !isset($alias["active"]) || $alias["active"] === true;
            if ($isActive) {
                $line .= "    " . trim($alias["value"]);
            }
        }
    }

    echo $line . "\n";
}
' >> /etc/hosts

echo "" >> /etc/hosts
echo "# End Localhost Manager" >> /etc/hosts
echo "" >> /etc/hosts

echo "✓ /etc/hosts actualizado exitosamente con $(grep -c '127.0.0.1' /etc/hosts | tail -1) entradas"
