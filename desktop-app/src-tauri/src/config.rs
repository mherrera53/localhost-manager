use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub php_install_dir: PathBuf,
    pub projects_config_dir: PathBuf,
    pub default_php_version: Option<String>,
}

/// Get the home directory in a cross-platform way
fn get_home_dir() -> PathBuf {
    #[cfg(target_os = "windows")]
    {
        std::env::var("USERPROFILE")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("C:\\Users\\Default"))
    }

    #[cfg(not(target_os = "windows"))]
    {
        std::env::var("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/tmp"))
    }
}

/// Get the config directory in a cross-platform way
fn get_config_dir() -> PathBuf {
    #[cfg(target_os = "windows")]
    {
        let appdata = std::env::var("APPDATA")
            .map(PathBuf::from)
            .unwrap_or_else(|_| get_home_dir().join("AppData").join("Roaming"));
        appdata.join("localhost-manager")
    }

    #[cfg(target_os = "macos")]
    {
        get_home_dir()
            .join("Library")
            .join("Application Support")
            .join("localhost-manager")
    }

    #[cfg(target_os = "linux")]
    {
        std::env::var("XDG_CONFIG_HOME")
            .map(|p| PathBuf::from(p).join("localhost-manager"))
            .unwrap_or_else(|_| get_home_dir().join(".config").join("localhost-manager"))
    }
}

impl Default for AppConfig {
    fn default() -> Self {
        let _home = get_home_dir();
        let config_dir = get_config_dir();

        Self {
            php_install_dir: config_dir.join("php-versions"),
            projects_config_dir: config_dir.join("projects"),
            default_php_version: None,
        }
    }
}

impl AppConfig {
    pub fn load() -> anyhow::Result<Self> {
        let config_dir = get_config_dir();
        let config_path = config_dir.join("config.json");

        if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)?;
            Ok(serde_json::from_str(&content)?)
        } else {
            Ok(Self::default())
        }
    }

    #[allow(dead_code)]
    pub fn save(&self) -> anyhow::Result<()> {
        let config_dir = get_config_dir();
        std::fs::create_dir_all(&config_dir)?;

        let config_path = config_dir.join("config.json");
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&config_path, content)?;

        Ok(())
    }
}
