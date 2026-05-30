// ============================================
// Re-implemented Tauri commands
// ============================================
// These commands match the frontend contract (app-config.ts, api.ts) and were
// missing from the backend. They cover the app paths configuration, dev-command
// detection and backend dev-server start/stop.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn home_dir() -> PathBuf {
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

fn manager_dir() -> PathBuf {
    home_dir().join("localhost-manager")
}

fn app_config_path() -> PathBuf {
    manager_dir().join("app-config.json")
}

/// The app paths configuration, mirroring the frontend `AppConfig` interface.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PathsConfig {
    pub scripts_base_path: String,
    pub hosts_json_path: String,
    pub apache_config_path: String,
    pub apache_vhosts_path: String,
    pub ssl_certificates_path: String,
    pub logs_path: String,
}

impl PathsConfig {
    fn defaults() -> Self {
        let base = manager_dir();
        let s = |p: PathBuf| p.to_string_lossy().to_string();

        let (apache_config, apache_vhosts) = {
            #[cfg(target_os = "macos")]
            {
                ("/etc/apache2".to_string(), "/etc/apache2/extra".to_string())
            }
            #[cfg(not(target_os = "macos"))]
            {
                (String::new(), String::new())
            }
        };

        Self {
            scripts_base_path: s(base.join("scripts")),
            hosts_json_path: s(base.join("conf").join("hosts.json")),
            apache_config_path: apache_config,
            apache_vhosts_path: apache_vhosts,
            ssl_certificates_path: s(base.join("certs")),
            logs_path: s(base.join("logs")),
        }
    }
}

/// Load the app paths config from ~/localhost-manager/app-config.json.
/// Falls back to sensible defaults if the file does not exist.
#[tauri::command]
pub fn get_app_config() -> Result<PathsConfig, String> {
    let path = app_config_path();
    if path.exists() {
        let content = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&content).map_err(|e| e.to_string())
    } else {
        Ok(PathsConfig::defaults())
    }
}

/// Persist the app paths config.
#[tauri::command]
pub fn save_app_config(config: PathsConfig) -> Result<(), String> {
    let path = app_config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let content = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    std::fs::write(&path, content).map_err(|e| e.to_string())
}

/// Reset the app paths config to defaults and return them.
#[tauri::command]
pub fn reset_app_config() -> Result<PathsConfig, String> {
    let config = PathsConfig::defaults();
    save_app_config(config.clone())?;
    Ok(config)
}

/// Validate that the configured paths exist. Returns an error listing the
/// invalid paths (the frontend surfaces it as a toast).
#[tauri::command]
pub fn validate_config_paths(config: PathsConfig) -> Result<(), String> {
    let checks = [
        ("scripts_base_path", config.scripts_base_path.as_str()),
        ("hosts_json_path", config.hosts_json_path.as_str()),
        ("apache_config_path", config.apache_config_path.as_str()),
        ("apache_vhosts_path", config.apache_vhosts_path.as_str()),
        (
            "ssl_certificates_path",
            config.ssl_certificates_path.as_str(),
        ),
        ("logs_path", config.logs_path.as_str()),
    ];

    let mut errors = Vec::new();
    for (name, p) in checks {
        if p.is_empty() {
            continue;
        }
        if !std::path::Path::new(p).exists() {
            errors.push(format!("{name} not found: {p}"));
        }
    }

    if errors.is_empty() {
        Ok(())
    } else {
        Err(errors.join("; "))
    }
}

