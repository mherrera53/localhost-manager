#!/bin/bash

# ============================================
# SSL Certificate Generator with Root CA
# Localhost Manager
# ============================================
# Features:
# - Local Root CA for browser trust
# - Certificate caching (skip valid certs)
# - Better error handling
# - Wildcard support
# - IP SAN support (127.0.0.1)
# ============================================

set -e

# Configuration
CERT_DIR="${CERT_DIR:-$HOME/localhost-manager/certs}"
HOSTS_JSON="${HOSTS_JSON:-$HOME/localhost-manager/conf/hosts.json}"
DAYS_VALID=730       # 2 years for domain certs
CA_DAYS_VALID=3650   # 10 years for Root CA
MIN_DAYS_REMAINING=30

# Root CA files
CA_KEY="$CERT_DIR/LocalRootCA.key"
CA_CERT="$CERT_DIR/LocalRootCA.crt"
CA_NAME="LocalDev Root CA"

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
echo -e "${BLUE}  with Local Root CA${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# ============================================
# STEP 1: Create Root CA if not exists
# ============================================
create_root_ca() {
    if [ -f "$CA_CERT" ] && [ -f "$CA_KEY" ]; then
        echo -e "${YELLOW}[Root CA]${NC} Already exists, skipping creation"
        return 0
    fi

    echo -e "${YELLOW}[Root CA]${NC} Creating Local Root CA..."

    # Generate CA private key (4096 bits for security)
    openssl genrsa -out "$CA_KEY" 4096 2>/dev/null

    # Generate CA certificate
    openssl req -x509 -new -nodes \
        -key "$CA_KEY" \
        -sha256 \
        -days "$CA_DAYS_VALID" \
        -out "$CA_CERT" \
        -subj "/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/OU=Development/CN=$CA_NAME" \
        2>/dev/null

    if [ -f "$CA_CERT" ]; then
        echo -e "${GREEN}✓${NC} Root CA created: $CA_CERT"
        echo -e "${YELLOW}  Note:${NC} Run install.sh to trust this CA in your system"
    else
        echo -e "${RED}✗${NC} Failed to create Root CA"
        return 1
    fi
}

# Check if certificate is still valid
cert_is_valid() {
    local cert_file="$1"
    local min_days="${2:-$MIN_DAYS_REMAINING}"

    [ ! -f "$cert_file" ] && return 1

    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2) || return 1
    [ -z "$expiry_date" ] && return 1

    local expiry_epoch current_epoch min_epoch

    if [[ "$OSTYPE" == "darwin"* ]]; then
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" "+%s" 2>/dev/null) || return 1
    else
        expiry_epoch=$(date -d "$expiry_date" "+%s" 2>/dev/null) || return 1
    fi

    current_epoch=$(date "+%s")
    min_epoch=$((current_epoch + min_days * 86400))

    [ "$expiry_epoch" -gt "$min_epoch" ]
}

# Check if certificate is signed by our Root CA
cert_is_signed_by_ca() {
    local cert_file="$1"
    [ ! -f "$cert_file" ] && return 1
    [ ! -f "$CA_CERT" ] && return 1

    local issuer
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | grep -o "CN=[^,/]*" | head -1)
    [[ "$issuer" == *"$CA_NAME"* ]]
}

# Check if certificate already covers EVERY required DNS name (SAN).
# Returns 1 (false) if any required name is missing -> cert must be regenerated.
# This is what makes newly-added aliases take effect without manually deleting certs.
cert_covers_sans() {
    local cert_file="$1"
    local required_dns="$2"   # comma-separated DNS names, no "DNS:" prefix

    [ ! -f "$cert_file" ] && return 1

    local current_sans
    current_sans=$(openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null \
        | grep -o "DNS:[^,]*" | sed 's/DNS://g' | tr -d ' ')
    [ -z "$current_sans" ] && return 1

    local name
    IFS=',' read -ra REQ <<< "$required_dns"
    for name in "${REQ[@]}"; do
        name=$(echo "$name" | xargs 2>/dev/null || echo "$name")
        [ -z "$name" ] && continue
        # -x whole line, -F fixed string (so the '*' in *.domain is literal)
        grep -qxF "$name" <<< "$current_sans" || return 1
    done
    return 0
}

