#!/bin/bash
# Use system Apache, not MAMP
export PATH="/usr/sbin:/usr/bin:/bin:/sbin:$PATH"


# Script para configurar servicios de inicio automático
# PHP 8.4, MySQL 8.4 y Apache en macOS

echo "======================================"
echo " Configuración de Servicios"
echo "======================================"
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Este script configurará los siguientes servicios para inicio automático:"
echo "  • PHP 8.4 (php-fpm)"
echo "  • MySQL 8.4"
echo "  • Apache 2.4"
echo ""

# Configurar PHP 8.4
echo -e "${YELLOW}Configurando PHP 8.4...${NC}"
brew services start php@8.4
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PHP 8.4 configurado${NC}"
else
    echo "⚠️  Error configurando PHP 8.4"
fi
echo ""

# Configurar MySQL 8.4
echo -e "${YELLOW}Configurando MySQL 8.4...${NC}"
brew services start mysql@8.4
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MySQL 8.4 configurado${NC}"
else
    echo "⚠️  Error configurando MySQL 8.4"
fi
echo ""

# Información sobre Apache
echo -e "${YELLOW}Apache 2.4...${NC}"
echo "Apache se inicia automáticamente en macOS."
echo "Para habilitarlo manualmente ejecuta:"
echo "  sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist"
echo ""

# Verificar servicios
echo "======================================"
echo " Estado de Servicios"
echo "======================================"
echo ""

echo "PHP-FPM:"
brew services list | grep php@8.4
echo ""

echo "MySQL:"
brew services list | grep mysql@8.4
echo ""

echo "Apache:"
sudo apachectl status 2>/dev/null || echo "Apache no está corriendo. Ejecútalo con: sudo apachectl start"
echo ""

# Agregar al PATH si no está
echo "======================================"
echo " Configuración de PATH"
echo "======================================"
echo ""

ZSHRC="$HOME/.zshrc"

# PHP 8.4
if ! grep -q "php@8.4/bin" "$ZSHRC"; then
    echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> "$ZSHRC"
    echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> "$ZSHRC"
    echo -e "${GREEN}✓ PHP 8.4 agregado al PATH${NC}"
else
    echo "✓ PHP 8.4 ya está en el PATH"
fi

# MySQL 8.4
if ! grep -q "mysql@8.4/bin" "$ZSHRC"; then
    echo 'export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"' >> "$ZSHRC"
    echo -e "${GREEN}✓ MySQL 8.4 agregado al PATH${NC}"
else
    echo "✓ MySQL 8.4 ya está en el PATH"
fi

echo ""
echo "======================================"
echo " Configuración Completada"
echo "======================================"
echo ""
echo "Los servicios ahora se iniciarán automáticamente al arrancar el sistema."
echo ""
echo "Comandos útiles:"
echo "  • Detener PHP:   brew services stop php@8.4"
echo "  • Reiniciar PHP: brew services restart php@8.4"
echo "  • Detener MySQL: brew services stop mysql@8.4"
echo "  • Estado:        brew services list"
echo ""
echo "Para aplicar los cambios del PATH, ejecuta:"
echo "  source ~/.zshrc"
echo ""
