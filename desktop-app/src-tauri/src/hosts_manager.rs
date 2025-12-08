use crate::types::{ServicesStatus, VirtualHost, VirtualHostAlias};
use anyhow::Result;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x08000000;

// ============================================
// Helper Functions for Command Execution
// ============================================

/// Execute a command and return stdout if successful
fn run_command(cmd: &str, args: &[&str]) -> Option<String> {
    let mut command = Command::new(cmd);
    command.args(args);

    #[cfg(target_os = "windows")]
    command.creation_flags(CREATE_NO_WINDOW);

    command
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
}

/// Execute a command and return the full output (for Windows with hidden window)
#[cfg(target_os = "windows")]
fn run_windows_command(cmd: &str, args: &[&str]) -> std::io::Result<std::process::Output> {
    Command::new(cmd)
        .args(args)
        .creation_flags(CREATE_NO_WINDOW)
        .output()
}

#[cfg(not(target_os = "windows"))]
fn run_windows_command(cmd: &str, args: &[&str]) -> std::io::Result<std::process::Output> {
    Command::new(cmd).args(args).output()
}

/// Try to find a binary in multiple paths and execute with given args
fn find_and_execute(paths: &[&str], args: &[&str]) -> Option<String> {
    for path in paths {
        if let Some(output) = run_command(path, args) {
            return Some(output);
        }
    }
    None
}

/// Check if a command exists using 'which' (Unix) or 'where' (Windows)
fn command_exists(cmd: &str) -> bool {
    let check_cmd = if cfg!(target_os = "windows") {
        "where"
    } else {
        "which"
    };
    run_command(check_cmd, &[cmd]).is_some()
}

fn get_home_dir() -> String {
    if cfg!(target_os = "windows") {
        std::env::var("USERPROFILE").unwrap_or_else(|_| {
            // Fallback: try to construct from HOMEDRIVE + HOMEPATH
            let drive = std::env::var("HOMEDRIVE").unwrap_or_else(|_| String::from("C:"));
            let path =
                std::env::var("HOMEPATH").unwrap_or_else(|_| String::from("\\Users\\Default"));
            format!("{}{}", drive, path)
        })
    } else {
        std::env::var("HOME").unwrap_or_else(|_| {
            // Fallback: try to get from user info
            String::from("/tmp")
        })
    }
}

fn get_hosts_file_path() -> PathBuf {
    let home = get_home_dir();
    if cfg!(target_os = "windows") {
        PathBuf::from(format!("{}\\localhost-manager\\conf\\hosts.json", home))
    } else {
        PathBuf::from(format!("{}/localhost-manager/conf/hosts.json", home))
    }
}

#[tauri::command]
pub async fn get_virtual_hosts() -> Result<HashMap<String, VirtualHost>, String> {
    let hosts_file = get_hosts_file_path();

    if !hosts_file.exists() {
        return Ok(HashMap::new());
    }

    let content =
        fs::read_to_string(&hosts_file).map_err(|e| format!("Failed to read hosts file: {}", e))?;

    let hosts_raw: HashMap<String, serde_json::Value> =
        serde_json::from_str(&content).map_err(|e| format!("Failed to parse hosts file: {}", e))?;

    let mut hosts = HashMap::new();

    for (domain, host_data) in hosts_raw {
        if let Ok(host_obj) =
            serde_json::from_value::<serde_json::Map<String, serde_json::Value>>(host_data.clone())
        {
            let docroot = host_obj
                .get("docroot")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();

            let group = host_obj
                .get("group")
                .and_then(|v| v.as_str())
                .unwrap_or("Uncategorized")
                .to_string();

            let active = host_obj
                .get("active")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);

            let ssl = host_obj
                .get("ssl")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);

            let host_type = host_obj
                .get("type")
                .and_then(|v| v.as_str())
                .unwrap_or("static")
                .to_string();

            // Parse aliases
            let mut aliases = Vec::new();

            // Check for aliases array
            if let Some(aliases_val) = host_obj.get("aliases") {
                if let Some(aliases_arr) = aliases_val.as_array() {
                    for alias_val in aliases_arr {
                        if let Some(alias_obj) = alias_val.as_object() {
                            let alias = VirtualHostAlias {
                                id: alias_obj
                                    .get("id")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .to_string(),
                                value: alias_obj
                                    .get("value")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .to_string(),
                                active: alias_obj
                                    .get("active")
                                    .and_then(|v| v.as_bool())
                                    .unwrap_or(true),
                            };
                            if !alias.value.is_empty() {
                                aliases.push(alias);
                            }
                        } else if let Some(alias_str) = alias_val.as_str() {
                            // Legacy string format
                            aliases.push(VirtualHostAlias {
                                id: format!("alias_{}", uuid::Uuid::new_v4()),
                                value: alias_str.to_string(),
                                active: true,
                            });
                        }
                    }
                }
            }

            // Check for legacy 'alias' field
            if aliases.is_empty() {
                if let Some(alias_val) = host_obj.get("alias") {
                    if let Some(alias_str) = alias_val.as_str() {
                        if !alias_str.is_empty() {
                            aliases.push(VirtualHostAlias {
                                id: format!("alias_{}", uuid::Uuid::new_v4()),
                                value: alias_str.to_string(),
                                active: true,
                            });
                        }
                    }
                }
            }

            let host = VirtualHost {
                domain: domain.clone(),
                docroot,
                aliases,
                group,
                active,
                ssl,
                host_type,
            };

            hosts.insert(domain, host);
        }
    }

    Ok(hosts)
}

