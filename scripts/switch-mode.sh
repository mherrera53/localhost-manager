#!/bin/bash

HOME_DIR="$HOME"
CONF_DIR="$HOME_DIR/localhost-manager/conf"
CONFIG_FILE="$HOME_DIR/localhost-manager/app-config.json"
SETTINGS_FILE="$CONF_DIR/settings.json"

if [ -f "$CONFIG_FILE" ]; then
    SCRIPTS_BASE_PATH=$(/opt/homebrew/opt/php@8.4/bin/php -r "echo json_decode(file_get_contents('$CONFIG_FILE'))->scripts_base_path;")
    HOSTS_JSON=$(/opt/homebrew/opt/php@8.4/bin/php -r "echo json_decode(file_get_contents('$CONFIG_FILE'))->hosts_json_path;")
else
    SCRIPTS_BASE_PATH="$HOME_DIR/PARA/3_Recursos/Tools/localhost-manager/scripts"
    HOSTS_JSON="$CONF_DIR/hosts.json"
fi

MANAGE_BACKEND_SCRIPT="$SCRIPTS_BASE_PATH/manage-backend.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$CONF_DIR"

get_current_mode() {
    if [ -f "$SETTINGS_FILE" ]; then
        MODE=$(jq -r '.mode // "local"' "$SETTINGS_FILE")
        echo "$MODE"
    else
        echo "local"
    fi
}

set_mode() {
    local NEW_MODE="$1"
    cat > "$SETTINGS_FILE" <<EOF
{
  "mode": "$NEW_MODE",
  "last_switched": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

switch_to_local() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Switching to LOCAL MODE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}[1/5]${NC} Starting dev servers for Apache proxy..."
    if [ -f "$HOSTS_JSON" ]; then
        export MANAGE_SCRIPT="$MANAGE_BACKEND_SCRIPT"
        export HOSTS_JSON
        /opt/homebrew/opt/php@8.4/bin/php -r '
            $hosts = json_decode(file_get_contents(getenv("HOSTS_JSON")), true);
            $script = getenv("MANAGE_SCRIPT");
            foreach ($hosts as $domain => $config) {
                if (!isset($config["active"]) || $config["active"] !== true) {
                    continue;
                }
                
                $stack = isset($config["stack"]) ? $config["stack"] : "frontend";
                if ($stack === "backend" && isset($config["autostart"]) && $config["autostart"] === true) {
                    exec("bash " . escapeshellarg($script) . " start " . escapeshellarg($domain) . " 2>&1", $output, $code);
                    echo "  Started: $domain\n";
                }
            }
        '
    fi
    echo -e "${GREEN}✓${NC} Dev servers started"
    
    echo -e "${YELLOW}[2/5]${NC} Starting Apache..."
    brew services start httpd 2>/dev/null || sudo apachectl start
    echo -e "${GREEN}✓${NC} Apache started"
    
    echo -e "${YELLOW}[3/5]${NC} Starting PHP-FPM..."
    brew services start php@8.3 2>/dev/null || true
    echo -e "${GREEN}✓${NC} PHP-FPM started"
    
    echo -e "${YELLOW}[4/5]${NC} Starting MySQL..."
    brew services start mysql@8.4 2>/dev/null || brew services start mysql 2>/dev/null || true
    echo -e "${GREEN}✓${NC} MySQL started"
    
    echo -e "${YELLOW}[5/5]${NC} Updating mode configuration..."
    set_mode "local"
    echo -e "${GREEN}[OK]${NC} Mode updated"

    # Flush DNS so hostnames re-resolve to 127.0.0.1 instead of a stale
    # production (Cloudflare) IP cached from before switching to local.
    bash "$SCRIPTS_BASE_PATH/flush-dns.sh" || true

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}[OK] LOCAL MODE activated${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "Apache proxying to dev servers on ports 80/443"
    echo -e "Dev servers running in background"
    echo ""
}

