# Inicio Rápido - Localhost Manager

Sistema completo para reemplazar MAMP Pro con configuración nativa en macOS.

## Estado Actual

- PHP 8.4 instalado
- MySQL 8.4 instalado
- Apache 2.4 (nativo macOS)
- Password sudo en Keychain (seguro)
- Interfaz web de administración
- Grupos automáticos por repositorio

## Pasos de Configuración

### 1. Configurar Servicios (2 min)

```bash
# Configurar PHP y MySQL para inicio automático
bash ~/localhost-manager/scripts/configure-services.sh
source ~/.zshrc
```

### 2. Acceder a la Interfaz (30 seg)

Abre tu navegador en: **http://localhost/manager**

### 3. Generar Todo Automáticamente (1 min)

En la interfaz web, haz click en estos botones en orden:

1. **Generar Certificados** - Genera certificados SSL para todos los dominios activos
2. **Generar Vhosts** - Crea la configuración de Apache
3. **Generar Hosts** - Prepara el archivo /etc/hosts
4. **Aplicar Configuración** - Aplica todo automáticamente (usa Keychain para sudo)

Y listo! Todos tus dominios estarán funcionando con HTTPS.

## Características Principales

### Gestión por Grupos

Los dominios se agrupan automáticamente por repositorio basándose en la estructura de directorios.

### Activar/Desactivar Dominios

- **Toggle individual**: Activa/desactiva cada dominio con el switch
- **Toggle por grupo**: Activa/desactiva todos los dominios de un grupo

**Beneficio**: Solo los dominios activos se incluyen en:
- Configuración de Apache
- Archivo /etc/hosts
- Certificados SSL

### Seguridad

El password de sudo está almacenado en **macOS Keychain**, no en texto plano.

## Agregar Nuevo Dominio

1. En la interfaz, ve al formulario "Agregar Nuevo Dominio"
2. Completa:
   - **Dominio**: `nuevo.local`
   - **Alias**: `www.nuevo.local` (opcional)
   - **Document Root**: `/Users/youruser/Sites/localhost/nuevo/public`
   - **Grupo**: Auto (detecta automáticamente del path)
3. Click "Agregar Dominio"
4. Genera certificado SSL
5. Click "Aplicar Configuración"

El dominio estará listo en segundos.

## Comandos Útiles

```bash
# Ver servicios activos
brew services list

# Reiniciar Apache
sudo apachectl restart

# Ver logs de Apache
tail -f /var/log/apache2/error_log

# Verificar configuración
sudo apachectl configtest

# Ver password en Keychain
security find-generic-password -a $USER -s localhost-manager-sudo -w
```

## Workflow Recomendado

### Desarrollo en Múltiples Proyectos

1. **Desactiva** todos los grupos que no necesites
2. **Activa** solo el grupo del proyecto actual
3. Click **Aplicar Configuración**

Esto mejora el rendimiento de Apache y mantiene /etc/hosts limpio.

### Agregar Proyecto Nuevo

1. Crea el directorio de tu proyecto
2. Agrega el dominio en la interfaz
3. El grupo se detecta automáticamente
4. Genera certificado y aplica configuración

## Ventajas vs MAMP Pro

- **Gratis** - No necesitas licencia
- **Más rápido** - Apache nativo de macOS
- **Actualizable** - `brew upgrade` para todo
- **Grupos inteligentes** - Por repositorio automáticamente
- **Seguro** - Password en Keychain
- **Flexible** - Activa/desactiva proyectos fácilmente
- **Moderno** - Interfaz web elegante

## Archivos Importantes

```
~/localhost-manager/
├── conf/
│   ├── hosts.json          # Base de datos de dominios
│   ├── hosts.txt           # Entradas para /etc/hosts
│   └── vhosts.conf         # Configuración Apache
├── certs/                  # Certificados SSL (*.crt, *.key)
├── scripts/
│   ├── apply-config.sh     # Aplica configuración (usa Keychain)
│   ├── setup-keychain.sh   # Configura password
│   └── configure-services.sh
└── README.md               # Documentación completa

/Users/youruser/Sites/localhost/manager/
└── index.php               # Interfaz web
```

---

**Problemas?** Consulta [README.md](README.md) para documentación completa.

**Versión**: 2.0.0 (con Keychain y grupos automáticos)
**Fecha**: Noviembre 2025
