#!/bin/bash
# Mensajes en Español

# Mensajes de estado
export MSG_OK="[OK]"
export MSG_ERROR="[ERROR]"
export MSG_WARNING="[!]"
export MSG_INFO="[INFO]"

# Mensajes comunes
export MSG_PASSWORD_NOT_FOUND="Contraseña no encontrada en Keychain."
export MSG_ALREADY_RUNNING="Ya está corriendo"
export MSG_NOT_RUNNING="No está corriendo"
export MSG_STARTED="Iniciado"
export MSG_STOPPED="Detenido"
export MSG_RESTARTING="Reiniciando..."
export MSG_PLEASE_WAIT="Por favor espere"

# Mensajes de Apache
export MSG_APACHE_STARTING="Iniciando Apache..."
export MSG_APACHE_STOPPING="Deteniendo Apache..."
export MSG_APACHE_RESTARTING="Reiniciando Apache..."
export MSG_APACHE_STARTED="Apache iniciado exitosamente"
export MSG_APACHE_STOPPED="Apache detenido exitosamente"
export MSG_APACHE_ALREADY_RUNNING="Apache ya está corriendo"
export MSG_APACHE_NOT_RUNNING="Apache no está corriendo"

# Mensajes de MySQL
export MSG_MYSQL_STARTING="Iniciando MySQL..."
export MSG_MYSQL_STOPPING="Deteniendo MySQL..."
export MSG_MYSQL_STARTED="MySQL iniciado exitosamente"
export MSG_MYSQL_STOPPED="MySQL detenido exitosamente"
export MSG_MYSQL_ALREADY_RUNNING="MySQL ya está corriendo"
export MSG_MYSQL_NOT_RUNNING="MySQL no está corriendo"

# Mensajes de PHP-FPM
export MSG_PHP_STARTING="Iniciando PHP-FPM..."
export MSG_PHP_STOPPING="Deteniendo PHP-FPM..."
export MSG_PHP_STARTED="PHP-FPM iniciado exitosamente"
export MSG_PHP_STOPPED="PHP-FPM detenido exitosamente"
export MSG_PHP_ALREADY_RUNNING="PHP-FPM ya está corriendo"
export MSG_PHP_NOT_RUNNING="PHP-FPM no está corriendo"

# Mensajes de configuración
export MSG_CONFIG_GENERATING="Generando configuración..."
export MSG_CONFIG_GENERATED="Configuración generada exitosamente"
export MSG_CONFIG_APPLYING="Aplicando configuración..."
export MSG_CONFIG_APPLIED="Configuración aplicada exitosamente"
export MSG_CONFIG_ERROR="Error al generar configuración"

# Mensajes de certificados
export MSG_CERT_GENERATING="Generando certificado SSL..."
export MSG_CERT_GENERATED="Certificado SSL generado exitosamente"
export MSG_CERT_EXISTS="El certificado ya existe"
export MSG_CERT_COPYING="Copiando certificados SSL..."
export MSG_CERT_COPIED="Certificados copiados"

# Mensajes de archivos/directorios
export MSG_FILE_NOT_FOUND="Archivo no encontrado:"
export MSG_DIR_CREATED="Directorio creado:"
export MSG_DIR_EXISTS="El directorio ya existe:"
export MSG_CHECKING_STATUS="Verificando estado..."

# Mensajes de instalación
export MSG_INSTALL_STARTING="Iniciando instalación..."
export MSG_INSTALL_COMPLETE="Instalación completada"
export MSG_ENABLE_MODULE="Habilitando módulo:"
export MSG_MODULE_ENABLED="Módulo habilitado"
export MSG_MODULE_ALREADY_ENABLED="El módulo ya está habilitado"
export MSG_MODULE_NOT_FOUND="Módulo no encontrado"

# Mensajes de vhosts
export MSG_VHOSTS_TITLE="Generador de Virtual Hosts"
export MSG_VHOSTS_GENERATED="Configuración de virtual hosts generada"
export MSG_VHOSTS_ENABLED="Virtual Hosts habilitados"
export MSG_VHOSTS_ALREADY_ENABLED="Virtual Hosts ya están habilitados"
export MSG_VHOSTS_NOT_FOUND="Include de Virtual Hosts no encontrado"

# Mensajes de archivo hosts
export MSG_HOSTS_UPDATING="Actualizando /etc/hosts..."
export MSG_HOSTS_UPDATED="Archivo hosts actualizado exitosamente"
export MSG_HOSTS_BACKUP="Creando respaldo del hosts..."

# Mensajes de prompts
export MSG_ENTER_PASSWORD="Ingrese su contraseña de sudo:"
export MSG_CONFIRM_PASSWORD="Confirme su contraseña de sudo:"
export MSG_PASSWORD_MISMATCH="Las contraseñas no coinciden"
export MSG_PASSWORD_INVALID="Contraseña de sudo inválida"
export MSG_PASSWORD_SAVED="Contraseña guardada en Keychain exitosamente"

# Otros mensajes
export MSG_NO_CHANGES="No se detectaron cambios"
export MSG_CHANGES_DETECTED="Se detectaron cambios"
export MSG_VERIFYING="Verificando..."
export MSG_DONE="Hecho"
export MSG_FAILED="Falló"
