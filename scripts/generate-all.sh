#!/bin/bash

# ============================================
# Localhost Manager - Configuration Generator
# ============================================
# Este script genera todos los archivos de configuración necesarios:
# - Virtual Hosts de Apache
# - Certificados SSL
# - Archivo /etc/hosts
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPTS_DIR="$HOME/localhost-manager/scripts"
CONF_DIR="$HOME/localhost-manager/conf"
HOSTS_FILE="$CONF_DIR/hosts.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Localhost Manager - Generador de Configuración${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar que existe el archivo de hosts
if [ ! -f "$HOSTS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} No se encontró $HOSTS_FILE"
    exit 1
fi

# 1. Generar Virtual Hosts de Apache
echo -e "${YELLOW}[1/2]${NC} Generando Virtual Hosts de Apache..."
if bash "$SCRIPTS_DIR/generate-vhosts-config.sh" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Virtual Hosts generados"
else
    echo -e "${RED}✗${NC} Error generando Virtual Hosts"
    exit 1
fi

# 2. Generar Certificados SSL
echo -e "${YELLOW}[2/2]${NC} Generando Certificados SSL..."
if bash "$SCRIPTS_DIR/generate-certificates.sh" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Certificados SSL generados"
else
    echo -e "${YELLOW}⚠${NC} Error generando certificados (se continuará de todos modos)"
fi

# NOTA: /etc/hosts se actualiza en install.sh con privilegios de admin

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Configuración generada${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  1. Aplicar configuración: ${BLUE}bash $SCRIPTS_DIR/install.sh${NC}"
echo -e "  2. O copiar manualmente los archivos generados a Apache"
echo ""