#[tauri::command]
pub async fn get_services_status() -> Result<ServicesStatus, String> {
    let apache = check_process("httpd");
    let mysql = check_process("mysqld");
    let php = check_process("php-fpm");

    Ok(ServicesStatus {
        apache,
        mysql,
        php,
        all_running: apache && mysql && php,
    })
}

fn check_process(name: &str) -> bool {
    if cfg!(target_os = "windows") {
        // Windows: Use tasklist command to check for running processes
        let search_name = match name {
            "httpd" => "httpd.exe",
            "mysqld" => "mysqld.exe",
            "php-fpm" => "php-cgi.exe", // On Windows, PHP typically runs as php-cgi
            _ => name,
        };

        let mut cmd = Command::new("tasklist");
        cmd.args(["/FI", &format!("IMAGENAME eq {}", search_name), "/NH"]);
        #[cfg(target_os = "windows")]
        cmd.creation_flags(CREATE_NO_WINDOW);
        let output = cmd.output();

        match output {
            Ok(out) => {
                let stdout = String::from_utf8_lossy(&out.stdout);
                stdout.contains(search_name)
            }
            Err(_) => false,
        }
    } else {
        // macOS/Linux: Use pgrep
        let output = if name == "php-fpm" {
            Command::new("pgrep").args(["-f", name]).output()
        } else {
            Command::new("pgrep").arg(name).output()
        };

        match output {
            Ok(output) => !output.stdout.is_empty(),
            Err(_) => false,
        }
    }
}

/// Parse PHP version from "PHP X.Y.Z ..." output
fn parse_php_version(output: &str) -> Option<String> {
    output
        .lines()
        .next()
        .and_then(|line| line.find("PHP "))
        .and_then(|start| {
            let version_str = &output[start + 4..];
            version_str
                .find(' ')
                .map(|end| version_str[..end].to_string())
        })
}

/// Parse Apache version from "Server version: Apache/X.Y.Z" output
fn parse_apache_version(output: &str) -> Option<String> {
    output.lines().find_map(|line| {
        line.find("Apache/").map(|start| {
            let version_str = &line[start + 7..];
            version_str
                .find([' ', ')'])
                .map(|end| version_str[..end].to_string())
                .unwrap_or_else(|| version_str.to_string())
        })
    })
}

/// Parse MySQL version from "mysql Ver X.Y.Z ..." output
fn parse_mysql_version(output: &str) -> Option<String> {
    output.find(" Ver ").map(|pos| {
        let after_ver = &output[pos + 5..];
        after_ver
            .find([' ', '-'])
            .map(|end| after_ver[..end].to_string())
            .unwrap_or_else(|| after_ver.to_string())
    })
}

#[tauri::command]
pub async fn get_current_php_version() -> Result<String, String> {
    let php_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            "C:\\xampp\\php\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.3.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.2.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.1.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.0.0\\php.exe",
            "C:\\laragon\\bin\\php\\php-8.3.0-nts-Win32-vs16-x64\\php.exe",
            "C:\\laragon\\bin\\php\\php-8.2.0-nts-Win32-vs16-x64\\php.exe",
            "php.exe",
            "php",
        ]
    } else {
        vec![
            "/opt/homebrew/opt/php@8.4/bin/php",
            "/opt/homebrew/opt/php@8.3/bin/php",
            "/opt/homebrew/opt/php@8.2/bin/php",
            "/opt/homebrew/opt/php@8.1/bin/php",
            "/opt/homebrew/bin/php",
            "/usr/local/bin/php",
            "php",
        ]
    };

    find_and_execute(&php_paths, &["-v"])
        .and_then(|output| parse_php_version(&output))
        .ok_or_else(|| "PHP not found".to_string())
}

#[tauri::command]
pub async fn get_current_apache_version() -> Result<String, String> {
    let httpd_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            "C:\\xampp\\apache\\bin\\httpd.exe",
            "C:\\wamp64\\bin\\apache\\apache2.4.54\\bin\\httpd.exe",
            "C:\\wamp64\\bin\\apache\\apache2.4.51\\bin\\httpd.exe",
            "C:\\laragon\\bin\\apache\\httpd-2.4.54-win64-VS16\\bin\\httpd.exe",
            "httpd.exe",
            "httpd",
        ]
    } else {
        vec![
            "/opt/homebrew/opt/httpd/bin/httpd",
            "/opt/homebrew/bin/httpd",
            "/usr/local/bin/httpd",
            "/usr/sbin/httpd",
            "httpd",
        ]
    };

    find_and_execute(&httpd_paths, &["-v"])
        .and_then(|output| parse_apache_version(&output))
        .ok_or_else(|| "Apache not found".to_string())
}

