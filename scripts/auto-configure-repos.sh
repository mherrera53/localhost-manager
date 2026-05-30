#!/bin/bash

HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
TEMP_FILE="/tmp/hosts_updated.json"

echo "🔍 Auto-configurando repos con package.json..."
echo ""

# Backup
cp "$HOSTS_JSON" "$HOSTS_JSON.backup"

# Procesar cada host
jq -r 'to_entries[] | "\(.key)|\(.value.docroot)"' "$HOSTS_JSON" | while IFS='|' read -r domain docroot; do
    
    # Buscar package.json en docroot o directorio padre
    PKG_JSON=""
    if [ -f "$docroot/package.json" ]; then
        PKG_JSON="$docroot/package.json"
        PROJECT_ROOT="$docroot"
    elif [ -f "$(dirname "$docroot")/package.json" ]; then
        PKG_JSON="$(dirname "$docroot")/package.json"
        PROJECT_ROOT="$(dirname "$docroot")"
    fi
    
    if [ -n "$PKG_JSON" ]; then
        echo "✅ $domain - Encontrado package.json"
        
        # Detectar comando dev
        DEV_CMD="npm run dev"
        if grep -q '"dev"' "$PKG_JSON"; then
            DEV_CMD="npm run dev"
        elif grep -q '"watch"' "$PKG_JSON"; then
            DEV_CMD="npm run watch"
        elif grep -q '"start:dev"' "$PKG_JSON"; then
            DEV_CMD="npm run start:dev"
        fi
        
        # Detectar package manager
        PKG_MGR="npm"
        if [ -f "$(dirname "$PKG_JSON")/yarn.lock" ]; then
            DEV_CMD=$(echo "$DEV_CMD" | sed 's/npm run/yarn/')
            PKG_MGR="yarn"
        elif [ -f "$(dirname "$PKG_JSON")/pnpm-lock.yaml" ]; then
            DEV_CMD=$(echo "$DEV_CMD" | sed 's/npm run/pnpm run/')
            PKG_MGR="pnpm"
        fi
        
        # Detectar puerto desde vite.config(.js|.ts|.mjs|.mts) o package.json
        PORT=3000
        CFG_DIR="$(dirname "$PKG_JSON")"
        for cfg in "vite.config.js" "vite.config.ts" "vite.config.mjs" "vite.config.mts"; do
            if [ -f "$CFG_DIR/$cfg" ]; then
                VITE_PORT=$(grep -E "port\s*:\s*[0-9]+" "$CFG_DIR/$cfg" | head -1 | grep -oE "[0-9]+")
                [ -n "$VITE_PORT" ] && PORT=$VITE_PORT && break
            fi
        done
        
        # Si el script dev define --port o -p, úsalo
        DEV_SCRIPT=$(jq -r '.scripts.dev // ""' "$PKG_JSON")
        if echo "$DEV_SCRIPT" | grep -E -- '--port[ =]?[0-9]+' >/dev/null; then
            PORT=$(echo "$DEV_SCRIPT" | grep -oE '--port[ =]?[0-9]+' | grep -oE '[0-9]+')
        elif echo "$DEV_SCRIPT" | grep -E '(^| )-p[ =]?[0-9]+' >/dev/null; then
            PORT=$(echo "$DEV_SCRIPT" | grep -oE '(^| )-p[ =]?[0-9]+' | grep -oE '[0-9]+')
        fi
        
        echo "   📦 Comando: $DEV_CMD"
        echo "   🔌 Puerto: $PORT"
        echo "   📂 Root: $PROJECT_ROOT"
        
        # Actualizar hosts.json - solo campos que estén vacíos/null (respetar config del usuario)
        jq --arg domain "$domain" \
           --arg cmd "$DEV_CMD" \
           --argjson port "$PORT" \
           '
           .[$domain] as $h |
           .[$domain] += (
               {}
               + (if ($h.stack == null or $h.stack == "") then {"stack": "backend"} else {} end)
               + (if ($h.port == null) then {"port": $port} else {} end)
               + (if ($h.dev_command == null or $h.dev_command == "") then {"dev_command": $cmd} else {} end)
               + (if ($h.autostart == null) then {"autostart": true} else {} end)
           )
           ' "$HOSTS_JSON" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HOSTS_JSON"
        
        echo ""
    fi
done

echo "✨ Configuración completada!"
echo ""
echo "📋 Próximos pasos:"
echo "   1. Regenerar configuraciones: bash ~/PARA/3_Recursos/Tools/localhost-manager/scripts/generate-vhosts-config.sh"
echo "   2. Aplicar cambios: bash ~/localhost-manager/scripts/install.sh"
echo "   3. Iniciar repos: bash ~/PARA/3_Recursos/Tools/localhost-manager/scripts/manage-backend.sh start <domain>"
echo ""
echo "💡 O usar switch-mode.sh para cambiar entre LOCAL/PRODUCTION"
