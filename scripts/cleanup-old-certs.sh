#!/bin/bash

# Localhost Manager - Cleanup Old Certificates
# Removes old self-signed certificates from keychain and regenerates with Root CA

set -e

USER_HOME="$HOME"
CERT_DIR="$USER_HOME/localhost-manager/certs"
CONF_DIR="$USER_HOME/localhost-manager/conf"
HOSTS_FILE="$CONF_DIR/hosts.json"

echo "=== Localhost Manager Certificate Cleanup ==="
echo ""
echo "This script will:"
echo "1. Remove old self-signed certificates from System Keychain"
echo "2. Delete old certificate files (to regenerate with Root CA)"
echo ""
echo "This requires sudo access."
echo ""

# Get domains from hosts.json
if [ -f "$HOSTS_FILE" ]; then
    DOMAINS=$(jq -r 'keys[]' "$HOSTS_FILE" 2>/dev/null)
else
    echo "Warning: hosts.json not found, using default domains"
    DOMAINS="localhost vendors.jirafazul.com app.anysubscriptions.com latam.paygateway-api.com isi.hospital afiliacionesneonet.com.gt"
fi

# Add some known old domains
DOMAINS="$DOMAINS localhost Localhost"

echo "=== Removing old certificates from System Keychain ==="

# Create a temporary script for sudo
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash
remove_cert() {
    local name="$1"
    local count=0
    while security find-certificate -c "$name" /Library/Keychains/System.keychain >/dev/null 2>&1; do
        security delete-certificate -c "$name" /Library/Keychains/System.keychain 2>/dev/null || break
        count=$((count + 1))
        if [ $count -gt 10 ]; then
            break  # Safety limit
        fi
    done
    if [ $count -gt 0 ]; then
        echo "  Removed $count certificate(s) for: $name"
    fi
}
EOF

# Add domain removal commands
for domain in $DOMAINS; do
    echo "remove_cert \"$domain\"" >> "$TEMP_SCRIPT"
    # Also try with quotes (old bug format)
    echo "remove_cert \"'$domain'\"" >> "$TEMP_SCRIPT"
done

# Execute cleanup
sudo bash "$TEMP_SCRIPT"
rm -f "$TEMP_SCRIPT"

echo "  Keychain cleanup complete"

echo ""
echo "=== Removing old certificate files ==="
# Remove all .crt and .key files EXCEPT LocalRootCA
if [ -d "$CERT_DIR" ]; then
    find "$CERT_DIR" -type f \( -name "*.crt" -o -name "*.key" \) ! -name "LocalRootCA.*" -delete 2>/dev/null || true
    echo "  Old certificate files removed from $CERT_DIR"
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Now run:"
echo "  bash ~/localhost-manager/scripts/generate-all.sh"
echo "  bash ~/localhost-manager/scripts/install.sh"
echo ""
echo "This will create new certificates signed by the Root CA."