#[tauri::command]
pub async fn get_current_mysql_version() -> Result<String, String> {
    let mysql_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            "C:\\xampp\\mysql\\bin\\mysql.exe",
            "C:\\wamp64\\bin\\mysql\\mysql8.0.31\\bin\\mysql.exe",
            "C:\\wamp64\\bin\\mysql\\mysql8.0.21\\bin\\mysql.exe",
            "C:\\laragon\\bin\\mysql\\mysql-8.0.30-winx64\\bin\\mysql.exe",
            "mysql.exe",
            "mysql",
        ]
    } else {
        vec![
            "/opt/homebrew/opt/mysql@8.4/bin/mysql",
            "/opt/homebrew/opt/mysql@8.0/bin/mysql",
            "/opt/homebrew/bin/mysql",
            "/usr/local/bin/mysql",
            "mysql",
        ]
    };

    find_and_execute(&mysql_paths, &["--version"])
        .and_then(|output| parse_mysql_version(&output))
        .ok_or_else(|| "MySQL not found".to_string())
}

#[tauri::command]
pub async fn save_virtual_hosts(hosts: HashMap<String, VirtualHost>) -> Result<(), String> {
    let hosts_file = get_hosts_file_path();

    // Ensure the directory exists
    if let Some(parent) = hosts_file.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create config directory: {}", e))?;
    }

    // Convert the hosts map to JSON with pretty formatting
    let json_content = serde_json::to_string_pretty(&hosts)
        .map_err(|e| format!("Failed to serialize hosts: {}", e))?;

    // Write to file
    fs::write(&hosts_file, json_content)
        .map_err(|e| format!("Failed to write hosts file: {}", e))?;

    Ok(())
}

#[tauri::command]
pub async fn generate_configs() -> Result<String, String> {
    let home = get_home_dir();

    if cfg!(target_os = "windows") {
        // Windows: Use PowerShell scripts
        let scripts_dir = format!("{}\\localhost-manager\\scripts\\windows", home);

        // Step 1: Generate configs
        let generate_script = format!("{}\\generate-all.ps1", scripts_dir);
        let mut cmd = Command::new("powershell");
        cmd.args(["-ExecutionPolicy", "Bypass", "-File", &generate_script]);
        #[cfg(target_os = "windows")]
        cmd.creation_flags(CREATE_NO_WINDOW);
        let output = cmd
            .output()
            .map_err(|e| format!("Failed to execute generate script: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Generate failed: {}", stderr));
        }

        // Step 2: Apply configs (install.ps1) - requires admin
        let install_script = format!("{}\\install.ps1", scripts_dir);
        let mut install_cmd = Command::new("powershell");
        install_cmd.args(["-ExecutionPolicy", "Bypass", "-File", &install_script]);
        #[cfg(target_os = "windows")]
        install_cmd.creation_flags(CREATE_NO_WINDOW);
        let install_output = install_cmd
            .output()
            .map_err(|e| format!("Failed to execute install script: {}", e))?;

        if install_output.status.success() {
            let stdout = String::from_utf8_lossy(&install_output.stdout);
            Ok(format!(
                "Configuration generated and applied successfully.\n{}",
                stdout
            ))
        } else {
            let stderr = String::from_utf8_lossy(&install_output.stderr);
            Err(format!("Install failed: {}", stderr))
        }
    } else {
        // macOS/Linux: Use bash scripts
        let home = get_home_dir();
        let scripts_dir = format!("{}/localhost-manager/scripts", home);

        // Step 1: Generate configs
        let generate_script = format!("{}/generate-all.sh", scripts_dir);
        let output = Command::new("bash")
            .arg(&generate_script)
            .output()
            .map_err(|e| format!("Failed to execute generate script: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Generate failed: {}", stderr));
        }

        // Step 2: Apply configs (install.sh)
        let install_script = format!("{}/install.sh", scripts_dir);
        let install_output = Command::new("bash")
            .arg(&install_script)
            .output()
            .map_err(|e| format!("Failed to execute install script: {}", e))?;

        if install_output.status.success() {
            let stdout = String::from_utf8_lossy(&install_output.stdout);
            Ok(format!(
                "Configuration generated and applied successfully.\n{}",
                stdout
            ))
        } else {
            let stderr = String::from_utf8_lossy(&install_output.stderr);
            Err(format!("Install failed: {}", stderr))
        }
    }
}

