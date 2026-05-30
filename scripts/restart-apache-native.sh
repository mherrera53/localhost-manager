#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Restart macOS native Apache.
# Elevation is requested via osascript (Touch ID / GUI prompt) -- we never
# store or pipe a sudo password.

echo "Restarting native macOS Apache..."
if osascript -e 'do shell script "/usr/sbin/apachectl restart" with administrator privileges' 2>&1; then
    echo "[OK] Apache restarted"
else
    echo "[X] Could not restart Apache"
    exit 1
fi
