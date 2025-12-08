# Windows Release Guide - Localhost Manager

##  Configuración Completada

El proyecto ya está configurado para compilar instaladores de Windows. A continuación se explica cómo generar los instaladores.

##  Opciones para Compilar

### Opción 1: GitHub Actions (RECOMENDADO - Automático)

**La forma más fácil desde macOS:**

1. **Hacer commit de todos los cambios:**
   ```bash
   cd /Users/mario/localhost-manager
   git add .
   git commit -m "feat: Windows support with cross-platform paths"
   git push origin main
   ```

2. **El workflow de GitHub Actions compilará automáticamente:**
   - Se ejecuta automáticamente en cada push a `main` o `release`
   - También puedes ejecutarlo manualmente desde GitHub:
     - Ve a tu repositorio en GitHub
     - Click en "Actions"
     - Selecciona "Build Windows Release"
     - Click en "Run workflow"

3. **Descargar el instalador:**
   - Una vez completado el workflow, ve a "Actions" en GitHub
   - Click en el workflow completado
   - Descarga el artifact "localhost-manager-windows-nsis"
   - Contiene el archivo `.exe` instalador

### Opción 2: Crear una Release (Para versiones oficiales)

```bash
# Crear y push un tag de versión
git tag -a v0.1.0 -m "Release v0.1.0 - Windows Support"
git push origin v0.1.0
```

Esto automáticamente:
- Compila el instalador de Windows
- Crea una GitHub Release
- Adjunta los instaladores (NSIS y MSI)

### Opción 3: Compilar en Windows (Manual)

Si tienes acceso a una máquina Windows, sigue la guía completa en `BUILD_WINDOWS.md`.

##  Salidas del Build

El proceso genera dos tipos de instaladores:

### 1. NSIS Installer (Recomendado para usuarios)
- **Archivo:** `Localhost Manager_0.1.0_x64-setup.exe`
- **Características:**
  - Instalador moderno y fácil de usar
  - Soporte multiidioma (EN, ES, FR, DE, PT)
  - Crea accesos directos automáticamente
  - Instalación por usuario (no requiere admin)

### 2. MSI Installer (Para empresas)
- **Archivo:** `Localhost Manager_0.1.0_x64_en-US.msi`
- **Características:**
  - Compatible con Group Policy
  - Ideal para despliegues corporativos

##  Características Implementadas para Windows

###  Rutas Multi-Plataforma
```
Windows: %APPDATA%\localhost-manager\
macOS:   ~/Library/Application Support/localhost-manager/
Linux:   ~/.config/localhost-manager/
```

###  Soporte para Stacks de Windows
- **XAMPP** - `C:\xampp\`
- **WAMP** - `C:\wamp64\`
- **Laragon** - `C:\laragon\`

###  Privilegios de Administrador
- UAC elevation para operaciones que lo requieran
- Edición del archivo hosts (`C:\Windows\System32\drivers\etc\hosts`)
- Control de servicios de Windows

###  Scripts PowerShell
Creados scripts equivalentes para Windows:
- `scripts/windows/configure-services.ps1`

##  Archivos de Configuración

### Configuración de Tauri
`src-tauri/tauri.conf.json` - Configurado con:
- NSIS installer optimizado
- Soporte MSI
- Ícono de Windows (`.ico`)
- Configuración de WebView2

### Workflow de GitHub Actions
`.github/workflows/build-windows.yml` - Compilación automática en la nube

### Documentación
- `BUILD_WINDOWS.md` - Guía completa de compilación
- `WINDOWS_RELEASE.md` - Este archivo

##  Cómo Distribuir

### Distribución Simple
1. Obtén el archivo `.exe` de GitHub Actions o GitHub Release
2. Distribuye el archivo a los usuarios
3. Los usuarios ejecutan el instalador
4. ¡Listo! No se requieren dependencias adicionales

### Verificación del Instalador

Una vez descargado el `.exe`, verifica que:
- Tamaño: ~30-50 MB (incluye WebView2 bootstrapper)
- Idiomas disponibles durante instalación
- Crea accesos directos en Escritorio y Menú Inicio
- Se instala en: `%LOCALAPPDATA%\Programs\localhost-manager\`

## 🔐 Firma de Código (Opcional)

Para distribución profesional, considera firmar el instalador:

1. **Obtén un certificado de firma de código:**
   - DigiCert, Sectigo, etc.
   - ~$100-500 USD/año

2. **Configura en `tauri.conf.json`:**
   ```json
   {
     "bundle": {
       "windows": {
         "certificateThumbprint": "TU_THUMBPRINT_AQUI",
         "digestAlgorithm": "sha256",
         "timestampUrl": "http://timestamp.digicert.com"
       }
     }
   }
   ```

3. **Los usuarios NO verán advertencias de Windows Defender**

##  Checklist de Release

- [ ] Todos los cambios committed y pushed
- [ ] Version actualizada en `tauri.conf.json` y `package.json`
- [ ] Changelog actualizado
- [ ] Tag de git creado (`v0.1.0`)
- [ ] GitHub Actions workflow ejecutado exitosamente
- [ ] Instalador descargado y probado en Windows
- [ ] Release notes escritas
- [ ] Instalador publicado en GitHub Releases

##  Troubleshooting

### El workflow falla con error de compilación
- Revisa los logs en GitHub Actions
- Asegúrate que `Cargo.toml` no tenga dependencias incompatibles con Windows
- Verifica que no hay paths hardcoded de Unix

### El instalador no inicia en Windows
- El usuario debe tener WebView2 instalado (Windows 10/11 lo incluye)
- Verificar que no haya antivirus bloqueando

### Errores de permisos
- El instalador `perUser` no requiere admin
- Si se necesita admin, el instalador lo solicitará vía UAC

## 📚 Recursos Adicionales

- [Tauri Windows Guide](https://tauri.app/v1/guides/building/windows)
- [NSIS Documentation](https://nsis.sourceforge.io/Docs/)
- [GitHub Actions](https://docs.github.com/actions)
- [Code Signing](https://tauri.app/v1/guides/distribution/sign-windows)

## ✨ Próximos Pasos Sugeridos

1. **Testear en Windows:**
   - Descargar el instalador de GitHub Actions
   - Probar en Windows 10 y Windows 11
   - Verificar todas las funcionalidades

2. **Distribución:**
   - Publicar en GitHub Releases
   - Opcionalmente: Microsoft Store
   - Crear página de descargas

3. **Mejoras:**
   - Auto-updater de Tauri
   - Crash reporting (Sentry)
   - Telemetría de uso (opcional)

---

**¡El proyecto ya está listo para compilar instaladores de Windows!** 

Solo haz push a GitHub y el workflow creará automáticamente los instaladores.