#[tauri::command]
pub async fn apply_configs() -> Result<String, String> {
    let home = get_home_dir();

    if cfg!(target_os = "windows") {
        let script_path = format!("{}\\localhost-manager\\scripts\\windows\\install.ps1", home);

        let mut cmd = Command::new("powershell");
        cmd.args(["-ExecutionPolicy", "Bypass", "-File", &script_path]);
        #[cfg(target_os = "windows")]
        cmd.creation_flags(CREATE_NO_WINDOW);
        let output = cmd
            .output()
            .map_err(|e| format!("Failed to execute install script: {}", e))?;

        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            Ok(stdout.to_string())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!("Install failed: {}", stderr))
        }
    } else {
        let script_path = format!("{}/localhost-manager/scripts/install.sh", home);

        let output = Command::new("bash")
            .arg(&script_path)
            .output()
            .map_err(|e| format!("Failed to execute install script: {}", e))?;

        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            Ok(stdout.to_string())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!("Install failed: {}", stderr))
        }
    }
}

#[tauri::command]
pub async fn control_service(action: String, service: String) -> Result<String, String> {
    if cfg!(target_os = "windows") {
        // Windows service control
        // Map service names to Windows service names (varies by stack)
        let windows_services: Vec<&str> = match service.as_str() {
            "apache" => vec!["Apache2.4", "wampapache64", "Apache"],
            "mysql" => vec!["MySQL", "wampmysqld64", "MySQL80"],
            "php" => vec![], // PHP-FPM is not a Windows service typically
            _ => return Err(format!("Unknown service: {}", service)),
        };

        if windows_services.is_empty() {
            return Ok(format!(
                "Service {} does not run as a Windows service",
                service
            ));
        }

        // Try each possible service name
        for win_service in &windows_services {
            let sc_action = match action.as_str() {
                "start" => "start",
                "stop" => "stop",
                "restart" => "stop", // Will start after
                _ => return Err(format!("Unknown action: {}", action)),
            };

            let output = run_windows_command("sc", &[sc_action, win_service]);

            if let Ok(out) = output {
                if out.status.success() {
                    // If restart, also start
                    if action == "restart" {
                        std::thread::sleep(std::time::Duration::from_secs(1));
                        let _ = run_windows_command("sc", &["start", win_service]);
                    }
                    return Ok(format!("Service {} {}ed successfully", service, action));
                }
            }
        }

        // Try net command as fallback
        for win_service in &windows_services {
            let net_action = match action.as_str() {
                "start" => "start",
                "stop" => "stop",
                "restart" => "stop",
                _ => return Err(format!("Unknown action: {}", action)),
            };

            let output = run_windows_command("net", &[net_action, win_service]);

            if let Ok(out) = output {
                if out.status.success() {
                    if action == "restart" {
                        std::thread::sleep(std::time::Duration::from_secs(1));
                        let _ = run_windows_command("net", &["start", win_service]);
                    }
                    return Ok(format!("Service {} {}ed successfully", service, action));
                }
            }
        }

        Err(format!(
            "Could not {} {} - service may not be installed or requires admin rights",
            action, service
        ))
    } else {
        // macOS - use brew services
        let brew_service = match service.as_str() {
            "apache" => "httpd",
            "mysql" => "mysql@8.4",
            "php" => "php@8.3",
            _ => return Err(format!("Unknown service: {}", service)),
        };

        let output = Command::new("brew")
            .args(["services", &action, brew_service])
            .output()
            .map_err(|e| format!("Failed to {} {}: {}", action, service, e))?;

        if output.status.success() {
            Ok(format!("Service {} {}ed successfully", service, action))
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!("Failed to {} {}: {}", action, service, stderr))
        }
    }
}

#[tauri::command]
pub async fn delete_host(domain: String) -> Result<(), String> {
    let hosts_file = get_hosts_file_path();

    if !hosts_file.exists() {
        return Err("Hosts file not found".to_string());
    }

    let content =
        fs::read_to_string(&hosts_file).map_err(|e| format!("Failed to read hosts file: {}", e))?;

    let mut hosts: HashMap<String, serde_json::Value> =
        serde_json::from_str(&content).map_err(|e| format!("Failed to parse hosts file: {}", e))?;

    if hosts.remove(&domain).is_none() {
        return Err(format!("Host '{}' not found", domain));
    }

    let json_content = serde_json::to_string_pretty(&hosts)
        .map_err(|e| format!("Failed to serialize hosts: {}", e))?;

    fs::write(&hosts_file, json_content)
        .map_err(|e| format!("Failed to write hosts file: {}", e))?;

    Ok(())
}

#[tauri::command]
pub async fn get_home_directory() -> Result<String, String> {
    Ok(get_home_dir())
}

#[tauri::command]
pub async fn get_scripts_path() -> Result<String, String> {
    let home = get_home_dir();
    if cfg!(target_os = "windows") {
        Ok(format!("{}\\localhost-manager\\scripts\\windows", home))
    } else {
        Ok(format!("{}/localhost-manager/scripts", home))
    }
}

// Setup Wizard Commands

#[derive(serde::Serialize)]
pub struct DetectedStack {
    name: String,
    value: String,
    detected: bool,
}

