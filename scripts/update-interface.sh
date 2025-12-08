#!/bin/bash

SUDO_PASSWORD=$(security find-generic-password -a "$USER" -s "localhost-manager-sudo" -w 2>/dev/null)

# Backup
echo "$SUDO_PASSWORD" | sudo -S cp /Library/WebServer/Documents/manager/index.php /Library/WebServer/Documents/manager/index.php.$(date +%Y%m%d-%H%M%S)

# Copy new version (use index-new.php which has the Tabler interface)
echo "$SUDO_PASSWORD" | sudo -S cp /Users/mario/Sites/localhost/manager/index-new.php /Library/WebServer/Documents/manager/index.php

# Permissions
echo "$SUDO_PASSWORD" | sudo -S chmod 755 /Library/WebServer/Documents/manager/index.php

echo "Interface updated. Refresh your browser."
