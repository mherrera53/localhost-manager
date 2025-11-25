# Building Localhost Manager for Windows

This guide explains how to build the Localhost Manager desktop application for Windows.

## Prerequisites

### 1. Install Rust
```powershell
# Download and install rustup from https://rustup.rs/
# Or use winget:
winget install Rustlang.Rustup
```

### 2. Install Node.js
```powershell
# Download from https://nodejs.org/
# Or use winget:
winget install OpenJS.NodeJS.LTS
```

### 3. Install Visual Studio Build Tools
The Tauri framework requires the Microsoft C++ build tools.

**Option A: Install Visual Studio 2022 Community** (recommended)
- Download from: https://visualstudio.microsoft.com/downloads/
- During installation, select "Desktop development with C++"

**Option B: Install Build Tools only**
```powershell
winget install Microsoft.VisualStudio.2022.BuildTools
```

Required components:
- MSVC v143 - VS 2022 C++ x64/x86 build tools
- Windows 10/11 SDK

### 4. Install WebView2
Windows 10/11 already includes WebView2, but if needed:
```powershell
winget install Microsoft.EdgeWebView2Runtime
```

## Build Instructions

### 1. Clone and Setup
```powershell
cd C:\Users\YourUsername\Projects
git clone <repository-url>
cd localhost-manager\desktop-app

# Install Node dependencies
npm install
```

### 2. Development Build
```powershell
# Run in development mode
npm run tauri dev
```

### 3. Production Build
```powershell
# Build production installer
npm run tauri build
```

The installer will be created in:
```
desktop-app\src-tauri\target\release\bundle\
```

### Build Outputs

#### NSIS Installer (.exe)
- Location: `src-tauri\target\release\bundle\nsis\Localhost Manager_0.1.0_x64-setup.exe`
- This is a standard Windows installer that most users prefer
- Supports multilingual installation (EN, ES, FR, DE, PT)

#### MSI Installer (Windows Installer)
- Location: `src-tauri\target\release\bundle\msi\Localhost Manager_0.1.0_x64_en-US.msi`
- Enterprise-friendly installer
- Can be deployed via Group Policy

## Platform-Specific Features

### Windows Paths
The application automatically uses Windows-appropriate paths:
- **Config**: `%APPDATA%\localhost-manager\`
- **Projects**: `%APPDATA%\localhost-manager\projects\`
- **PHP Versions**: `%APPDATA%\localhost-manager\php-versions\`

### Supported Stacks on Windows
- **XAMPP** - Default paths: `C:\xampp\`
- **WAMP** - Default paths: `C:\wamp64\`
- **Laragon** - Default paths: `C:\laragon\`

### Administrator Privileges
Some operations require administrator privileges (editing hosts file, managing services).
The app uses Windows UAC (User Account Control) to request elevation when needed.

## Troubleshooting

### Build Errors

**Error: "unable to find vcvarsall.bat"**
- Install Visual Studio Build Tools with C++ support

**Error: "linker 'link.exe' not found"**
- Ensure MSVC build tools are installed via Visual Studio installer

**Error: "WebView2 not found"**
```powershell
winget install Microsoft.EdgeWebView2Runtime
```

### Runtime Issues

**App won't start**
- Check WebView2 is installed: `reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"`

**Services not detected**
- Run the app as Administrator
- Check that XAMPP/WAMP/Laragon is installed

## Cross-Compilation from macOS/Linux

Cross-compiling to Windows from macOS/Linux is possible but complex. Recommended approaches:

### Option 1: Use GitHub Actions (Recommended)
Create `.github/workflows/build-windows.yml`:
```yaml
name: Build Windows

on:
  push:
    tags:
      - 'v*'

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: dtolnay/rust-toolchain@stable
      - run: npm install
        working-directory: desktop-app
      - run: npm run tauri build
        working-directory: desktop-app
      - uses: actions/upload-artifact@v4
        with:
          name: windows-installer
          path: desktop-app/src-tauri/target/release/bundle/nsis/*.exe
```

### Option 2: Use a Windows VM
- Install VirtualBox or VMware
- Create Windows 10/11 VM
- Follow normal build instructions inside VM

### Option 3: Use Wine + Cross-compilation (Advanced)
```bash
# On macOS/Linux
rustup target add x86_64-pc-windows-msvc

# Note: This is complex and not recommended for beginners
# See: https://tauri.app/v1/guides/building/cross-platform/
```

## Installer Customization

### NSIS Installer Options
Edit `src-tauri/tauri.conf.json`:
```json
{
  "bundle": {
    "windows": {
      "nsis": {
        "languages": ["English", "Spanish", "French", "German", "Portuguese"],
        "displayLanguageSelector": true,
        "compression": "lzma",
        "installMode": "perUser"
      }
    }
  }
}
```

### Code Signing
For production releases, sign your installer:
```powershell
# Get a code signing certificate
# Then configure in tauri.conf.json:
{
  "bundle": {
    "windows": {
      "certificateThumbprint": "YOUR_CERTIFICATE_THUMBPRINT",
      "digestAlgorithm": "sha256",
      "timestampUrl": "http://timestamp.digicert.com"
    }
  }
}
```

## Distribution

### Manual Distribution
1. Build the installer: `npm run tauri build`
2. Distribute the `.exe` file from `src-tauri\target\release\bundle\nsis\`
3. Users run the installer - no additional dependencies needed

### Microsoft Store (Optional)
To publish to Microsoft Store:
1. Create MSIX package
2. Register for Partner Center account
3. Follow Microsoft's submission process

## Development Tips

### Hot Reload
The development server supports hot reload:
```powershell
npm run tauri dev
# Edit files in src/ - changes will auto-reload
```

### Debug Console
Press `F12` in the app window to open DevTools

### Logs
Application logs are in:
```
%APPDATA%\localhost-manager\logs\
```

## Support

For issues specific to Windows builds:
- Check logs in `%APPDATA%\localhost-manager\logs\`
- Verify all prerequisites are installed
- Try building in a fresh Windows environment
- Report issues on GitHub with:
  - Windows version
  - Build error output
  - Rust version (`rustc --version`)
  - Node version (`node --version`)
