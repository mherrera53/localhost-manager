#!/bin/bash

# Script para actualizar /etc/hosts desde hosts.json
# Ejecutar con: sudo bash update-hosts.sh

HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
MARKER_START="# BEGIN Localhost Manager"
MARKER_END="# END Localhost Manager"

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

# Build the new managed section into a temp file
TMPFILE=$(mktemp)

echo "$MARKER_START" > "$TMPFILE"
echo "# Generado: $(date +"%Y-%m-%d %H:%M:%S")" >> "$TMPFILE"

/opt/homebrew/opt/php@8.4/bin/php -r '
$hostsFile = "'$HOSTS_JSON'";
$hosts = json_decode(file_get_contents($hostsFile), true);

foreach ($hosts as $domain => $config) {
    if (!isset($config["active"]) || $config["active"] !== true) {
        continue;
    }

    $stack = isset($config["stack"]) ? $config["stack"] : "frontend";
    if ($stack === "backend") {
        $port = isset($config["port"]) ? $config["port"] : 3000;
        echo "# Backend: $domain (port $port)\n";
    }

    $aliases = isset($config["aliases"]) && is_array($config["aliases"]) ? $config["aliases"] : [];

    $line = "127.0.0.1    $domain";

    // Aliases follow the parent: the domain is active, so map ALL its aliases
    // to 127.0.0.1 too. The per-alias "active" flag is ignored on purpose.
    foreach ($aliases as $alias) {
        if (is_string($alias) && !empty(trim($alias))) {
            $line .= "    " . trim($alias);
        } elseif (is_array($alias) && isset($alias["value"]) && !empty(trim($alias["value"]))) {
            $line .= "    " . trim($alias["value"]);
        }
    }

    echo $line . "\n";
}
' >> "$TMPFILE"

echo "$MARKER_END" >> "$TMPFILE"

# Remove old managed section (handles both old and new marker formats)
# Also remove orphan ## lines left by previous buggy versions
sed -i '' '/# Localhost Manager/,/# End Localhost Manager/d' /etc/hosts 2>/dev/null || true
sed -i '' '/# BEGIN Localhost Manager/,/# END Localhost Manager/d' /etc/hosts 2>/dev/null || true

# Clean up orphan ## lines (not the ones in the standard header)
# Remove consecutive blank lines and orphan ## at end of file
/opt/homebrew/opt/php@8.4/bin/php -r '
$lines = file("/etc/hosts", FILE_IGNORE_NEW_LINES);
$out = [];
$seenContent = false;
$headerDone = false;
$blankCount = 0;

foreach ($lines as $i => $line) {
    $trimmed = trim($line);

    // Detect when we are past the standard macOS header (after ::1 localhost)
    if (!$headerDone && preg_match("/^::1\s+localhost$/", $trimmed)) {
        $headerDone = true;
        $out[] = $line;
        continue;
    }

    if (!$headerDone) {
        $out[] = $line;
        continue;
    }

    // Past header: skip orphan "##" lines (they have no content purpose)
    if ($trimmed === "##") {
        continue;
    }

    // Collapse multiple blank lines into one
    if ($trimmed === "") {
        $blankCount++;
        if ($blankCount <= 1) {
            $out[] = $line;
        }
        continue;
    }

    $blankCount = 0;
    $out[] = $line;
}

// Remove trailing blank lines
while (count($out) > 0 && trim(end($out)) === "") {
    array_pop($out);
}

file_put_contents("/etc/hosts", implode("\n", $out) . "\n");
' 2>/dev/null || true

# Append the new managed section
echo "" >> /etc/hosts
cat "$TMPFILE" >> /etc/hosts
echo "" >> /etc/hosts

rm -f "$TMPFILE"

ACTIVE_COUNT=$(grep -c '127.0.0.1' /etc/hosts 2>/dev/null || echo 0)
echo "[OK] /etc/hosts actualizado exitosamente con $ACTIVE_COUNT entradas"

# Flush DNS so the new /etc/hosts takes effect immediately (no stale cache).
# We run as root here, so mDNSResponder can be reset directly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/flush-dns.sh" ]; then
    bash "$SCRIPT_DIR/flush-dns.sh"
else
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
    echo "[OK] DNS cache flushed"
fi
