#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Restart macOS native Apache.
# Elevation via sudo, which uses pam_tid.so (Touch ID) -- we never store or
# pipe a password.

echo "Restarting native macOS Apache..."
if sudo /usr/sbin/apachectl restart 2>&1; then
    echo "[OK] Apache restarted"
else
    echo "[X] Could not restart Apache"
    exit 1
fi
