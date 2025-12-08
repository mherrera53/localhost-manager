#!/bin/bash

# Script to configure sudo password in macOS Keychain
# This is more secure than storing the password in plain text

SERVICE_NAME="localhost-manager-sudo"
ACCOUNT_NAME="$USER"

echo "======================================"
echo " Configure Password in Keychain"
echo "======================================"
echo ""
echo "This script will securely store your sudo password in macOS Keychain."
echo "This allows the localhost-manager scripts to run without prompting."
echo ""
echo "Your password will be stored securely and is never saved in plain text."
echo ""

# Prompt for password securely (input not echoed)
read -s -p "Enter your sudo password: " PASSWORD
echo ""
read -s -p "Confirm your sudo password: " PASSWORD_CONFIRM
echo ""

# Verify passwords match
if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "[ERROR] Passwords do not match"
    exit 1
fi

# Verify the password is correct by testing sudo
echo "$PASSWORD" | sudo -S -v 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] Invalid sudo password"
    exit 1
fi

echo ""
echo "Saving password to Keychain..."

# Remove existing entry if present
security delete-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" 2>/dev/null

# Add password to Keychain
security add-generic-password \
    -a "$ACCOUNT_NAME" \
    -s "$SERVICE_NAME" \
    -w "$PASSWORD"

if [ $? -eq 0 ]; then
    echo "[OK] Password saved to Keychain successfully"
    echo ""
    echo "The sudo password is now stored securely in:"
    echo "  Service: $SERVICE_NAME"
    echo "  Account: $ACCOUNT_NAME"
    echo ""
    echo "Scripts can now retrieve the password automatically."
    echo ""
    echo "To remove the password from Keychain, run:"
    echo "  security delete-generic-password -a \"$ACCOUNT_NAME\" -s \"$SERVICE_NAME\""
else
    echo "[ERROR] Failed to save password to Keychain"
    exit 1
fi
