# Localhost Manager - Desktop App

 A modern, cross-platform desktop application for managing local web development environments (Apache, PHP, MySQL) with support for multiple stacks like MAMP, XAMPP, WAMP, and native installations.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Tauri](https://img.shields.io/badge/Tauri-2.0-24C8DB)
![TypeScript](https://img.shields.io/badge/TypeScript-5.0-3178C6)

##  Features

- ️ **Cross-Platform**: Works on macOS, Windows, and Linux
-  **Multi-Stack Support**: Native (Homebrew), MAMP, XAMPP, WAMP, Laragon
-  **PHP Version Manager**: Install and switch between multiple PHP versions
- ️ **MySQL Management**: Version switching and password reset tools
-  **SSL Certificate Generator**: Auto-generate self-signed certificates
-  **Virtual Hosts Manager**: Create, edit, and organize your local domains
-  **Modern UI**: Built with Tabler.io and Bootstrap 5
-  **Multilingual**: EN, ES, FR, DE, PT
-  **Drag & Drop**: Drag folders into the document root field
-  **Service Control**: Start, stop, restart Apache/MySQL/PHP

##  Prerequisites

### macOS
- **macOS 10.15 (Catalina) or later**
- [Homebrew](https://brew.sh/) - Package manager (for native stack)
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```

### Windows
- **Windows 10 or later**
- [Visual Studio C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
- [WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) (usually pre-installed on Windows 11)

### Linux
- **Ubuntu 20.04+ / Debian 11+ / Fedora 36+**
- `webkit2gtk` and `libayatana-appindicator` libraries

##  Installation Steps (Step by Step)

### Step 1: Install Rust

Rust is required to compile the Tauri backend.

#### macOS / Linux
```bash
# Download and install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Load Rust environment
source $HOME/.cargo/env
```

#### Windows
1. Download [rustup-init.exe](https://win.rustup.rs/)
2. Run the installer
3. Follow the prompts (choose default installation)
4. Restart your terminal

**Verify installation:**
```bash
rustc --version  # Should show: rustc 1.xx.x
cargo --version  # Should show: cargo 1.xx.x
```

### Step 2: Install Node.js

Node.js is required for the frontend build tools.

#### macOS
```bash
# Using Homebrew
brew install node@20
```

#### Windows
1. Download the LTS installer (20.x) from [nodejs.org](https://nodejs.org/)
2. Run the `.msi` installer
3. Follow the installation wizard
4. Restart your terminal

#### Linux (Ubuntu/Debian)
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### Linux (Fedora)
```bash
sudo dnf install nodejs npm
```

**Verify installation:**
```bash
node --version  # Should show: v20.x.x
npm --version   # Should show: 10.x.x
```

### Step 3: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/yourusername/localhost-manager.git

# Navigate to the desktop app folder
cd localhost-manager/desktop-app
```

### Step 4: Install Project Dependencies

```bash
# Install Node.js dependencies
npm install
```

This will install all frontend dependencies including Vite, TypeScript, and Tauri CLI.

### Step 5: Install Platform-Specific Dependencies

#### macOS
No additional dependencies needed if Homebrew is installed.

#### Windows

**Install Visual Studio C++ Build Tools:**
```powershell
# Using winget (Windows Package Manager)
winget install Microsoft.VisualStudio.2022.BuildTools

# Or download manually from:
# https://visualstudio.microsoft.com/visual-cpp-build-tools/
```

During installation, select "Desktop development with C++" workload.

**Install WebView2 (if not already installed):**
```powershell
# Usually pre-installed on Windows 11
# If missing, download from:
# https://developer.microsoft.com/en-us/microsoft-edge/webview2/
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y \
    libwebkit2gtk-4.0-dev \
    build-essential \
    curl \
    wget \
    file \
    libssl-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev
```

#### Linux (Fedora)
```bash
sudo dnf install \
    webkit2gtk4.0-devel \
    openssl-devel \
    curl \
    wget \
    file \
    libappindicator-gtk3-devel \
    librsvg2-devel \
    gcc \
    gcc-c++
```

### Step 6: Run the Application

#### Development Mode (with hot-reload)

```bash
npm run tauri dev
```

This will:
1. Start the Vite dev server (frontend) on http://localhost:1420
2. Compile the Rust backend
3. Launch the application window
4. Enable hot-reload - changes to frontend files will auto-reload

**First run will take 5-10 minutes** as it compiles all Rust dependencies.

#### Production Build

```bash
npm run tauri build
```

Build outputs will be in:
- **macOS**: `src-tauri/target/release/bundle/dmg/` - `.dmg` installer
- **Windows**: `src-tauri/target/release/bundle/msi/` - `.msi` installer
- **Linux**: `src-tauri/target/release/bundle/deb/` - `.deb` package
  - Or `appimage/` for AppImage

##  Project Structure

```
desktop-app/
├── src/                    # Frontend TypeScript/JavaScript
│   ├── main.ts            # Main entry point & event listeners
│   ├── hosts.ts           # Virtual hosts management
│   ├── php-manager.ts     # PHP version manager
│   ├── ui.ts              # UI utilities (toasts, modals)
│   ├── api.ts             # Tauri API calls
│   ├── types.ts           # TypeScript type definitions
│   └── styles.css         # Application styles
├── src-tauri/             # Rust backend
│   ├── src/
│   │   ├── main.rs        # Main Rust entry point
│   │   ├── lib.rs         # Tauri setup
│   │   ├── hosts.rs       # Virtual hosts backend logic
│   │   ├── php_manager.rs # PHP management backend
│   │   ├── config.rs      # Configuration management
│   │   └── types.rs       # Rust type definitions
│   ├── Cargo.toml         # Rust dependencies
│   └── tauri.conf.json    # Tauri configuration
├── index.html             # Main HTML template
├── package.json           # Node.js dependencies
├── vite.config.ts         # Vite configuration
└── README.md              # This file
```

##  Usage Guide

### 1. Select Your Server Stack

Click the **"Server Stack"** dropdown in the sidebar and choose your stack:
- **Native (Homebrew)** - macOS with Homebrew installations
- **MAMP / MAMP PRO** - macOS
- **XAMPP** - Cross-platform
- **WAMP** - Windows
- **Laragon** - Windows
- **Custom Path** - Manual configuration

### 2. Manage Services

Use the control buttons in the sidebar footer:
- **️ Start** - Start Apache
- **️ Stop** - Stop Apache
- ** Restart** - Restart Apache
- ** Power** - Toggle all services (Apache + MySQL + PHP)

### 3. Create Virtual Hosts

1. Click the **+ button** in the sidebar header
2. Fill in the modal:
   - **Domain**: e.g., `myproject.test`
   - **Document Root**: Type path or **drag & drop a folder!**
   - **Group**: Organize hosts into groups
   - **Type**: static, php, vue, react
   - **Active**: Enable/disable the host
   - **SSL**: Auto-generate SSL certificate
   - **Aliases**: Additional domains (one per line)
3. Click **"Save Host"**
4. Click the **️ Generate & Apply Configs** button

### 4. Organize with Groups

- Click **+ button** to create a new group
- Hover over a group name to see the **✏ edit** button
- Click edit to rename the group
- Drag hosts between groups (coming soon)

### 5. Manage PHP/Apache/MySQL Versions

When a host is selected, scroll down to see:
- **PHP Version** selector with install button
- **Apache Version** selector with install button
- **MySQL Version** selector with install button

##  Supported Server Stacks

| Stack | macOS | Windows | Linux | Notes |
|-------|:-----:|:-------:|:-----:|-------|
| Native (Homebrew) |  | No | Yes | Recommended for macOS |
| MAMP / MAMP PRO |  | No | No | Popular macOS stack |
| XAMPP |  | Yes | Yes | Cross-platform |
| WAMP |  | Yes | No | Windows only |
| Laragon |  | Yes | No | Modern Windows stack |
| Custom |  | Yes | Yes | Manual paths |

## Common Issues & Solutions

### macOS: "App is damaged and can't be opened"

This happens because the app isn't signed. Remove the quarantine attribute:
```bash
sudo xattr -rd com.apple.quarantine /Applications/Localhost\ Manager.app
```

### macOS: Command Line Tools not found

```bash
xcode-select --install
```

### Windows: Missing WebView2

Download and install from:
https://developer.microsoft.com/en-us/microsoft-edge/webview2/

### Windows: Build fails with "error: linker `link.exe` not found"

Install Visual Studio C++ Build Tools (see Step 5 above).

### Linux: Missing webkit2gtk

```bash
# Ubuntu/Debian
sudo apt install webkit2gtk-4.0-37

# Fedora
sudo dnf install webkit2gtk4.0
```

### Build fails with "linker `cc` not found"

#### macOS
```bash
xcode-select --install
```

#### Linux
```bash
# Debian/Ubuntu
sudo apt install build-essential

# Fedora
sudo dnf install gcc gcc-c++
```

### Services not starting

1. Check if the stack is actually installed
2. Verify paths in the stack selector are correct
3. Check if ports 80/443 are already in use:
   ```bash
   # macOS/Linux
   sudo lsof -i :80
   sudo lsof -i :443

   # Windows
   netstat -ano | findstr :80
   netstat -ano | findstr :443
   ```

##  Tech Stack

### Backend (Rust)
- **Tauri 2.0** - Desktop app framework
- **tokio** - Async runtime
- **serde** - Serialization/deserialization
- **anyhow** - Error handling

### Frontend
- **TypeScript** - Type-safe JavaScript
- **Vite** - Fast build tool
- **Bootstrap 5** - UI components
- **Tabler.io** - Design system & icons

## Contributing

Contributions are welcome! Here's how:

1. **Fork** the repository
2. **Create** your feature branch:
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. **Commit** your changes:
   ```bash
   git commit -m 'Add some AmazingFeature'
   ```
4. **Push** to the branch:
   ```bash
   git push origin feature/AmazingFeature
   ```
5. **Open** a Pull Request

### Development Guidelines

- Write clear commit messages
- Test on your platform before submitting
- Update documentation if adding features
- Follow existing code style
- Add comments for complex logic

##  License

MIT License - see LICENSE file for details.

Feel free to use this project for any purpose!

##  Bug Reports

Found a bug? Please [open an issue](https://github.com/yourusername/localhost-manager/issues) with:

-  Your OS and version (e.g., "macOS 14.2 Sonoma")
-  Stack you're using (MAMP, XAMPP, Native, etc.)
-  Steps to reproduce the bug
-  Expected behavior vs actual behavior
-  Screenshots if applicable
-  Error messages from console/logs

##  Feature Requests

Have an idea? Open an issue with the `enhancement` label!

##  Support

If you find this project useful:
- Give it a  on GitHub
- Share it with other developers
- Consider contributing!

## Additional Resources

- [Tauri Documentation](https://tauri.app/)
- [Rust Book](https://doc.rust-lang.org/book/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Vite Guide](https://vitejs.dev/guide/)

---

**Made with ️ for the web development community**
