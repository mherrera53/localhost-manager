# Guía de Inicio Rápido - Localhost Manager

## Pasos para Configurar Todo en 5 Minutos

### 1. Configurar Servicios (PHP y MySQL)

```bash
bash ~/localhost-manager/scripts/configure-services.sh
source ~/.zshrc
```

### 2. Acceder a la Interfaz Web

Abre tu navegador y ve a:
```
http://localhost/manager
```

### 3. Generar Certificados SSL

En la interfaz web:
1. Click en "Generar Todos los Certificados"
2. Espera a que se generen los certificados

### 4. Generar Configuración de Apache

1. Click en "Generar Configuración Apache"
2. Luego ejecuta en terminal:

```bash
sudo bash ~/localhost-manager/scripts/install.sh
```

### 5. Actualizar /etc/hosts

1. En la interfaz web, click en "Generar /etc/hosts"
2. Ejecuta el comando que aparece:

```bash
sudo bash ~/localhost-manager/scripts/update-hosts.sh
```

### 6. Reiniciar Apache

```bash
sudo apachectl restart
```

## Listo

Ahora puedes acceder a tus dominios configurados con HTTPS.

## Agregar Nuevos Dominios

1. Ve a http://localhost/manager
2. Completa el formulario "Agregar Nuevo Dominio"
3. Genera el certificado SSL
4. Regenera la configuración de Apache (paso 4)
5. Actualiza /etc/hosts (paso 5)
6. Reinicia Apache (paso 6)

## Comandos Útiles

```bash
# Ver servicios activos
brew services list

# Reiniciar Apache
sudo apachectl restart

# Ver logs de Apache
tail -f /var/log/apache2/error_log

# Verificar configuración de Apache
sudo apachectl configtest
```

## Problemas Comunes

### Apache no inicia
```bash
sudo apachectl stop
sudo apachectl configtest
sudo apachectl start
```

### Certificado no confiable en el navegador
1. Abre Keychain Access
2. Arrastra el archivo .crt desde ~/localhost-manager/certs/
3. Doble click en el certificado
4. Marca como "Always Trust"

### PHP no se ejecuta
```bash
# Verifica que el módulo esté cargado
sudo apachectl -M | grep php
```

---

**Más información**: Ver [README.md](README.md) para documentación completa.
