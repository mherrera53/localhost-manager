#!/bin/bash
#
# i18n Loader for Bash Scripts
# Usage: source ~/localhost-manager/scripts/i18n/loader.sh
#

# Detect language from environment or use default
LANG_CODE="${LANG_CODE:-${LANGUAGE:-en}}"
LANG_CODE="${LANG_CODE:0:2}"  # Extract first 2 chars (en_US -> en)

# Supported languages
SUPPORTED_LANGS=("en" "es" "fr" "de" "pt")

# Validate language code
if [[ ! " ${SUPPORTED_LANGS[@]} " =~ " ${LANG_CODE} " ]]; then
    LANG_CODE="en"
fi

# Load messages file
I18N_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESSAGES_FILE="$I18N_DIR/messages_${LANG_CODE}.sh"

if [ -f "$MESSAGES_FILE" ]; then
    source "$MESSAGES_FILE"
else
    # Fallback to English
    source "$I18N_DIR/messages_en.sh"
fi

# Function to get translated message
# Usage: msg "key_name"
msg() {
    local key="MSG_$1"
    echo "${!key:-$1}"
}

# Export function for use in scripts
export -f msg