#[tauri::command]
pub async fn detect_installed_stacks() -> Result<Vec<DetectedStack>, String> {
    let mut stacks = Vec::new();

    if cfg!(target_os = "windows") {
        // Windows: Check for XAMPP, WAMP, Laragon
        stacks.push(DetectedStack {
            name: "XAMPP".to_string(),
            value: "xampp".to_string(),
            detected: std::path::Path::new("C:\\xampp").exists(),
        });

        stacks.push(DetectedStack {
            name: "WAMP".to_string(),
            value: "wamp".to_string(),
            detected: std::path::Path::new("C:\\wamp64").exists()
                || std::path::Path::new("C:\\wamp").exists(),
        });

        stacks.push(DetectedStack {
            name: "Laragon".to_string(),
            value: "laragon".to_string(),
            detected: std::path::Path::new("C:\\laragon").exists(),
        });

        stacks.push(DetectedStack {
            name: "MAMP".to_string(),
            value: "mamp".to_string(),
            detected: std::path::Path::new("C:\\MAMP").exists(),
        });
    } else if cfg!(target_os = "macos") {
        // macOS: Check for Homebrew, MAMP, XAMPP
        stacks.push(DetectedStack {
            name: "Homebrew".to_string(),
            value: "native".to_string(),
            detected: std::path::Path::new("/opt/homebrew/bin/brew").exists()
                || std::path::Path::new("/usr/local/bin/brew").exists(),
        });

        stacks.push(DetectedStack {
            name: "MAMP".to_string(),
            value: "mamp".to_string(),
            detected: std::path::Path::new("/Applications/MAMP").exists(),
        });

        stacks.push(DetectedStack {
            name: "XAMPP".to_string(),
            value: "xampp".to_string(),
            detected: std::path::Path::new("/Applications/XAMPP").exists(),
        });
    } else {
        // Linux: Check for native installation, XAMPP
        stacks.push(DetectedStack {
            name: "Native (apt/dnf)".to_string(),
            value: "native".to_string(),
            detected: std::path::Path::new("/usr/sbin/apache2").exists()
                || std::path::Path::new("/usr/sbin/httpd").exists(),
        });

        stacks.push(DetectedStack {
            name: "XAMPP".to_string(),
            value: "xampp".to_string(),
            detected: std::path::Path::new("/opt/lampp").exists(),
        });
    }

    Ok(stacks)
}

#[tauri::command]
pub async fn setup_directories(
    config_path: String,
    ssl_path: String,
    projects_path: String,
) -> Result<(), String> {
    // Create config directory
    fs::create_dir_all(&config_path)
        .map_err(|e| format!("Failed to create config directory: {}", e))?;

    // Create subdirectories
    let conf_dir = std::path::Path::new(&config_path).join("conf");
    fs::create_dir_all(&conf_dir).map_err(|e| format!("Failed to create conf directory: {}", e))?;

    let scripts_dir = std::path::Path::new(&config_path).join("scripts");
    fs::create_dir_all(&scripts_dir)
        .map_err(|e| format!("Failed to create scripts directory: {}", e))?;

    // Create SSL directory
    fs::create_dir_all(&ssl_path).map_err(|e| format!("Failed to create SSL directory: {}", e))?;

    // Create projects directory if it doesn't exist
    fs::create_dir_all(&projects_path)
        .map_err(|e| format!("Failed to create projects directory: {}", e))?;

    Ok(())
}

#[derive(serde::Deserialize)]
pub struct SetupConfig {
    stack: String,
    #[serde(rename = "projectsPath")]
    projects_path: String,
    #[serde(rename = "configPath")]
    config_path: String,
    #[serde(rename = "sslPath")]
    ssl_path: String,
}

#[tauri::command]
pub async fn create_initial_config(config: SetupConfig) -> Result<(), String> {
    // Create initial hosts.json
    let hosts_file = std::path::Path::new(&config.config_path)
        .join("conf")
        .join("hosts.json");

    let initial_hosts = serde_json::json!({});

    let json_content = serde_json::to_string_pretty(&initial_hosts)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;

    fs::write(&hosts_file, json_content)
        .map_err(|e| format!("Failed to write hosts file: {}", e))?;

    // Create settings.json
    let settings_file = std::path::Path::new(&config.config_path)
        .join("conf")
        .join("settings.json");

    let settings = serde_json::json!({
        "stack": config.stack,
        "projectsPath": config.projects_path,
        "configPath": config.config_path,
        "sslPath": config.ssl_path,
        "setupCompleted": true,
        "setupDate": chrono::Utc::now().to_rfc3339()
    });

    let settings_content = serde_json::to_string_pretty(&settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    fs::write(&settings_file, settings_content)
        .map_err(|e| format!("Failed to write settings file: {}", e))?;

    Ok(())
}

// File operations for import/export
#[tauri::command]
pub async fn read_file(path: String) -> Result<String, String> {
    fs::read_to_string(&path).map_err(|e| format!("Failed to read file: {}", e))
}

#[tauri::command]
pub async fn write_file(path: String, content: String) -> Result<(), String> {
    // Ensure parent directory exists
    if let Some(parent) = std::path::Path::new(&path).parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
    }

    fs::write(&path, content).map_err(|e| format!("Failed to write file: {}", e))
}

