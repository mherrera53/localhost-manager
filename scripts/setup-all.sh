#!/bin/bash

HOME_DIR="$HOME"
CONFIG_FILE="$HOME_DIR/localhost-manager/app-config.json"

if [ -f "$CONFIG_FILE" ]; then
    SCRIPTS_BASE_PATH=$(/opt/homebrew/opt/php@8.4/bin/php -r "echo json_decode(file_get_contents('$CONFIG_FILE'))->scripts_base_path;")
else
    SCRIPTS_BASE_PATH="$HOME_DIR/PARA/3_Recursos/Tools/localhost-manager/scripts"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Localhost Manager - Complete Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Auto-configure all repositories
echo "[1/5] Auto-configuring repositories..."
bash "$SCRIPTS_BASE_PATH/auto-configure-repos.sh"
echo "✓ Repositories configured"
echo ""

# 2. Generate vhosts configuration
echo "[2/5] Generating Apache vhosts..."
bash "$SCRIPTS_BASE_PATH/generate-vhosts-config.sh"
echo "✓ VHosts generated"
echo ""

# 3. Generate SSL certificates
echo "[3/5] Generating SSL certificates..."
bash "$SCRIPTS_BASE_PATH/generate-certificates.sh"
echo "✓ Certificates generated"
echo ""

# 4. Update /etc/hosts file
echo "[4/5] Updating /etc/hosts..."
bash "$SCRIPTS_BASE_PATH/update-hosts.sh"
echo "✓ Hosts file updated"
echo ""

# 5. Configure Apache to use vhosts.conf
echo "[5/5] Configuring Apache..."

# Clear old vhosts file
sudo sh -c 'echo "" > /private/etc/apache2/extra/httpd-vhosts.conf'

# Ensure localhost-manager vhosts.conf is included (path is dynamic, $HOME-based)
VHOSTS_INCLUDE="${HOME_DIR}/localhost-manager/conf/vhosts.conf"
if ! sudo grep -q "localhost-manager/conf/vhosts.conf" /private/etc/apache2/httpd.conf; then
    sudo sh -c 'echo "" >> /private/etc/apache2/httpd.conf'
    sudo sh -c 'echo "# Localhost Manager Virtual Hosts" >> /private/etc/apache2/httpd.conf'
    sudo sh -c "echo 'Include ${VHOSTS_INCLUDE}' >> /private/etc/apache2/httpd.conf"
fi

# Restart Apache
sudo apachectl restart

echo "✓ Apache configured"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All repositories are configured and Apache is ready."
echo "Use 'switch-mode.sh local' to start dev servers with Apache proxy."
