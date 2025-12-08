# Localhost Manager

**[Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md)**

Complete system to manage local domains, SSL certificates, and Apache configuration on macOS natively (without MAMP Pro).

## Prerequisites

- macOS (Ventura or later)
- Homebrew installed
- PHP 8.4 (installed)
- MySQL 8.4 (installed)
- Apache 2.4 (native macOS)

## Quick Installation

### Step 1: Configure Services

```bash
# Add PHP 8.4 and MySQL to PATH
echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Step 2: Start Services

```bash
# Start PHP-FPM
brew services start php@8.4

# Start MySQL
brew services start mysql@8.4

# Configure MySQL (optional - set root password)
mysql_secure_installation
```

### Step 3: Configure Apache and Generate Certificates

```bash
# Grant execution permissions to scripts
chmod +x ~/localhost-manager/scripts/*.sh

# Generate all SSL certificates
bash ~/localhost-manager/scripts/generate-certificates.sh
```

### Step 4: Access Web Interface

1. Open your browser
2. Go to: `http://localhost/manager`
3. Use the interface to:
   - Generate SSL certificates
   - Create Apache configuration
   - Generate /etc/hosts file
   - Manage domains and aliases

## Using the Web Interface

### Main Dashboard

The interface shows:
- **System Information**: PHP, Apache, and MySQL versions
- **Quick Actions**: Buttons to generate certificates, configuration, etc.
- **Domain List**: Table with all configured domains

### Generate SSL Certificates

1. Click "Generate All Certificates"
2. Or generate individual certificates with the "Cert" button on each row

### Generate Apache Configuration

1. Click "Generate Apache Configuration"
2. This creates the file `~/localhost-manager/conf/vhosts.conf`

### Update /etc/hosts

1. Click "Generate /etc/hosts"
2. Run the command that appears:

```bash
sudo bash ~/localhost-manager/scripts/update-hosts.sh
```

### Apply Configuration to Apache

After generating the configuration, run:

```bash
sudo bash ~/localhost-manager/scripts/install.sh
```

This script:
- Configures PHP 8.4 in Apache
- Enables necessary modules (SSL, rewrite, etc.)
- Copies certificates to `/etc/apache2/ssl`
- Applies virtual hosts configuration
- Restarts Apache

## Adding a New Domain

1. In the web interface, go to "Add New Domain" section
2. Fill in the fields:
   - **Domain**: `mydomain.local`
   - **Alias** (optional): `www.mydomain.local`
   - **Document Root**: `/Users/youruser/Sites/localhost/mydomain.local`
3. Click "Add Domain"
4. Generate SSL certificate for the domain
5. Regenerate Apache configuration
6. Update /etc/hosts
7. Run the installation script

## File Structure

```
~/localhost-manager/
├── certs/                    # Generated SSL certificates
├── conf/                     # Configuration files
│   ├── hosts.json           # Domain database
│   ├── hosts.txt            # Entries for /etc/hosts
│   └── vhosts.conf          # Apache configuration
├── scripts/                  # Management scripts
│   ├── generate-certificates.sh
│   ├── generate-vhosts-config.sh
│   ├── install.sh
│   └── update-hosts.sh
└── README.md

/Users/youruser/Sites/localhost/
└── manager/                  # Web interface
    └── index.php
```

## Auto-Start Services Configuration

To make services start automatically on system boot:

```bash
# PHP-FPM
brew services start php@8.4

# MySQL
brew services start mysql@8.4

# Apache (macOS)
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```

To stop services:

```bash
brew services stop php@8.4
brew services stop mysql@8.4
sudo apachectl stop
```

## Useful Commands

### Apache

```bash
# Start Apache
sudo apachectl start

# Stop Apache
sudo apachectl stop

# Restart Apache
sudo apachectl restart

# Verify configuration
sudo apachectl configtest

# View loaded modules
sudo apachectl -M
```

### PHP

```bash
# View version
php --version

# View configuration
php --ini

# Edit php.ini
nano /opt/homebrew/etc/php/8.4/php.ini
```

### MySQL

```bash
# Connect to MySQL
mysql -u root -p

# View databases
mysql -u root -p -e "SHOW DATABASES;"

# Service status
brew services list | grep mysql
```

## SSL Certificates

Self-signed certificates are valid for **10 years** (3650 days).

To trust a certificate on macOS:
1. Open Keychain Access
2. Drag the `.crt` file from `~/localhost-manager/certs/`
3. Double-click the certificate
4. Expand "Trust"
5. Select "Always Trust"

## Troubleshooting

### Apache won't start

```bash
# View error log
tail -f /var/log/apache2/error_log

# Verify configuration
sudo apachectl configtest
```

### PHP not working

```bash
# Verify module is loaded
sudo apachectl -M | grep php

# Verify php.ini
php --ini
```

### SSL certificate not trusted

Add the certificate to Keychain Access (see SSL Certificates section).

### Port 80 or 443 in use

```bash
# See what process is using the port
sudo lsof -i :80
sudo lsof -i :443

# Stop MAMP if running
```

## Benefits vs MAMP Pro

- Free and open source
- Native macOS configuration
- Better performance
- Easy component updates
- Full configuration control
- Modern web administration interface
- Automatic SSL certificate generation
- Domain alias support

## Support

For issues or suggestions, check the logs:

- Apache: `/var/log/apache2/error_log`
- PHP: `/opt/homebrew/var/log/php-fpm.log`
- MySQL: `/opt/homebrew/var/mysql/*.err`

---

**Author**: Localhost Manager
**Version**: 1.0.0
**Date**: November 2025
