#!/bin/bash

# ============================================
# Flush macOS DNS cache
# Localhost Manager
# ============================================
# Run this after /etc/hosts changes or when activating/deactivating LOCAL mode
# so the OS and browsers re-resolve hostnames immediately instead of serving a
# stale cache (e.g. a domain that previously resolved to Cloudflare/production
# keeping that IP after being pointed to 127.0.0.1, or vice versa).
#
# Safe to run as root or as a normal user:
#   - dscacheutil -flushcache       works without root on modern macOS
#   - killall -HUP mDNSResponder    needs root; we use sudo -n when not root

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[DNS]${NC} Flushing DNS cache..."

# 1. Flush the directory service cache (no root needed)
dscacheutil -flushcache 2>/dev/null || true

# 2. Signal mDNSResponder to drop its cache (needs root)
if [ "$(id -u)" -eq 0 ]; then
    killall -HUP mDNSResponder 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} DNS cache flushed (mDNSResponder reset)"
else
    # -n = non-interactive: never hang waiting for a password in automated runs
    if sudo -n killall -HUP mDNSResponder 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC} DNS cache flushed (mDNSResponder reset)"
    else
        echo -e "${GREEN}[OK]${NC} dscacheutil flushed."
        echo -e "${YELLOW}[DNS]${NC} For a full reset run: sudo killall -HUP mDNSResponder"
    fi
fi

exit 0
