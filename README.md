# Localhost Manager

Sistema completo para administrar dominios locales, certificados SSL y configuración de Apache en macOS de forma nativa (sin MAMP Pro).

## Requisitos Previos

- macOS (Ventura o superior)
- Homebrew instalado
- PHP 8.4 (instalado)
- MySQL 8.4 (instalado)
- Apache 2.4 (nativo de macOS)

## Instalación Rápida

### Paso 1: Configurar servicios

```bash
# Agregar PHP 8.4 y MySQL al PATH
echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Paso 2: Iniciar servicios

```bash
# Iniciar PHP-FPM
brew services start php@8.4

# Iniciar MySQL
brew services start mysql@8.4

# Configurar MySQL (opcional - establecer contraseña root)
mysql_secure_installation
```

### Paso 3: Configurar Apache y generar certificados

```bash
# Dar permisos de ejecución a los scripts
chmod +x ~/localhost-manager/scripts/*.sh

# Generar todos los certificados SSL
bash ~/localhost-manager/scripts/generate-certificates.sh
```

### Paso 4: Acceder a la interfaz web

1. Abre tu navegador
2. Ve a: `http://localhost/manager`
3. Usa la interfaz para:
   - Generar certificados SSL
   - Crear configuración de Apache
   - Generar archivo /etc/hosts
   - Administrar dominios y alias

## Uso de la Interfaz Web

### Dashboard Principal

La interfaz muestra:
- **Información del sistema**: Versiones de PHP, Apache y MySQL
- **Acciones rápidas**: Botones para generar certificados, configuración, etc.
- **Lista de dominios**: Tabla con todos los dominios configurados

### Generar Certificados SSL

1. Click en "Generar Todos los Certificados"
2. O genera certificados individuales con el botón "Cert" en cada fila

### Generar Configuración de Apache

1. Click en "Generar Configuración Apache"
2. Esto crea el archivo `~/localhost-manager/conf/vhosts.conf`

### Actualizar /etc/hosts

1. Click en "Generar /etc/hosts"
2. Ejecuta el comando que aparece:

```bash
sudo bash ~/localhost-manager/scripts/update-hosts.sh
```

### Aplicar Configuración a Apache

Después de generar la configuración, ejecuta:

```bash
sudo bash ~/localhost-manager/scripts/install.sh
```

Este script:
- Configura PHP 8.4 en Apache
- Habilita módulos necesarios (SSL, rewrite, etc.)
- Copia certificados a `/etc/apache2/ssl`
- Aplica configuración de virtual hosts
- Reinicia Apache

## Agregar Nuevo Dominio

1. En la interfaz web, ve a la sección "Agregar Nuevo Dominio"
2. Completa los campos:
   - **Dominio**: `midominio.local`
   - **Alias** (opcional): `www.midominio.local`
   - **Document Root**: `/Users/mario/Sites/localhost/midominio.local`
3. Click en "Agregar Dominio"
4. Genera el certificado SSL para el dominio
5. Regenera la configuración de Apache
6. Actualiza /etc/hosts
7. Ejecuta el script de instalación

## Estructura de Archivos

```
~/localhost-manager/
├── certs/                    # Certificados SSL generados
├── conf/                     # Archivos de configuración
│   ├── hosts.json           # Base de datos de dominios
│   ├── hosts.txt            # Entradas para /etc/hosts
│   └── vhosts.conf          # Configuración de Apache
├── scripts/                  # Scripts de administración
│   ├── generate-certificates.sh
│   ├── generate-vhosts-config.sh
│   ├── install.sh
│   └── update-hosts.sh
└── README.md

/Users/mario/Sites/localhost/
└── manager/                  # Interfaz web
    └── index.php
```

## Configuración de Servicios de Inicio Automático

Para que los servicios se inicien automáticamente al arrancar el sistema:

```bash
# PHP-FPM
brew services start php@8.4

# MySQL
brew services start mysql@8.4

# Apache (macOS)
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```

Para detener los servicios:

```bash
brew services stop php@8.4
brew services stop mysql@8.4
sudo apachectl stop
```

## Comandos Útiles

### Apache

```bash
# Iniciar Apache
sudo apachectl start

# Detener Apache
sudo apachectl stop

# Reiniciar Apache
sudo apachectl restart

# Verificar configuración
sudo apachectl configtest

# Ver módulos cargados
sudo apachectl -M
```

### PHP

```bash
# Ver versión
php --version

# Ver configuración
php --ini

# Editar php.ini
nano /opt/homebrew/etc/php/8.4/php.ini
```

### MySQL

```bash
# Conectar a MySQL
mysql -u root -p

# Ver bases de datos
mysql -u root -p -e "SHOW DATABASES;"

# Estado del servicio
brew services list | grep mysql
```

## Certificados SSL

Los certificados autofirmados son válidos por **10 años** (3650 días).

Para confiar en un certificado en macOS:
1. Abre Keychain Access
2. Arrastra el archivo `.crt` desde `~/localhost-manager/certs/`
3. Doble click en el certificado
4. Expande "Trust"
5. Selecciona "Always Trust"

## Solución de Problemas

### Apache no inicia

```bash
# Ver error log
tail -f /var/log/apache2/error_log

# Verificar configuración
sudo apachectl configtest
```

### PHP no funciona

```bash
# Verificar que el módulo está cargado
sudo apachectl -M | grep php

# Verificar php.ini
php --ini
```

### Certificado SSL no confiable

Agrega el certificado a Keychain Access (ver sección Certificados SSL).

### Puerto 80 o 443 ocupado

```bash
# Ver qué proceso usa el puerto
sudo lsof -i :80
sudo lsof -i :443

# Detener MAMP si está corriendo
```

## Beneficios vs MAMP Pro

- Gratis y de código abierto
- Configuración nativa de macOS
- Mejor rendimiento
- Fácil actualización de componentes
- Control total de la configuración
- Interfaz web moderna para administración
- Generación automática de certificados SSL
- Soporte para alias de dominios

## Soporte

Para problemas o sugerencias, revisa los logs:

- Apache: `/var/log/apache2/error_log`
- PHP: `/opt/homebrew/var/log/php-fpm.log`
- MySQL: `/opt/homebrew/var/mysql/*.err`

---

**Autor**: Localhost Manager
**Versión**: 1.0.0
**Fecha**: Noviembre 2025