# Generate a certificate signed by Root CA
generate_signed_cert() {
    local domain="$1"
    local san_list="$2"
    local cert_file="$CERT_DIR/${domain}.crt"
    local key_file="$CERT_DIR/${domain}.key"
    local csr_file="$CERT_DIR/${domain}.csr"
    local ext_file="$CERT_DIR/${domain}.ext"

    # Build the list of required DNS names: domain + aliases + wildcard
    local required_dns="${domain}"
    if [ -n "$san_list" ]; then
        IFS=',' read -ra SANS <<< "$san_list"
        for san in "${SANS[@]}"; do
            san=$(echo "$san" | xargs 2>/dev/null || echo "$san")
            [ -n "$san" ] && required_dns="${required_dns},${san}"
        done
    fi
    required_dns="${required_dns},*.${domain}"

    # Skip ONLY if cert is valid, signed by our CA, AND already covers every
    # required SAN. If an alias was added in the panel, the SAN is stale and we
    # fall through to regenerate it automatically.
    if cert_is_valid "$cert_file" \
        && cert_is_signed_by_ca "$cert_file" \
        && cert_covers_sans "$cert_file" "$required_dns"; then
        echo -e "  ${YELLOW}⊘${NC} $domain (valid, skipped)"
        ((SKIPPED++))
        return 0
    fi

    # Build the openssl SAN string from the required DNS names + loopback IP
    local san_string="" name
    IFS=',' read -ra DNSNAMES <<< "$required_dns"
    for name in "${DNSNAMES[@]}"; do
        [ -n "$name" ] && san_string="${san_string}${san_string:+,}DNS:${name}"
    done
    san_string="${san_string},IP:127.0.0.1"

    # Generate private key
    openssl genrsa -out "$key_file" 2048 2>/dev/null

    # Generate CSR
    openssl req -new \
        -key "$key_file" \
        -out "$csr_file" \
        -subj "/C=GT/ST=Guatemala/L=Guatemala/O=LocalDev/CN=$domain" \
        2>/dev/null

    # Create extensions file
    cat > "$ext_file" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = $san_string
EOF

    # Sign with Root CA
    if openssl x509 -req \
        -in "$csr_file" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$cert_file" \
        -days "$DAYS_VALID" \
        -sha256 \
        -extfile "$ext_file" \
        2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $domain (signed by Root CA)"
        ((GENERATED++))
        rm -f "$csr_file" "$ext_file"
        return 0
    else
        echo -e "  ${RED}✗${NC} $domain (failed)"
        ((FAILED++))
        rm -f "$csr_file" "$ext_file"
        return 1
    fi
}

# Parse JSON using jq or python - skip backend projects
get_active_domains() {
    local json_file="$1"

    if command -v jq &> /dev/null; then
        jq -r 'to_entries | .[] | select(.value.active == true or .value.active == null) | select(.value.stack != "backend") | .key' "$json_file" 2>/dev/null
    elif command -v python3 &> /dev/null; then
        python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
for domain, config in data.items():
    if config.get('active', True) and config.get('stack', 'frontend') != 'backend':
        print(domain)
" 2>/dev/null
    else
        echo ""
    fi
}

get_domain_aliases() {
    local json_file="$1"
    local domain="$2"

    # Parent-driven: include ALL alias values. The parent domain is already
    # filtered to active by get_active_domains, so per-alias "active" is ignored.
    if command -v jq &> /dev/null; then
        jq -r ".[\"$domain\"].aliases // [] |
            if type == \"array\" then
                map(if type == \"string\" then .
                    elif type == \"object\" then .value
                    else empty end)
                | map(select(. != null and . != \"\"))
                | join(\",\")
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
    elif isinstance(a, dict) and a.get('value'):
        result.append(a['value'])
print(','.join(result))
" 2>/dev/null
    else
        echo ""
    fi
}

# ============================================
# Main execution
# ============================================

# Step 1: Create Root CA
echo -e "${YELLOW}[1/3]${NC} Checking Root CA..."
create_root_ca
echo ""

# Step 2: Generate default certificate
echo -e "${YELLOW}[2/3]${NC} Generating default certificate..."
generate_signed_cert "default" "localhost"
echo ""

# Step 3: Process hosts from JSON
echo -e "${YELLOW}[3/3]${NC} Processing hosts..."
echo ""

if [ ! -f "$HOSTS_JSON" ]; then
    echo -e "${YELLOW}No hosts.json found at $HOSTS_JSON${NC}"
    echo -e "${YELLOW}Only default certificate was generated${NC}"
else
    domains=$(get_active_domains "$HOSTS_JSON")

    if [ -z "$domains" ]; then
        echo -e "${YELLOW}No active hosts found in hosts.json${NC}"
    else
        while IFS= read -r domain; do
            [ -z "$domain" ] && continue
            aliases=$(get_domain_aliases "$HOSTS_JSON" "$domain")
            generate_signed_cert "$domain" "$aliases"
        done <<< "$domains"
    fi
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "  Generated: ${GREEN}$GENERATED${NC}"
echo -e "  Skipped:   ${YELLOW}$SKIPPED${NC}"
echo -e "  Failed:    ${RED}$FAILED${NC}"
echo ""
echo -e "Root CA:     $CA_CERT"
echo -e "Certs Dir:   $CERT_DIR"
echo -e "Validity:    $DAYS_VALID days (certs), $CA_DAYS_VALID days (CA)"
echo ""
echo -e "${YELLOW}Important:${NC} Run install.sh to trust the Root CA in your system."
echo -e "           Once trusted, all certificates will be valid in browsers."
echo ""

[ "$FAILED" -gt 0 ] && exit 1
exit 0
