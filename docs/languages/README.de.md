# Localhost Manager

**[English](README.en.md) | [Español](README.es.md) | [Français](README.fr.md)**

Vollständiges System zur Verwaltung lokaler Domains, SSL-Zertifikate und Apache-Konfiguration auf macOS nativ (ohne MAMP Pro).

## Voraussetzungen

- macOS (Ventura oder neuer)
- Homebrew installiert
- PHP 8.4 (installiert)
- MySQL 8.4 (installiert)
- Apache 2.4 (nativ macOS)

## Schnellinstallation

### Schritt 1: Dienste Konfigurieren

```bash
# PHP 8.4 und MySQL zum PATH hinzufügen
echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Schritt 2: Dienste Starten

```bash
# PHP-FPM starten
brew services start php@8.4

# MySQL starten
brew services start mysql@8.4

# MySQL konfigurieren (optional)
mysql_secure_installation
```

### Schritt 3: Apache Konfigurieren und Zertifikate Generieren

```bash
# Ausführungsrechte für Skripte erteilen
chmod +x ~/localhost-manager/scripts/*.sh

# Alle SSL-Zertifikate generieren
bash ~/localhost-manager/scripts/generate-certificates.sh
```

### Schritt 4: Zugriff auf Web-Interface

1. Öffnen Sie Ihren Browser
2. Gehen Sie zu: `http://localhost/manager`
3. Verwenden Sie die Oberfläche für:
   - SSL-Zertifikate generieren
   - Apache-Konfiguration erstellen
   - /etc/hosts-Datei generieren
   - Domains und Aliase verwalten

## Verwendung der Web-Oberfläche

### Hauptdashboard

Die Oberfläche zeigt:
- **Systeminformationen**: PHP-, Apache- und MySQL-Versionen
- **Schnellaktionen**: Schaltflächen zum Generieren von Zertifikaten, Konfiguration usw.
- **Domain-Liste**: Tabelle mit allen konfigurierten Domains

### SSL-Zertifikate Generieren

1. Klicken Sie auf "Alle Zertifikate Generieren"
2. Oder generieren Sie einzelne Zertifikate mit der Schaltfläche "Cert" in jeder Zeile

### Apache-Konfiguration Generieren

1. Klicken Sie auf "Apache-Konfiguration Generieren"
2. Dies erstellt die Datei `~/localhost-manager/conf/vhosts.conf`

### /etc/hosts Aktualisieren

1. Klicken Sie auf "/etc/hosts Generieren"
2. Führen Sie den angezeigten Befehl aus:

```bash
sudo bash ~/localhost-manager/scripts/update-hosts.sh
```

### Konfiguration auf Apache Anwenden

Nach dem Generieren der Konfiguration führen Sie aus:

```bash
sudo bash ~/localhost-manager/scripts/install.sh
```

Dieses Skript:
- Konfiguriert PHP 8.4 in Apache
- Aktiviert erforderliche Module (SSL, rewrite usw.)
- Kopiert Zertifikate nach `/etc/apache2/ssl`
- Wendet Virtual-Hosts-Konfiguration an
- Startet Apache neu

## Neue Domain Hinzufügen

1. Gehen Sie in der Web-Oberfläche zum Abschnitt "Neue Domain Hinzufügen"
2. Füllen Sie die Felder aus:
   - **Domain**: `meinedomain.local`
   - **Alias** (optional): `www.meinedomain.local`
   - **Document Root**: `/Users/ihrbenutzer/Sites/localhost/meinedomain.local`
3. Klicken Sie auf "Domain Hinzufügen"
4. Generieren Sie SSL-Zertifikat für die Domain
5. Regenerieren Sie Apache-Konfiguration
6. Aktualisieren Sie /etc/hosts
7. Führen Sie das Installationsskript aus

## Dateistruktur

```
~/localhost-manager/
├── certs/                    # Generierte SSL-Zertifikate
├── conf/                     # Konfigurationsdateien
│   ├── hosts.json           # Domain-Datenbank
│   ├── hosts.txt            # Einträge für /etc/hosts
│   └── vhosts.conf          # Apache-Konfiguration
├── scripts/                  # Verwaltungsskripte
│   ├── generate-certificates.sh
│   ├── generate-vhosts-config.sh
│   ├── install.sh
│   └── update-hosts.sh
└── README.md

/Users/ihrbenutzer/Sites/localhost/
└── manager/                  # Web-Oberfläche
    └── index.php
```

## Nützliche Befehle

### Apache

```bash
# Apache starten
sudo apachectl start

# Apache stoppen
sudo apachectl stop

# Apache neustarten
sudo apachectl restart

# Konfiguration überprüfen
sudo apachectl configtest
```

### PHP

```bash
# Version anzeigen
php --version

# Konfiguration anzeigen
php --ini
```

### MySQL

```bash
# Mit MySQL verbinden
mysql -u root -p

# Datenbanken anzeigen
mysql -u root -p -e "SHOW DATABASES;"
```

## SSL-Zertifikate

Selbstsignierte Zertifikate sind **10 Jahre** (3650 Tage) gültig.

Um einem Zertifikat auf macOS zu vertrauen:
1. Öffnen Sie Keychain Access
2. Ziehen Sie die `.crt`-Datei aus `~/localhost-manager/certs/`
3. Doppelklicken Sie auf das Zertifikat
4. Erweitern Sie "Trust"
5. Wählen Sie "Always Trust"

## Vorteile gegenüber MAMP Pro

- Kostenlos und Open Source
- Native macOS-Konfiguration
- Bessere Leistung
- Einfache Komponenten-Updates
- Volle Konfigurationskontrolle
- Moderne Web-Verwaltungsoberfläche
- Automatische SSL-Zertifikatgenerierung
- Unterstützung für Domain-Aliase

---

**Autor**: Localhost Manager
**Version**: 1.0.0
**Datum**: November 2025