switch_to_production() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Switching to PRODUCTION MODE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}[1/4]${NC} Stopping Apache..."
    brew services stop httpd 2>/dev/null || sudo apachectl stop 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Apache stopped"
    
    echo -e "${YELLOW}[2/4]${NC} Starting production dev servers..."
    if [ -f "$HOSTS_JSON" ]; then
        export MANAGE_SCRIPT="$MANAGE_BACKEND_SCRIPT"
        export HOSTS_JSON
        /opt/homebrew/opt/php@8.4/bin/php -r '
            $hosts = json_decode(file_get_contents(getenv("HOSTS_JSON")), true);
            $script = getenv("MANAGE_SCRIPT");
            foreach ($hosts as $domain => $config) {
                if (!isset($config["active"]) || $config["active"] !== true) {
                    continue;
                }
                
                $mode = isset($config["mode"]) ? $config["mode"] : "both";
                if ($mode === "local") {
                    continue;
                }
                
                $stack = isset($config["stack"]) ? $config["stack"] : "frontend";
                
                if ($stack === "backend" && isset($config["autostart"]) && $config["autostart"] === true) {
                    exec("bash " . escapeshellarg($script) . " start " . escapeshellarg($domain) . " 2>&1", $output, $code);
                    echo "  Started: $domain\n";
                }
            }
        '
    fi
    echo -e "${GREEN}✓${NC} Production servers started"
    
    echo -e "${YELLOW}[3/4]${NC} Keeping MySQL running..."
    echo -e "${GREEN}✓${NC} MySQL continues running"
    
    echo -e "${YELLOW}[4/4]${NC} Updating mode configuration..."
    set_mode "production"
    echo -e "${GREEN}[OK]${NC} Mode updated"

    # Flush DNS so hostnames stop resolving to 127.0.0.1 (local) and pick up
    # the real production IP again instead of a stale local cache.
    bash "$SCRIPTS_BASE_PATH/flush-dns.sh" || true

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}[OK] PRODUCTION MODE activated${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "Each project now runs its own dev server"
    echo -e "Apache is stopped"
    echo ""
}

show_status() {
    CURRENT_MODE=$(get_current_mode)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Environment Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "$CURRENT_MODE" = "local" ]; then
        echo -e "Current Mode: ${GREEN}LOCAL${NC}"
        echo ""
        echo -e "Services:"
        
        if brew services list | grep httpd | grep started >/dev/null 2>&1; then
            echo -e "  Apache:   ${GREEN}●${NC} Running"
        else
            echo -e "  Apache:   ${RED}○${NC} Stopped"
        fi
        
        if brew services list | grep "php@8.3" | grep started >/dev/null 2>&1; then
            echo -e "  PHP-FPM:  ${GREEN}●${NC} Running"
        else
            echo -e "  PHP-FPM:  ${RED}○${NC} Stopped"
        fi
        
        if brew services list | grep mysql | grep started >/dev/null 2>&1; then
            echo -e "  MySQL:    ${GREEN}●${NC} Running"
        else
            echo -e "  MySQL:    ${RED}○${NC} Stopped"
        fi
    else
        echo -e "Current Mode: ${YELLOW}PRODUCTION${NC}"
        echo ""
        echo -e "Backend Services:"
        bash "$MANAGE_BACKEND_SCRIPT" status
    fi
    
    echo ""
}

case "$1" in
    local)
        switch_to_local
        ;;
    production|prod)
        switch_to_production
        ;;
    status)
        show_status
        ;;
    toggle)
        CURRENT=$(get_current_mode)
        if [ "$CURRENT" = "local" ]; then
            switch_to_production
        else
            switch_to_local
        fi
        ;;
    *)
        echo "Usage: $0 {local|production|status|toggle}"
        echo ""
        echo "Commands:"
        echo "  local       - Switch to LOCAL mode (Apache, PHP-FPM)"
        echo "  production  - Switch to PRODUCTION mode (dev servers)"
        echo "  status      - Show current mode and service status"
        echo "  toggle      - Toggle between modes"
        echo ""
        CURRENT=$(get_current_mode)
        echo "Current mode: $CURRENT"
        exit 1
        ;;
esac
