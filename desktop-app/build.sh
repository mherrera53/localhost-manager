#!/bin/bash

# Build script para Localhost Manager
# Pide contraseña una sola vez y configura acceso para codesign

set -e

cd "$(dirname "$0")"

echo "Ingresa tu contraseña del Keychain (una sola vez):"
read -s KEYCHAIN_PWD

echo ""
echo "Configurando Keychain para codesign..."

# Desbloquear keychain
security unlock-keychain -p "$KEYCHAIN_PWD" ~/Library/Keychains/login.keychain-db

# Permitir acceso a codesign sin confirmacion adicional
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PWD" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# Limpiar variable con contraseña
unset KEYCHAIN_PWD

echo ""
echo "Iniciando build de Tauri..."
npm run tauri build

echo ""
echo "Build completado!"
echo ""
echo "Bundles generados:"
ls -lh src-tauri/target/release/bundle/macos/*.app 2>/dev/null || true
ls -lh src-tauri/target/release/bundle/dmg/*.dmg 2>/dev/null || true
