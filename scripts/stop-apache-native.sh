#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Stop macOS native Apache.
# Elevation is requested via osascript (Touch ID / GUI prompt) -- we never
# store or pipe a sudo password.

echo "Stopping native macOS Apache..."
if osascript -e 'do shell script "/usr/sbin/apachectl stop" with administrator privileges' 2>&1; then
    echo "[OK] Apache stopped"
else
    echo "[i]  Apache already stopped or could not be stopped"
fi
