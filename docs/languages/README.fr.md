# Localhost Manager

**[English](README.en.md) | [Español](README.es.md) | [Deutsch](README.de.md)**

Système complet pour gérer les domaines locaux, les certificats SSL et la configuration Apache sur macOS nativement (sans MAMP Pro).

## Prérequis

- macOS (Ventura ou ultérieur)
- Homebrew installé
- PHP 8.4 (installé)
- MySQL 8.4 (installé)
- Apache 2.4 (natif macOS)

## Installation Rapide

### Étape 1: Configurer les Services

```bash
# Ajouter PHP 8.4 et MySQL au PATH
echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Étape 2: Démarrer les Services

```bash
# Démarrer PHP-FPM
brew services start php@8.4

# Démarrer MySQL
brew services start mysql@8.4

# Configurer MySQL (optionnel)
mysql_secure_installation
```

### Étape 3: Configurer Apache et Générer les Certificats

```bash
# Donner les permissions d'exécution aux scripts
chmod +x ~/localhost-manager/scripts/*.sh

# Générer tous les certificats SSL
bash ~/localhost-manager/scripts/generate-certificates.sh
```

### Étape 4: Accéder à l'Interface Web

1. Ouvrez votre navigateur
2. Allez à: `http://localhost/manager`
3. Utilisez l'interface pour:
   - Générer des certificats SSL
   - Créer la configuration Apache
   - Générer le fichier /etc/hosts
   - Gérer les domaines et les alias

## Utilisation de l'Interface Web

### Tableau de Bord Principal

L'interface affiche:
- **Informations système**: Versions de PHP, Apache et MySQL
- **Actions rapides**: Boutons pour générer les certificats, la configuration, etc.
- **Liste des domaines**: Tableau avec tous les domaines configurés

### Générer les Certificats SSL

1. Cliquez sur "Générer Tous les Certificats"
2. Ou générez des certificats individuels avec le bouton "Cert" sur chaque ligne

### Générer la Configuration Apache

1. Cliquez sur "Générer la Configuration Apache"
2. Cela crée le fichier `~/localhost-manager/conf/vhosts.conf`

### Mettre à Jour /etc/hosts

1. Cliquez sur "Générer /etc/hosts"
2. Exécutez la commande qui apparaît:

```bash
sudo bash ~/localhost-manager/scripts/update-hosts.sh
```

### Appliquer la Configuration à Apache

Après avoir généré la configuration, exécutez:

```bash
sudo bash ~/localhost-manager/scripts/install.sh
```

Ce script:
- Configure PHP 8.4 dans Apache
- Active les modules nécessaires (SSL, rewrite, etc.)
- Copie les certificats vers `/etc/apache2/ssl`
- Applique la configuration des hôtes virtuels
- Redémarre Apache

## Ajouter un Nouveau Domaine

1. Dans l'interface web, allez à la section "Ajouter un Nouveau Domaine"
2. Remplissez les champs:
   - **Domaine**: `mondomaine.local`
   - **Alias** (optionnel): `www.mondomaine.local`
   - **Document Root**: `/Users/votreuser/Sites/localhost/mondomaine.local`
3. Cliquez sur "Ajouter un Domaine"
4. Générez le certificat SSL pour le domaine
5. Régénérez la configuration Apache
6. Mettez à jour /etc/hosts
7. Exécutez le script d'installation

## Structure des Fichiers

```
~/localhost-manager/
├── certs/                    # Certificats SSL générés
├── conf/                     # Fichiers de configuration
│   ├── hosts.json           # Base de données des domaines
│   ├── hosts.txt            # Entrées pour /etc/hosts
│   └── vhosts.conf          # Configuration Apache
├── scripts/                  # Scripts de gestion
│   ├── generate-certificates.sh
│   ├── generate-vhosts-config.sh
│   ├── install.sh
│   └── update-hosts.sh
└── README.md

/Users/votreuser/Sites/localhost/
└── manager/                  # Interface web
    └── index.php
```

## Commandes Utiles

### Apache

```bash
# Démarrer Apache
sudo apachectl start

# Arrêter Apache
sudo apachectl stop

# Redémarrer Apache
sudo apachectl restart

# Vérifier la configuration
sudo apachectl configtest
```

### PHP

```bash
# Voir la version
php --version

# Voir la configuration
php --ini
```

### MySQL

```bash
# Se connecter à MySQL
mysql -u root -p

# Voir les bases de données
mysql -u root -p -e "SHOW DATABASES;"
```

## Certificats SSL

Les certificats auto-signés sont valides pendant **10 ans** (3650 jours).

Pour faire confiance à un certificat sur macOS:
1. Ouvrez Keychain Access
2. Faites glisser le fichier `.crt` depuis `~/localhost-manager/certs/`
3. Double-cliquez sur le certificat
4. Développez "Trust"
5. Sélectionnez "Always Trust"

## Avantages vs MAMP Pro

- Gratuit et open source
- Configuration native de macOS
- Meilleures performances
- Mises à jour faciles des composants
- Contrôle total de la configuration
- Interface d'administration web moderne
- Génération automatique des certificats SSL
- Support des alias de domaines

---

**Auteur**: Localhost Manager
**Version**: 1.0.0
**Date**: Novembre 2025
