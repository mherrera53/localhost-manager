# Bash Scripts i18n System

This directory contains the internationalization (i18n) system for localhost-manager bash scripts.

## Supported Languages

- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Portuguese (pt)

## Usage

### Basic Usage

To use i18n in your bash script:

```bash
#!/bin/bash

# Load the i18n system
source ~/localhost-manager/scripts/i18n/loader.sh

# Use translated messages
echo "$(msg APACHE_STARTING)"
echo "$MSG_OK $(msg APACHE_STARTED)"
```

### Setting Language

The language is auto-detected from the environment, but you can override it:

```bash
# Set language before loading
export LANG_CODE="fr"
source ~/localhost-manager/scripts/i18n/loader.sh
```

### Available Message Functions

**Using msg function:**
```bash
echo "$(msg APACHE_STARTING)"  # Returns translated message
```

**Direct variable access:**
```bash
echo "$MSG_APACHE_STARTING"    # Same as above
```

## Message Keys

All message keys are prefixed with `MSG_` and use SCREAMING_SNAKE_CASE.

### Common Message Keys

**Status Messages:**
- `MSG_OK` - [OK] indicator
- `MSG_ERROR` - [ERROR] indicator
- `MSG_WARNING` - [!] indicator
- `MSG_INFO` - [INFO] indicator

**Apache:**
- `MSG_APACHE_STARTING`
- `MSG_APACHE_STARTED`
- `MSG_APACHE_STOPPED`
- `MSG_APACHE_ALREADY_RUNNING`
- `MSG_APACHE_NOT_RUNNING`

**MySQL:**
- `MSG_MYSQL_STARTING`
- `MSG_MYSQL_STARTED`
- `MSG_MYSQL_STOPPED`
- `MSG_MYSQL_ALREADY_RUNNING`
- `MSG_MYSQL_NOT_RUNNING`

**PHP-FPM:**
- `MSG_PHP_STARTING`
- `MSG_PHP_STARTED`
- `MSG_PHP_STOPPED`
- `MSG_PHP_ALREADY_RUNNING`
- `MSG_PHP_NOT_RUNNING`

**Configuration:**
- `MSG_CONFIG_GENERATING`
- `MSG_CONFIG_GENERATED`
- `MSG_CONFIG_APPLYING`
- `MSG_CONFIG_APPLIED`
- `MSG_CONFIG_ERROR`

**Certificates:**
- `MSG_CERT_GENERATING`
- `MSG_CERT_GENERATED`
- `MSG_CERT_EXISTS`
- `MSG_CERT_COPYING`
- `MSG_CERT_COPIED`

**Installation:**
- `MSG_INSTALL_STARTING`
- `MSG_INSTALL_COMPLETE`
- `MSG_MODULE_ENABLED`
- `MSG_MODULE_ALREADY_ENABLED`
- `MSG_MODULE_NOT_FOUND`

**See message files for complete list of available keys.**

## Adding New Messages

To add a new message:

1. Add the message to all language files (`messages_*.sh`)
2. Use the same key name in all files
3. Prefix with `MSG_`

Example:

```bash
# messages_en.sh
export MSG_BACKUP_CREATING="Creating backup..."

# messages_es.sh
export MSG_BACKUP_CREATING="Creando respaldo..."

# messages_fr.sh
export MSG_BACKUP_CREATING="Création de la sauvegarde..."

# etc.
```

## Example Script

```bash
#!/bin/bash
#
# Example script with i18n support
#

# Load i18n
source ~/localhost-manager/scripts/i18n/loader.sh

echo "======================================"
echo "  $(msg APACHE_STARTING)"
echo "======================================"

# Your code here
if systemctl start apache2; then
    echo "$MSG_OK $(msg APACHE_STARTED)"
else
    echo "$MSG_ERROR $(msg APACHE_NOT_RUNNING)"
    exit 1
fi

echo "$MSG_DONE"
```

## File Structure

```
scripts/i18n/
├── README.md           # This file
├── loader.sh           # Main loader script
├── messages_en.sh      # English messages
├── messages_es.sh      # Spanish messages
├── messages_fr.sh      # French messages
├── messages_de.sh      # German messages
└── messages_pt.sh      # Portuguese messages
```

## Language Detection

The system detects language in this order:

1. `$LANG_CODE` environment variable (if set)
2. `$LANGUAGE` environment variable (first 2 chars)
3. Defaults to English if not supported

## Contributing

When adding new scripts or modifying existing ones:

1. Always use message keys instead of hardcoded strings
2. Add new message keys to ALL language files
3. Keep messages concise and clear
4. Use consistent terminology across messages
