# Localhost Manager - Architecture Diagrams

## System Architecture

```mermaid
graph TB
    subgraph "Desktop App (Tauri)"
        UI[React/TypeScript UI]
        Backend[Rust Backend]
        Config[Config Manager]
    end

    subgraph "Web Interface"
        PHP[PHP Interface]
        Web[index.php]
    end

    subgraph "System Services"
        Apache[Apache 2.4]
        PHP_FPM[PHP-FPM 8.4]
        MySQL[MySQL 8.4]
    end

    subgraph "Configuration Files"
        HostsJSON[conf/hosts.json]
        VHostsConf[conf/vhosts.conf]
        HostsTxt[conf/hosts.txt]
    end

    subgraph "Security"
        Certs[SSL Certificates]
        Keychain[macOS Keychain]
    end

    UI --> Backend
    Backend --> Config
    Config --> HostsJSON

    PHP --> Web
    Web --> HostsJSON

    HostsJSON --> VHostsConf
    HostsJSON --> HostsTxt
    VHostsConf --> Apache
    HostsTxt --> EtcHosts["etc/hosts file"]

    Apache --> PHP_FPM
    Apache --> Certs

    Keychain -.->|sudo password| Config
    Keychain -.->|sudo password| Web
```

## Configuration Flow

```mermaid
flowchart TD
    Start([User Opens App]) --> LoadConfig[Load hosts.json]
    LoadConfig --> DisplayUI[Display Grouped Hosts]

    DisplayUI --> UserAction{User Action}

    UserAction -->|Add Host| AddForm[Fill Add Form]
    AddForm --> ValidateDomain[Validate Domain]
    ValidateDomain --> SaveHost[Save to hosts.json]
    SaveHost --> DisplayUI

    UserAction -->|Toggle Host| ToggleState[Change Enabled State]
    ToggleState --> SaveHost

    UserAction -->|Generate Certs| GenCerts[Generate SSL Certificates]
    GenCerts --> OpenSSL[Run openssl commands]
    OpenSSL --> SaveCert[Save .crt and .key]
    SaveCert --> DisplayUI

    UserAction -->|Generate Config| GenVHosts[Generate vhosts.conf]
    GenVHosts --> FilterActive[Filter Active Hosts Only]
    FilterActive --> CreateVHost[Create VirtualHost blocks]
    CreateVHost --> WriteConf[Write vhosts.conf]
    WriteConf --> DisplayUI

    UserAction -->|Apply Config| ApplyConf[Apply Configuration]
    ApplyConf --> CopyCerts["Copy certs to etc/apache2/ssl"]
    CopyCerts --> CopyVHosts[Copy vhosts.conf to Apache]
    CopyVHosts --> UpdateHosts["Update etc-hosts"]
    UpdateHosts --> RestartApache[Restart Apache]
    RestartApache --> Success([Configuration Applied])
```

## Certificate Generation Process

```mermaid
sequenceDiagram
    participant User
    participant UI as Desktop App / Web UI
    participant Script as generate-certificates.sh
    participant OpenSSL
    participant FS as File System

    User->>UI: Click "Generate Certificates"
    UI->>Script: Execute script with domain list

    loop For each active domain
        Script->>OpenSSL: Generate private key
        OpenSSL->>FS: Save domain.key

        Script->>OpenSSL: Generate CSR
        OpenSSL->>FS: Save domain.csr

        Script->>OpenSSL: Self-sign certificate (10 years)
        OpenSSL->>FS: Save domain.crt

        FS-->>Script: Certificate created
    end

    Script-->>UI: All certificates generated
    UI-->>User: Show success message
```

## Desktop App Structure

```mermaid
graph LR
    subgraph "Frontend (React + TypeScript)"
        Components[React Components]
        State[State Management]
        Styles[Tailwind CSS]
    end

    subgraph "Backend (Rust + Tauri)"
        Commands[Tauri Commands]
        FileIO[File I/O Operations]
        Sudo[Sudo Operations]
        ConfigMgr[Config Manager]
    end

    subgraph "System Integration"
        Apache[Apache Control]
        Hosts["etc-hosts Management"]
        Certs[Certificate Management]
        Services[Service Control]
    end

    Components --> State
    State --> Styles
    Components --> Commands

    Commands --> FileIO
    Commands --> Sudo
    Commands --> ConfigMgr

    FileIO --> Apache
    FileIO --> Hosts
    Sudo --> Apache
    ConfigMgr --> Certs
    ConfigMgr --> Services
```

## Group Detection Logic

```mermaid
flowchart TD
    Start([New Host Added]) --> GetPath[Get documentRoot path]
    GetPath --> Extract[Extract directory name]

    Extract --> CheckExisting{Group exists?}

    CheckExisting -->|Yes| AssignExisting[Assign to existing group]
    CheckExisting -->|No| CreateNew[Create new group]

    AssignExisting --> UpdateJSON[Update hosts.json]
    CreateNew --> UpdateJSON

    UpdateJSON --> End([Host grouped])

    style CreateNew fill:#90EE90
    style AssignExisting fill:#87CEEB
```

## Security Model

```mermaid
graph TB
    subgraph "Security Layers"
        direction TB

        Keychain[macOS Keychain]
        SSL[SSL Certificates]
        Sudo[Sudo Elevation]
        FilePerms[File Permissions]
    end

    subgraph "Protected Operations"
        EditHosts[Edit /etc/hosts]
        CopyConfig[Copy Apache config]
        RestartService[Restart Apache]
        CopyCerts[Copy certificates]
    end

    subgraph "Stored Secrets"
        SudoPass[Sudo Password]
        PrivKeys[Private Keys]
    end

    Keychain -->|Stores| SudoPass
    FilePerms -->|Protects| PrivKeys
    SSL -->|Generates| PrivKeys

    SudoPass -->|Authorizes| Sudo
    Sudo -->|Enables| EditHosts
    Sudo -->|Enables| CopyConfig
    Sudo -->|Enables| RestartService
    Sudo -->|Enables| CopyCerts

    style Keychain fill:#FFD700
    style SSL fill:#90EE90
    style SudoPass fill:#FF6B6B
    style PrivKeys fill:#FF6B6B
```

## Cross-Platform Support

```mermaid
graph TB
    subgraph "Platform Detection"
        Runtime[Rust Runtime]
        OS{Operating System}
    end

    Runtime --> OS

    OS -->|macOS| MacPaths[macOS Paths]
    OS -->|Windows| WinPaths[Windows Paths]
    OS -->|Linux| LinuxPaths[Linux Paths]

    MacPaths --> MacConfig["~/Library/Application Support/<br/>localhost-manager/"]
    WinPaths --> WinConfig["%APPDATA%<br/>localhost-manager/"]
    LinuxPaths --> LinuxConfig["~/.config/<br/>localhost-manager/"]

    MacConfig --> ConfigFiles[Config Files]
    WinConfig --> ConfigFiles
    LinuxConfig --> ConfigFiles

    subgraph "Supported Stacks"
        MacStack[Native Apache<br/>Homebrew]
        WinStack[XAMPP<br/>WAMP<br/>Laragon]
        LinuxStack[Native Apache<br/>apt/yum]
    end

    MacPaths -.-> MacStack
    WinPaths -.-> WinStack
    LinuxPaths -.-> LinuxStack
```