// ============================================
// Stack Installer Commands
// ============================================

#[derive(serde::Serialize)]
pub struct PlatformInfo {
    os: String,
    package_manager: String,
    available: bool,
}

#[tauri::command]
pub async fn detect_platform() -> Result<PlatformInfo, String> {
    let os = if cfg!(target_os = "macos") {
        "macOS"
    } else if cfg!(target_os = "windows") {
        "Windows"
    } else {
        "Linux"
    };

    let (package_manager, available) = if cfg!(target_os = "macos") {
        // Check for Homebrew
        let output = Command::new("which").arg("brew").output();
        let available = output.map(|o| o.status.success()).unwrap_or(false);
        ("Homebrew", available)
    } else if cfg!(target_os = "windows") {
        // Check for Chocolatey
        let output = Command::new("where").arg("choco").output();
        let available = output.map(|o| o.status.success()).unwrap_or(false);
        ("Chocolatey", available)
    } else {
        // Check for apt
        let output = Command::new("which").arg("apt").output();
        let available = output.map(|o| o.status.success()).unwrap_or(false);
        ("apt", available)
    };

    Ok(PlatformInfo {
        os: os.to_string(),
        package_manager: package_manager.to_string(),
        available,
    })
}

/// Check if package is installed based on platform
fn is_package_installed(brew_name: &str, win_cmd: &str, dpkg_name: &str) -> bool {
    if cfg!(target_os = "macos") {
        run_command("brew", &["list", brew_name]).is_some()
    } else if cfg!(target_os = "windows") {
        command_exists(win_cmd)
    } else {
        run_command("dpkg", &["-l", dpkg_name]).is_some()
    }
}

#[tauri::command]
pub async fn check_package_installed(package: String) -> Result<bool, String> {
    let installed = match package.as_str() {
        "apache" => is_package_installed("httpd", "httpd", "apache2"),
        "mysql" => is_package_installed("mysql", "mysql", "mysql-server"),
        "php" => is_package_installed("php", "php", "php"),
        _ => false,
    };

    Ok(installed)
}

#[tauri::command]
pub async fn install_package(package: String, version: String) -> Result<String, String> {
    let output = if cfg!(target_os = "macos") {
        match package.as_str() {
            "apache" => Command::new("brew")
                .args(["install", "httpd"])
                .output()
                .map_err(|e| e.to_string())?,
            "mysql" => Command::new("brew")
                .args(["install", "mysql"])
                .output()
                .map_err(|e| e.to_string())?,
            "php" => {
                let php_package = if version.is_empty() || version == "8.3" {
                    "php"
                } else {
                    &format!("php@{}", version)
                };
                Command::new("brew")
                    .args(["install", php_package])
                    .output()
                    .map_err(|e| e.to_string())?
            }
            _ => return Err("Unknown package".to_string()),
        }
    } else if cfg!(target_os = "windows") {
        match package.as_str() {
            "apache" => run_windows_command("choco", &["install", "apache-httpd", "-y"])
                .map_err(|e| e.to_string())?,
            "mysql" => run_windows_command("choco", &["install", "mysql", "-y"])
                .map_err(|e| e.to_string())?,
            "php" => {
                let php_version = if version.is_empty() {
                    "8.3".to_string()
                } else {
                    version.clone()
                };
                run_windows_command(
                    "choco",
                    &[
                        "install",
                        "php",
                        &format!("--version={}", php_version),
                        "-y",
                    ],
                )
                .map_err(|e| e.to_string())?
            }
            _ => return Err("Unknown package".to_string()),
        }
    } else {
        match package.as_str() {
            "apache" => Command::new("sudo")
                .args(["apt", "install", "-y", "apache2"])
                .output()
                .map_err(|e| e.to_string())?,
            "mysql" => Command::new("sudo")
                .args(["apt", "install", "-y", "mysql-server"])
                .output()
                .map_err(|e| e.to_string())?,
            "php" => {
                let php_version = if version.is_empty() { "8.3" } else { &version };
                Command::new("sudo")
                    .args([
                        "apt",
                        "install",
                        "-y",
                        &format!("php{}", php_version),
                        &format!("php{}-fpm", php_version),
                        &format!("php{}-mysql", php_version),
                        &format!("php{}-curl", php_version),
                        &format!("php{}-gd", php_version),
                        &format!("php{}-mbstring", php_version),
                    ])
                    .output()
                    .map_err(|e| e.to_string())?
            }
            _ => return Err("Unknown package".to_string()),
        }
    };

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// ============================================
// PHP Extensions Commands
// ============================================

#[tauri::command]
pub async fn get_installed_php_versions_list() -> Result<Vec<String>, String> {
    let mut versions = Vec::new();

    if cfg!(target_os = "macos") {
        // Get PHP versions from Homebrew
        let output = Command::new("brew")
            .args(["list", "--versions"])
            .output()
            .map_err(|e| e.to_string())?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if line.starts_with("php@") || line.starts_with("php ") {
                if let Some(version) = line.split_whitespace().nth(1) {
                    let major_minor: String =
                        version.split('.').take(2).collect::<Vec<_>>().join(".");
                    if !versions.contains(&major_minor) {
                        versions.push(major_minor);
                    }
                }
            }
        }
    } else if cfg!(target_os = "windows") {
        // Check common PHP locations on Windows
        let output = run_windows_command("php", &["-v"]);
        if let Ok(o) = output {
            if o.status.success() {
                let stdout = String::from_utf8_lossy(&o.stdout);
                if let Some(line) = stdout.lines().next() {
                    if let Some(version) = line.split_whitespace().nth(1) {
                        let major_minor: String =
                            version.split('.').take(2).collect::<Vec<_>>().join(".");
                        versions.push(major_minor);
                    }
                }
            }
        }
    } else {
        // Linux: check installed PHP versions
        for v in ["7.4", "8.0", "8.1", "8.2", "8.3"] {
            let path = format!("/usr/bin/php{}", v);
            if std::path::Path::new(&path).exists() {
                versions.push(v.to_string());
            }
        }
    }

    if versions.is_empty() {
        // Fallback: try to get current PHP version
        let output = run_windows_command("php", &["-v"]);
        if let Ok(o) = output {
            if o.status.success() {
                let stdout = String::from_utf8_lossy(&o.stdout);
                if let Some(line) = stdout.lines().next() {
                    if let Some(version) = line.split_whitespace().nth(1) {
                        let major_minor: String =
                            version.split('.').take(2).collect::<Vec<_>>().join(".");
                        versions.push(major_minor);
                    }
                }
            }
        }
    }

    Ok(versions)
}

