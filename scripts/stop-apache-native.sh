#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Stop macOS native Apache.
# Elevation via sudo, which uses pam_tid.so (Touch ID) -- we never store or
# pipe a password.

echo "Stopping native macOS Apache..."
if sudo /usr/sbin/apachectl stop 2>&1; then
    echo "[OK] Apache stopped"
else
    echo "[i]  Apache already stopped or could not be stopped"
fi
