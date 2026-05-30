#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Start macOS native Apache.
# Elevation is requested via osascript (Touch ID / GUI prompt) -- we never
# store or pipe a sudo password. Binding to ports 80/443 requires root.

echo "Starting native macOS Apache..."
if osascript -e 'do shell script "/usr/sbin/apachectl start" with administrator privileges' 2>&1; then
    echo "[OK] Apache started"
else
    echo "[i]  Apache already running or could not be started"
fi
