#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"

# Start macOS native Apache.
# Elevation via sudo, which uses pam_tid.so (Touch ID) -- we never store or
# pipe a password. Binding to ports 80/443 requires root.

echo "Starting native macOS Apache..."
if sudo /usr/sbin/apachectl start 2>&1; then
    echo "[OK] Apache started"
else
    echo "[i]  Apache already running or could not be started"
fi
