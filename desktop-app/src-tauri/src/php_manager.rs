use crate::config::AppConfig;
use crate::types::{PhpConfig, PhpExtension, PhpVersion};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// Get list of available PHP versions from Homebrew
#[tauri::command]
pub async fn get_available_php_versions() -> Result<Vec<PhpVersion>, String> {
    // For macOS, we'll list Homebrew PHP versions available
    let versions = vec![
        create_php_version("8.4.1", 8, 4, 1),
        create_php_version("8.3.14", 8, 3, 14),
        create_php_version("8.2.26", 8, 2, 26),
        create_php_version("8.1.30", 8, 1, 30),
        create_php_version("8.0.30", 8, 0, 30),
        create_php_version("7.4.33", 7, 4, 33),
    ];

    Ok(versions)
}

/// Get list of installed PHP versions
#[tauri::command]
pub async fn get_installed_php_versions() -> Result<Vec<PhpVersion>, String> {
    let _config = AppConfig::load().map_err(|e| e.to_string())?;
    let mut versions = Vec::new();

    // Check Homebrew installations
    let homebrew_cellar = PathBuf::from("/opt/homebrew/Cellar");
    if homebrew_cellar.exists() {
        if let Ok(entries) = std::fs::read_dir(&homebrew_cellar) {
            for entry in entries.filter_map(Result::ok) {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("php@") || name == "php" {
                    if let Some(version) = extract_php_version(&name, &entry.path()) {
                        versions.push(version);
                    }
                }
            }
        }
    }

    Ok(versions)
}

/// Install a PHP version using Homebrew
#[tauri::command]
pub async fn install_php_version(
    version: String,
    _window: tauri::Window,
) -> Result<String, String> {
    use std::process::Command;

    let formula = if version.starts_with("8.4") {
        "php"
    } else {
        let major_minor = version.split('.').take(2).collect::<Vec<_>>().join(".");
        &format!("php@{}", major_minor)
    };

    // Execute brew install with output streaming
    let output = Command::new("brew")
        .args(["install", formula])
        .output()
        .map_err(|e| format!("Failed to execute brew: {}", e))?;

    if output.status.success() {
        Ok(format!("PHP {} installed successfully", version))
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        Err(format!("Installation failed: {}", error))
    }
}

/// Uninstall a PHP version
#[tauri::command]
pub async fn uninstall_php_version(version: String) -> Result<String, String> {
    use std::process::Command;

    let major_minor = version.split('.').take(2).collect::<Vec<_>>().join(".");
    let formula = if version.starts_with("8.4") {
        "php"
    } else {
        &format!("php@{}", major_minor)
    };

    let output = Command::new("brew")
        .args(["uninstall", formula])
        .output()
        .map_err(|e| format!("Failed to execute brew: {}", e))?;

    if output.status.success() {
        Ok(format!("PHP {} uninstalled successfully", version))
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        Err(format!("Uninstallation failed: {}", error))
    }
}

/// Get PHP configuration for a specific version
#[tauri::command]
pub async fn get_php_config(version: String) -> Result<PhpConfig, String> {
    let install_path =
        find_php_install_path(&version).ok_or_else(|| format!("PHP {} not found", version))?;

    let php_ini_path = find_php_ini_path(&install_path);
    let extensions = get_php_extensions(&version)?;
    let settings = read_php_ini_settings(&php_ini_path)?;

    Ok(PhpConfig {
        version,
        install_path: install_path.to_string_lossy().to_string(),
        php_ini_path: php_ini_path.to_string_lossy().to_string(),
        extensions,
        settings,
    })
}

/// Update PHP ini setting
#[tauri::command]
pub async fn update_php_ini_setting(
    version: String,
    key: String,
    value: String,
) -> Result<(), String> {
    let install_path =
        find_php_install_path(&version).ok_or_else(|| format!("PHP {} not found", version))?;

    let php_ini_path = find_php_ini_path(&install_path);

    // Read current content
    let content = std::fs::read_to_string(&php_ini_path)
        .map_err(|e| format!("Failed to read php.ini: {}", e))?;

    // Update or add setting
    let mut lines: Vec<String> = content.lines().map(String::from).collect();
    let mut found = false;

    for line in &mut lines {
        if line.trim_start().starts_with(&key) {
            *line = format!("{} = {}", key, value);
            found = true;
            break;
        }
    }

    if !found {
        lines.push(format!("{} = {}", key, value));
    }

    // Write back
    std::fs::write(&php_ini_path, lines.join("\n"))
        .map_err(|e| format!("Failed to write php.ini: {}", e))?;

    Ok(())
}

// Helper functions

fn create_php_version(version: &str, major: u8, minor: u8, patch: u8) -> PhpVersion {
    PhpVersion {
        version: version.to_string(),
        major,
        minor,
        patch,
        installed: false,
        install_path: None,
        download_url: None,
    }
}

fn extract_php_version(_name: &str, path: &PathBuf) -> Option<PhpVersion> {
    // Extract version from Homebrew Cellar directory
    if let Ok(entries) = std::fs::read_dir(path) {
        if let Some(first_version) = entries.filter_map(Result::ok).next() {
            let version_str = first_version.file_name().to_string_lossy().to_string();
            let parts: Vec<&str> = version_str.split('.').collect();

            if parts.len() >= 2 {
                let major = parts[0].parse().unwrap_or(0);
                let minor = parts[1].parse().unwrap_or(0);
                let patch = parts.get(2).and_then(|p| p.parse().ok()).unwrap_or(0);

                return Some(PhpVersion {
                    version: version_str.clone(),
                    major,
                    minor,
                    patch,
                    installed: true,
                    install_path: Some(first_version.path().to_string_lossy().to_string()),
                    download_url: None,
                });
            }
        }
    }

    None
}

fn find_php_install_path(version: &str) -> Option<PathBuf> {
    let major_minor = version.split('.').take(2).collect::<Vec<_>>().join(".");
    let paths = vec![
        PathBuf::from(format!("/opt/homebrew/Cellar/php/{}", version)),
        PathBuf::from(format!(
            "/opt/homebrew/Cellar/php@{}/{}",
            major_minor, version
        )),
    ];

    paths.into_iter().find(|p| p.exists())
}

fn find_php_ini_path(install_path: &Path) -> PathBuf {
    let mut ini_path = install_path.to_path_buf();
    ini_path.push("etc");
    ini_path.push("php.ini");

    if !ini_path.exists() {
        ini_path.set_file_name("php.ini-development");
    }

    ini_path
}

fn get_php_extensions(_version: &str) -> Result<Vec<PhpExtension>, String> {
    // This would parse php -m output
    Ok(vec![
        PhpExtension {
            name: "mbstring".to_string(),
            enabled: true,
            version: None,
        },
        PhpExtension {
            name: "curl".to_string(),
            enabled: true,
            version: None,
        },
        PhpExtension {
            name: "openssl".to_string(),
            enabled: true,
            version: None,
        },
    ])
}

fn read_php_ini_settings(php_ini_path: &Path) -> Result<HashMap<String, String>, String> {
    if !php_ini_path.exists() {
        return Ok(HashMap::new());
    }

    let content = std::fs::read_to_string(php_ini_path)
        .map_err(|e| format!("Failed to read php.ini: {}", e))?;

    let mut settings = HashMap::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with(';') || trimmed.is_empty() {
            continue;
        }

        if let Some(pos) = trimmed.find('=') {
            let key = trimmed[..pos].trim().to_string();
            let value = trimmed[pos + 1..].trim().to_string();
            settings.insert(key, value);
        }
    }

    Ok(settings)
}
