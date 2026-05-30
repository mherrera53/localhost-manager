# Localhost Manager - Windows Installer

Professional NSIS installer for Localhost Manager on Windows.

## Supported Stacks

- **XAMPP** - Apache Friends (C:\xampp)
- **WAMP** - WampServer (C:\wamp64)
- **Laragon** - Laragon.org (C:\laragon)

## Building the Installer

### Prerequisites

1. **Rust** - https://rustup.rs/
2. **Node.js** - https://nodejs.org/
3. **NSIS** - https://nsis.sourceforge.io/

### Build Commands

```powershell
# Full build (compile + installer)
.\build-installer.ps1

# Build with custom version
.\build-installer.ps1 -Version "1.2.0"

# Skip Rust compilation (use existing build)
.\build-installer.ps1 -SkipBuild

# Debug build
.\build-installer.ps1 -Debug
```

### Output

The installer will be created at:
```
installer/windows/output/LocalhostManager-Setup-{version}.exe
```

## Manual Installation

If you don't want to use the installer:

1. Run the setup wizard:
```powershell
.\scripts\windows\setup.ps1
```

2. Or manually:
```powershell
# Create directories
mkdir $env:USERPROFILE\localhost-manager\conf
mkdir $env:USERPROFILE\localhost-manager\certs
mkdir $env:USERPROFILE\localhost-manager\scripts\windows

# Copy scripts
Copy-Item .\scripts\windows\*.ps1 $env:USERPROFILE\localhost-manager\scripts\windows\

# Run initial setup
.\scripts\windows\setup.ps1
```

## Scripts

| Script | Description |
|--------|-------------|
| `setup.ps1` | Initial setup wizard |
| `detect-stack.ps1` | Auto-detect installed stacks |
| `generate-all.ps1` | Generate all configurations |
| `generate-vhosts-config.ps1` | Generate Apache virtual hosts |
| `generate-certificates.ps1` | Generate SSL certificates |
| `update-hosts.ps1` | Update Windows hosts file |
| `install.ps1` | Apply configurations |

## Usage Examples

### Detect Stack
```powershell
# Human readable
.\detect-stack.ps1

# Detailed info
.\detect-stack.ps1 -Detailed

# JSON output (for scripts)
.\detect-stack.ps1 -Json
```

### Generate Configurations
```powershell
# Auto-detect stack
.\generate-all.ps1

# Specify stack
.\generate-all.ps1 -Stack xampp
.\generate-all.ps1 -Stack wamp
.\generate-all.ps1 -Stack laragon
```

### Apply Configurations (requires admin)
```powershell
# Run as Administrator
.\install.ps1 -Stack xampp
```

## SSL Certificates

To avoid browser SSL warnings:

1. Open `certmgr.msc`
2. Navigate to: Trusted Root Certification Authorities > Certificates
3. Right-click > All Tasks > Import
4. Select certificates from `%USERPROFILE%\localhost-manager\certs`

## Directory Structure

```
%USERPROFILE%\localhost-manager\
├── conf\
│   ├── hosts.json          # Virtual hosts configuration
│   ├── settings.json       # App settings
│   ├── stack.conf          # Selected stack
│   └── vhosts.conf         # Generated Apache config
├── certs\
│   ├── default.crt         # Default SSL certificate
│   ├── default.key         # Default SSL key
│   └── *.crt/*.key         # Per-domain certificates
├── backups\
│   └── hosts_*.bak         # Hosts file backups
└── scripts\
    └── windows\
        └── *.ps1           # PowerShell scripts
```

## Troubleshooting

### Apache won't start
1. Check for port conflicts: `netstat -ano | findstr :80`
2. Verify config: `httpd.exe -t`
3. Check error log in stack's logs directory

### SSL not working
1. Ensure certificates exist in `%USERPROFILE%\localhost-manager\certs`
2. Verify SSL modules are enabled in Apache
3. Import certificates to Windows trust store

### Scripts fail with permission error
- Run PowerShell as Administrator
- Or set execution policy: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

## License

MIT License
