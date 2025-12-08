#!/bin/bash

# ============================================
# SSL Certificate Generator - Optimized
# Localhost Manager
# ============================================
# Features:
# - No PHP dependency (uses jq or python fallback)
# - Certificate caching (skip valid certs)
# - Better error handling
# - Wildcard support
# - IP SAN support (127.0.0.1)
# ============================================

set -e

# Configuration
CERT_DIR="${CERT_DIR:-$HOME/localhost-manager/certs}"
HOSTS_JSON="${HOSTS_JSON:-$HOME/localhost-manager/conf/hosts.json}"
DAYS_VALID=3650  # 10 years
MIN_DAYS_REMAINING=30  # Regenerate if less than this many days remain

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
GENERATED=0
SKIPPED=0
FAILED=0

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  SSL Certificate Generator${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# Check if certificate is still valid (not expiring soon)
cert_is_valid() {
    local cert_file="$1"
    local min_days="${2:-$MIN_DAYS_REMAINING}"

    [ ! -f "$cert_file" ] && return 1

    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2) || return 1
    [ -z "$expiry_date" ] && return 1

    local expiry_epoch current_epoch min_epoch

    # Convert dates to epoch (cross-platform)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" "+%s" 2>/dev/null) || return 1
    else
        expiry_epoch=$(date -d "$expiry_date" "+%s" 2>/dev/null) || return 1
    fi

    current_epoch=$(date "+%s")
    min_epoch=$((current_epoch + min_days * 86400))

    [ "$expiry_epoch" -gt "$min_epoch" ]
}

# Generate a single certificate
generate_cert() {
    local domain="$1"
    local san_list="$2"
    local cert_file="$CERT_DIR/${domain}.crt"
    local key_file="$CERT_DIR/${domain}.key"

    # Check if certificate already exists and is valid
    if cert_is_valid "$cert_file"; then
        echo -e "  ${YELLOW}⊘${NC} $domain (valid, skipped)"
        ((SKIPPED++))
        return 0
    fi

    # Build SAN string
    local san_string="DNS:${domain}"

    # Add aliases to SAN
    if [ -n "$san_list" ]; then
        IFS=',' read -ra SANS <<< "$san_list"
        for san in "${SANS[@]}"; do
            san=$(echo "$san" | xargs 2>/dev/null || echo "$san")
            [ -n "$san" ] && san_string="${san_string},DNS:${san}"
        done
    fi

    # Add wildcard and IP
    san_string="${san_string},DNS:*.${domain},IP:127.0.0.1"

    # Generate certificate
    if openssl req -x509 -nodes -days "$DAYS_VALID" \
        -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -subj "/C=US/ST=Development/L=LocalDev/O=Localhost Manager/OU=Development/CN=${domain}" \
        -addext "subjectAltName = ${san_string}" \
        -addext "basicConstraints = CA:FALSE" \
        -addext "keyUsage = nonRepudiation, digitalSignature, keyEncipherment" \
        2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $domain"
        ((GENERATED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $domain (failed)"
        ((FAILED++))
        return 1
    fi
}

# Parse JSON using jq or python (no PHP dependency)
get_active_domains() {
    local json_file="$1"

    if command -v jq &> /dev/null; then
        jq -r 'to_entries | .[] | select(.value.active == true or .value.active == null) | .key' "$json_file" 2>/dev/null
    elif command -v python3 &> /dev/null; then
        python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
for domain, config in data.items():
    if config.get('active', True):
        print(domain)
" 2>/dev/null
    elif command -v python &> /dev/null; then
        python -c "
import json
with open('$json_file') as f:
    data = json.load(f)
for domain, config in data.items():
    if config.get('active', True):
        print(domain)
" 2>/dev/null
    else
        echo ""
    fi
}

get_domain_aliases() {
    local json_file="$1"
    local domain="$2"

    if command -v jq &> /dev/null; then
        jq -r ".[\"$domain\"].aliases // [] |
            if type == \"array\" then
                map(if type == \"string\" then .
                    elif type == \"object\" and (.active == true or .active == null) then .value
                    else empty end) | join(\",\")
            else \"\" end" "$json_file" 2>/dev/null
    elif command -v python3 &> /dev/null; then
        python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
aliases = data.get('$domain', {}).get('aliases', [])
result = []
for a in aliases:
    if isinstance(a, str) and a:
        result.append(a)
    elif isinstance(a, dict) and a.get('active', True) and a.get('value'):
        result.append(a['value'])
print(','.join(result))
" 2>/dev/null
    else
        echo ""
    fi
}

# Generate default certificate for localhost
echo -e "${YELLOW}[1/2]${NC} Generating default certificate..."
generate_cert "default" "localhost"
echo ""

# Check if hosts.json exists
if [ ! -f "$HOSTS_JSON" ]; then
    echo -e "${YELLOW}No hosts.json found at $HOSTS_JSON${NC}"
    echo -e "${YELLOW}Only default certificate was generated${NC}"
    exit 0
fi

# Process hosts from JSON
echo -e "${YELLOW}[2/2]${NC} Processing hosts..."
echo ""

domains=$(get_active_domains "$HOSTS_JSON")

if [ -z "$domains" ]; then
    echo -e "${YELLOW}No active hosts found in hosts.json${NC}"
else
    while IFS= read -r domain; do
        [ -z "$domain" ] && continue

        # Get aliases for this domain
        aliases=$(get_domain_aliases "$HOSTS_JSON" "$domain")

        # Generate certificate
        generate_cert "$domain" "$aliases"
    done <<< "$domains"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "  Generated: ${GREEN}$GENERATED${NC}"
echo -e "  Skipped:   ${YELLOW}$SKIPPED${NC}"
echo -e "  Failed:    ${RED}$FAILED${NC}"
echo ""
echo -e "Location: $CERT_DIR"
echo -e "Validity: $DAYS_VALID days"
echo ""

# Exit with error if any failed
[ "$FAILED" -gt 0 ] && exit 1
exit 0