#[derive(serde::Serialize)]
pub struct ExtensionInfo {
    name: String,
    enabled: bool,
    installed: bool,
}

#[tauri::command]
pub async fn get_php_extensions(version: String) -> Result<Vec<ExtensionInfo>, String> {
    let mut extensions = Vec::new();

    // Common PHP extensions
    let common_extensions = vec![
        "bcmath",
        "bz2",
        "calendar",
        "ctype",
        "curl",
        "dom",
        "exif",
        "fileinfo",
        "filter",
        "ftp",
        "gd",
        "gettext",
        "gmp",
        "iconv",
        "imagick",
        "imap",
        "intl",
        "json",
        "ldap",
        "mbstring",
        "memcached",
        "mongodb",
        "mysqli",
        "mysqlnd",
        "opcache",
        "openssl",
        "pcntl",
        "pdo",
        "pdo_mysql",
        "pdo_pgsql",
        "pdo_sqlite",
        "pgsql",
        "phar",
        "posix",
        "readline",
        "redis",
        "session",
        "shmop",
        "simplexml",
        "soap",
        "sockets",
        "sodium",
        "sqlite3",
        "ssh2",
        "sysvmsg",
        "sysvsem",
        "sysvshm",
        "tidy",
        "tokenizer",
        "xdebug",
        "xml",
        "xmlreader",
        "xmlrpc",
        "xmlwriter",
        "xsl",
        "zip",
        "zlib",
    ];

    // Get loaded extensions
    let output = if cfg!(target_os = "macos") {
        let php_cmd = if version == "8.3" || version.is_empty() {
            "php".to_string()
        } else {
            format!("/opt/homebrew/opt/php@{}/bin/php", version)
        };
        Command::new(&php_cmd)
            .args(["-m"])
            .output()
            .map_err(|e| e.to_string())?
    } else {
        run_windows_command("php", &["-m"]).map_err(|e| e.to_string())?
    };

    let loaded: Vec<String> = String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|s| s.to_lowercase())
        .collect();

    for ext in common_extensions {
        let enabled = loaded.contains(&ext.to_lowercase());
        extensions.push(ExtensionInfo {
            name: ext.to_string(),
            enabled,
            installed: true, // Simplified: assume all are available
        });
    }

    Ok(extensions)
}

