use crate::types::{ServicesStatus, VirtualHost, VirtualHostAlias};
use anyhow::Result;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

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
    let output = if name == "php-fpm" {
        Command::new("pgrep").args(&["-f", name]).output()
    } else {
        Command::new("pgrep").arg(name).output()
    };

    match output {
        Ok(output) => !output.stdout.is_empty(),
        Err(_) => false,
    }
}

#[tauri::command]
pub async fn get_current_php_version() -> Result<String, String> {
    let php_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            // XAMPP
            "C:\\xampp\\php\\php.exe",
            // WAMP (common versions)
            "C:\\wamp64\\bin\\php\\php8.3.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.2.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.1.0\\php.exe",
            "C:\\wamp64\\bin\\php\\php8.0.0\\php.exe",
            // Laragon
            "C:\\laragon\\bin\\php\\php-8.3.0-nts-Win32-vs16-x64\\php.exe",
            "C:\\laragon\\bin\\php\\php-8.2.0-nts-Win32-vs16-x64\\php.exe",
            // System PATH
            "php.exe",
            "php",
        ]
    } else {
        vec![
            // macOS Homebrew
            "/opt/homebrew/opt/php@8.3/bin/php",
            "/opt/homebrew/opt/php@8.4/bin/php",
            "/opt/homebrew/opt/php@8.2/bin/php",
            "/opt/homebrew/opt/php@8.1/bin/php",
            "/opt/homebrew/bin/php",
            "/usr/local/bin/php",
            "php",
        ]
    };

    for php_path in &php_paths {
        if let Ok(output) = Command::new(php_path).arg("-v").output() {
            if output.status.success() {
                let version_output = String::from_utf8_lossy(&output.stdout);
                if let Some(line) = version_output.lines().next() {
                    if let Some(start) = line.find("PHP ") {
                        let version_str = &line[start + 4..];
                        if let Some(end) = version_str.find(' ') {
                            return Ok(version_str[..end].to_string());
                        }
                    }
                }
            }
        }
    }

    Err("PHP not found".to_string())
}

#[tauri::command]
pub async fn get_current_apache_version() -> Result<String, String> {
    let httpd_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            // XAMPP
            "C:\\xampp\\apache\\bin\\httpd.exe",
            // WAMP
            "C:\\wamp64\\bin\\apache\\apache2.4.54\\bin\\httpd.exe",
            "C:\\wamp64\\bin\\apache\\apache2.4.51\\bin\\httpd.exe",
            // Laragon
            "C:\\laragon\\bin\\apache\\httpd-2.4.54-win64-VS16\\bin\\httpd.exe",
            // System PATH
            "httpd.exe",
            "httpd",
        ]
    } else {
        vec![
            // macOS Homebrew
            "/opt/homebrew/opt/httpd/bin/httpd",
            "/opt/homebrew/bin/httpd",
            "/usr/local/bin/httpd",
            "/usr/sbin/httpd",
            "httpd",
        ]
    };

    for httpd_path in &httpd_paths {
        if let Ok(output) = Command::new(httpd_path).arg("-v").output() {
            if output.status.success() {
                let version_output = String::from_utf8_lossy(&output.stdout);
                for line in version_output.lines() {
                    if line.contains("Server version:") || line.contains("Apache/") {
                        if let Some(start) = line.find("Apache/") {
                            let version_str = &line[start + 7..];
                            if let Some(end) = version_str.find(|c: char| c == ' ' || c == ')') {
                                return Ok(version_str[..end].to_string());
                            }
                        }
                    }
                }
            }
        }
    }

    Err("Apache not found".to_string())
}

#[tauri::command]
pub async fn get_current_mysql_version() -> Result<String, String> {
    let mysql_paths: Vec<&str> = if cfg!(target_os = "windows") {
        vec![
            // XAMPP
            "C:\\xampp\\mysql\\bin\\mysql.exe",
            // WAMP
            "C:\\wamp64\\bin\\mysql\\mysql8.0.31\\bin\\mysql.exe",
            "C:\\wamp64\\bin\\mysql\\mysql8.0.21\\bin\\mysql.exe",
            // Laragon
            "C:\\laragon\\bin\\mysql\\mysql-8.0.30-winx64\\bin\\mysql.exe",
            // System PATH
            "mysql.exe",
            "mysql",
        ]
    } else {
        vec![
            // macOS Homebrew
            "/opt/homebrew/opt/mysql@8.4/bin/mysql",
            "/opt/homebrew/opt/mysql@8.0/bin/mysql",
            "/opt/homebrew/bin/mysql",
            "/usr/local/bin/mysql",
            "mysql",
        ]
    };

    for mysql_path in &mysql_paths {
        if let Ok(output) = Command::new(mysql_path).arg("--version").output() {
            if output.status.success() {
                let version_output = String::from_utf8_lossy(&output.stdout);
                // Parse "mysql  Ver 8.4.7 for ..." or "mysql.exe  Ver 8.0.31..."
                if let Some(ver_pos) = version_output.find(" Ver ") {
                    let after_ver = &version_output[ver_pos + 5..];
                    if let Some(end) = after_ver.find(|c: char| c == ' ' || c == '-') {
                        return Ok(after_ver[..end].to_string());
                    }
                }
            }
        }
    }

    Err("MySQL not found".to_string())
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
        let output = Command::new("powershell")
            .args(&["-ExecutionPolicy", "Bypass", "-File", &generate_script])
            .output()
            .map_err(|e| format!("Failed to execute generate script: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Generate failed: {}", stderr));
        }

        // Step 2: Apply configs (install.ps1) - requires admin
        let install_script = format!("{}\\install.ps1", scripts_dir);
        let install_output = Command::new("powershell")
            .args(&["-ExecutionPolicy", "Bypass", "-File", &install_script])
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

        let output = Command::new("powershell")
            .args(&["-ExecutionPolicy", "Bypass", "-File", &script_path])
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

            let output = Command::new("sc").args(&[sc_action, win_service]).output();

            if let Ok(out) = output {
                if out.status.success() {
                    // If restart, also start
                    if action == "restart" {
                        std::thread::sleep(std::time::Duration::from_secs(1));
                        let _ = Command::new("sc").args(&["start", win_service]).output();
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

            let output = Command::new("net")
                .args(&[net_action, win_service])
                .output();

            if let Ok(out) = output {
                if out.status.success() {
                    if action == "restart" {
                        std::thread::sleep(std::time::Duration::from_secs(1));
                        let _ = Command::new("net").args(&["start", win_service]).output();
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
            .args(&["services", &action, brew_service])
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
