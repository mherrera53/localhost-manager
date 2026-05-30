#!/bin/bash

HOME_DIR="$HOME"
CONFIG_FILE="$HOME_DIR/localhost-manager/app-config.json"

if [ -f "$CONFIG_FILE" ]; then
    SCRIPTS_BASE_PATH=$(/opt/homebrew/opt/php@8.4/bin/php -r "echo json_decode(file_get_contents('$CONFIG_FILE'))->scripts_base_path;")
else
    SCRIPTS_BASE_PATH="$HOME_DIR/PARA/3_Recursos/Tools/localhost-manager/scripts"
fi

# This script must be run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

echo "Applying all configurations..."

# 1. Generate SSL certificates (run as user, not root)
echo "[1/4] Generating SSL certificates..."
sudo -u $SUDO_USER bash "$SCRIPTS_BASE_PATH/generate-certificates.sh" 2>/dev/null || echo "  (some certs may have been skipped)"

# 2. Update /etc/hosts
echo "[2/4] Updating /etc/hosts..."
bash "$SCRIPTS_BASE_PATH/update-hosts.sh"

# 3. Generate Apache vhosts
echo "[3/5] Generating Apache vhosts..."
sudo -u $SUDO_USER bash "$SCRIPTS_BASE_PATH/generate-vhosts-config.sh"

# 4. Sync generated vhosts to Apache's extra dir
echo "[4/5] Syncing vhosts to Apache..."
GENERATED_VHOSTS="$HOME_DIR/localhost-manager/conf/vhosts.conf"
APACHE_VHOSTS="/etc/apache2/extra/vhosts.conf"
if [ -f "$GENERATED_VHOSTS" ]; then
    cp -f "$GENERATED_VHOSTS" "$APACHE_VHOSTS"
    echo "  ✓ Synced to $APACHE_VHOSTS"
else
    echo "  Warning: Generated vhosts file not found"
fi

# 5. Restart Apache (check config first)
echo "[5/5] Restarting Apache..."
if apachectl configtest 2>/dev/null; then
    apachectl graceful
else
    echo "  Warning: Apache config has errors, skipping restart"
    apachectl configtest 2>&1 | head -5
fi

echo "✓ All configurations applied successfully!"