#[tauri::command]
pub async fn toggle_php_extension(
    version: String,
    extension: String,
    enable: bool,
) -> Result<(), String> {
    // Find php.ini path
    let ini_path = if cfg!(target_os = "macos") {
        if version == "8.3" || version.is_empty() {
            "/opt/homebrew/etc/php/8.3/php.ini".to_string()
        } else {
            format!("/opt/homebrew/etc/php/{}/php.ini", version)
        }
    } else if cfg!(target_os = "windows") {
        // Common Windows PHP locations
        let possible_paths = vec![
            format!("C:\\php\\php.ini"),
            format!("C:\\xampp\\php\\php.ini"),
            format!("C:\\wamp64\\bin\\php\\php{}\\php.ini", version),
        ];
        possible_paths
            .into_iter()
            .find(|p| std::path::Path::new(p).exists())
            .unwrap_or_else(|| "C:\\php\\php.ini".to_string())
    } else {
        format!("/etc/php/{}/fpm/php.ini", version)
    };

    if !std::path::Path::new(&ini_path).exists() {
        return Err(format!("php.ini not found at {}", ini_path));
    }

    let content = fs::read_to_string(&ini_path).map_err(|e| e.to_string())?;

    let ext_line = format!("extension={}", extension);
    let ext_line_commented = format!(";extension={}", extension);

    let new_content = if enable {
        // Enable: uncomment or add
        if content.contains(&ext_line_commented) {
            content.replace(&ext_line_commented, &ext_line)
        } else if !content.contains(&ext_line) {
            format!("{}\n{}", content, ext_line)
        } else {
            content
        }
    } else {
        // Disable: comment out
        if content.contains(&ext_line) && !content.contains(&ext_line_commented) {
            content.replace(&ext_line, &ext_line_commented)
        } else {
            content
        }
    };

    fs::write(&ini_path, new_content).map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub async fn restart_php_fpm() -> Result<(), String> {
    let output = if cfg!(target_os = "macos") {
        Command::new("brew")
            .args(["services", "restart", "php"])
            .output()
            .map_err(|e| e.to_string())?
    } else if cfg!(target_os = "windows") {
        // Windows doesn't typically use php-fpm
        return Ok(());
    } else {
        Command::new("sudo")
            .args(["systemctl", "restart", "php-fpm"])
            .output()
            .map_err(|e| e.to_string())?
    };

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// ============================================
// MySQL Configuration Commands
// ============================================

/// Run mysql command with proper window handling
fn run_mysql_command<I, S>(args: I) -> std::io::Result<std::process::Output>
where
    I: IntoIterator<Item = S>,
    S: AsRef<std::ffi::OsStr>,
{
    let mut cmd = Command::new("mysql");
    cmd.args(args);
    #[cfg(target_os = "windows")]
    cmd.creation_flags(CREATE_NO_WINDOW);
    cmd.output()
}

#[tauri::command]
pub async fn check_mysql_connection() -> Result<bool, String> {
    let output = run_mysql_command(["--version"]).map_err(|e| e.to_string())?;

    Ok(output.status.success())
}

#[derive(serde::Serialize)]
pub struct MysqlUser {
    user: String,
    host: String,
}

#[tauri::command]
pub async fn get_mysql_users(root_password: String) -> Result<Vec<MysqlUser>, String> {
    let mut args = vec!["-u", "root", "-e", "SELECT user, host FROM mysql.user;"];
    let password_arg;

    if !root_password.is_empty() {
        password_arg = format!("-p{}", root_password);
        args.insert(2, &password_arg);
    }

    let output = run_mysql_command(args).map_err(|e| e.to_string())?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut users = Vec::new();

    for line in stdout.lines().skip(1) {
        // Skip header
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
            users.push(MysqlUser {
                user: parts[0].to_string(),
                host: parts[1].to_string(),
            });
        }
    }

    Ok(users)
}

#[tauri::command]
pub async fn change_mysql_root_password(
    current_password: String,
    new_password: String,
) -> Result<(), String> {
    let query = format!(
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '{}';",
        new_password
    );

    let mut args = vec!["-u", "root", "-e", &query];
    let password_arg;

    if !current_password.is_empty() {
        password_arg = format!("-p{}", current_password);
        args.insert(2, &password_arg);
    }

    let output = run_mysql_command(args).map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[tauri::command]
pub async fn create_mysql_user(
    root_password: String,
    username: String,
    password: String,
    host: String,
    grant_all: bool,
) -> Result<(), String> {
    let create_query = format!(
        "CREATE USER '{}'@'{}' IDENTIFIED BY '{}';",
        username, host, password
    );

    let grant_query = if grant_all {
        format!(
            "GRANT ALL PRIVILEGES ON *.* TO '{}'@'{}' WITH GRANT OPTION;",
            username, host
        )
    } else {
        format!("GRANT SELECT ON *.* TO '{}'@'{}';", username, host)
    };

    let full_query = format!("{} {} FLUSH PRIVILEGES;", create_query, grant_query);

    let mut args = vec!["-u", "root", "-e", &full_query];
    let password_arg;

    if !root_password.is_empty() {
        password_arg = format!("-p{}", root_password);
        args.insert(2, &password_arg);
    }

    let output = run_mysql_command(args).map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[tauri::command]
pub async fn delete_mysql_user(
    root_password: String,
    username: String,
    host: String,
) -> Result<(), String> {
    let query = format!("DROP USER '{}'@'{}';", username, host);

    let mut args = vec!["-u", "root", "-e", &query];
    let password_arg;

    if !root_password.is_empty() {
        password_arg = format!("-p{}", root_password);
        args.insert(2, &password_arg);
    }

    let output = run_mysql_command(args).map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}