/// Detect the dev command for a project directory from its package.json.
#[tauri::command]
pub fn detect_dev_command(path: String) -> Result<String, String> {
    let dir = std::path::Path::new(&path);
    let pkg = dir.join("package.json");
    if !pkg.exists() {
        return Ok(String::new());
    }

    let content = std::fs::read_to_string(&pkg).map_err(|e| e.to_string())?;
    let json: serde_json::Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;

    let manager = if dir.join("yarn.lock").exists() {
        "yarn"
    } else if dir.join("pnpm-lock.yaml").exists() {
        "pnpm"
    } else {
        "npm"
    };

    if let Some(scripts) = json.get("scripts").and_then(|s| s.as_object()) {
        // Prefer a "dev:fast" script when present (faster dev server).
        for key in ["dev:fast", "dev", "start", "serve"] {
            if scripts.contains_key(key) {
                // yarn invokes scripts without "run" (e.g. `yarn dev:fast`).
                return Ok(if manager == "yarn" {
                    format!("yarn {key}")
                } else {
                    format!("{manager} run {key}")
                });
            }
        }
    }

    Ok(String::new())
}

/// A running backend dev service, mirroring the frontend `BackendService`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackendService {
    pub domain: String,
    pub port: u16,
    pub pid: Option<u32>,
    pub status: String,
    pub command: String,
}

/// Start a project's dev server (detached) and record its PID.
#[tauri::command]
pub fn start_backend_service(
    domain: String,
    path: String,
    port: u16,
    command: String,
) -> Result<BackendService, String> {
    #[cfg(target_os = "windows")]
    let mut cmd = {
        let mut c = Command::new("cmd");
        c.arg("/C").arg(&command);
        c
    };
    #[cfg(not(target_os = "windows"))]
    let mut cmd = {
        let mut c = Command::new("sh");
        c.arg("-c").arg(&command);
        c
    };

    let child = cmd
        .current_dir(&path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to start dev server: {e}"))?;

    let pid = child.id();
    let pid_dir = manager_dir().join("services");
    let _ = std::fs::create_dir_all(&pid_dir);
    let _ = std::fs::write(pid_dir.join(format!("{domain}.pid")), pid.to_string());

    Ok(BackendService {
        domain,
        port,
        pid: Some(pid),
        status: "running".to_string(),
        command,
    })
}

/// Stop a backend dev server by PID.
#[tauri::command]
pub fn stop_backend_service(pid: u32) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        Command::new("taskkill")
            .args(["/PID", &pid.to_string(), "/F"])
            .status()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(not(target_os = "windows"))]
    {
        Command::new("kill")
            .arg(pid.to_string())
            .status()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

/// Smart finder: probe common locations for installed server tooling and return
/// best-guess paths to pre-fill the configuration form.
#[tauri::command]
pub fn detect_server_paths() -> PathsConfig {
    let base = manager_dir();
    let s = |p: PathBuf| p.to_string_lossy().to_string();

    let first_existing = |candidates: &[&str]| -> String {
        candidates
            .iter()
            .find(|p| std::path::Path::new(p).exists())
            .map(|p| (*p).to_string())
            .unwrap_or_default()
    };

    let apache_config = first_existing(&[
        "/opt/homebrew/etc/httpd",
        "/usr/local/etc/httpd",
        "/etc/apache2",
        "/Applications/MAMP/conf/apache",
        "/Applications/XAMPP/etc",
        "/Applications/XAMPP/xamppfiles/etc",
        "C:\\xampp\\apache\\conf",
        "C:\\wamp64\\bin\\apache",
        "C:\\laragon\\bin\\apache",
    ]);

    let apache_vhosts = first_existing(&[
        "/opt/homebrew/etc/httpd/extra",
        "/usr/local/etc/httpd/extra",
        "/etc/apache2/extra",
        "/Applications/MAMP/conf/apache/extra",
        "/Applications/XAMPP/etc/extra",
        "/Applications/XAMPP/xamppfiles/etc/extra",
        "C:\\xampp\\apache\\conf\\extra",
        "C:\\laragon\\etc\\apache2\\sites-enabled",
    ]);

    PathsConfig {
        scripts_base_path: s(base.join("scripts")),
        hosts_json_path: s(base.join("conf").join("hosts.json")),
        apache_config_path: apache_config,
        apache_vhosts_path: apache_vhosts,
        ssl_certificates_path: s(base.join("certs")),
        logs_path: s(base.join("logs")),
    }
}
