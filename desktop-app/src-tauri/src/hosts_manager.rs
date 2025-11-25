use crate::types::{VirtualHost, VirtualHostAlias, ServicesStatus};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use anyhow::Result;

fn get_hosts_file_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/Users/mario"));
    PathBuf::from(format!("{}/localhost-manager/conf/hosts.json", home))
}

#[tauri::command]
pub async fn get_virtual_hosts() -> Result<HashMap<String, VirtualHost>, String> {
    let hosts_file = get_hosts_file_path();

    if !hosts_file.exists() {
        return Ok(HashMap::new());
    }

    let content = fs::read_to_string(&hosts_file)
        .map_err(|e| format!("Failed to read hosts file: {}", e))?;

    let hosts_raw: HashMap<String, serde_json::Value> = serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse hosts file: {}", e))?;

    let mut hosts = HashMap::new();

    for (domain, host_data) in hosts_raw {
        if let Ok(host_obj) = serde_json::from_value::<serde_json::Map<String, serde_json::Value>>(host_data.clone()) {
            let docroot = host_obj.get("docroot")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();

            let group = host_obj.get("group")
                .and_then(|v| v.as_str())
                .unwrap_or("Uncategorized")
                .to_string();

            let active = host_obj.get("active")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);

            let ssl = host_obj.get("ssl")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);

            let host_type = host_obj.get("type")
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
                                id: alias_obj.get("id")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .to_string(),
                                value: alias_obj.get("value")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("")
                                    .to_string(),
                                active: alias_obj.get("active")
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
        Command::new("pgrep")
            .args(&["-f", name])
            .output()
    } else {
        Command::new("pgrep")
            .arg(name)
            .output()
    };

    match output {
        Ok(output) => !output.stdout.is_empty(),
        Err(_) => false,
    }
}

#[tauri::command]
pub async fn get_current_php_version() -> Result<String, String> {
    let output = Command::new("php")
        .arg("-v")
        .output()
        .map_err(|e| format!("Failed to execute php: {}", e))?;

    if !output.status.success() {
        return Err("PHP not found or not executable".to_string());
    }

    let version_output = String::from_utf8_lossy(&output.stdout);
    // Parse "PHP 8.4.15 (cli) ..." to extract "8.4.15"
    if let Some(line) = version_output.lines().next() {
        if let Some(start) = line.find("PHP ") {
            let version_str = &line[start + 4..];
            if let Some(end) = version_str.find(' ') {
                return Ok(version_str[..end].to_string());
            }
        }
    }

    Err("Could not parse PHP version".to_string())
}

#[tauri::command]
pub async fn get_current_apache_version() -> Result<String, String> {
    let output = Command::new("httpd")
        .arg("-v")
        .output()
        .map_err(|e| format!("Failed to execute httpd: {}", e))?;

    if !output.status.success() {
        return Err("Apache not found or not executable".to_string());
    }

    let version_output = String::from_utf8_lossy(&output.stdout);
    // Parse "Server version: Apache/2.4.62 (Unix)" to extract "2.4.62"
    for line in version_output.lines() {
        if line.contains("Server version:") {
            if let Some(start) = line.find("Apache/") {
                let version_str = &line[start + 7..];
                if let Some(end) = version_str.find(' ') {
                    return Ok(version_str[..end].to_string());
                }
            }
        }
    }

    Err("Could not parse Apache version".to_string())
}

#[tauri::command]
pub async fn get_current_mysql_version() -> Result<String, String> {
    let output = Command::new("mysql")
        .arg("--version")
        .output()
        .map_err(|e| format!("Failed to execute mysql: {}", e))?;

    if !output.status.success() {
        return Err("MySQL not found or not executable".to_string());
    }

    let version_output = String::from_utf8_lossy(&output.stdout);
    // Parse "mysql  Ver 8.4.7 for ..." to extract "8.4.7"
    if let Some(ver_pos) = version_output.find(" Ver ") {
        let after_ver = &version_output[ver_pos + 5..];
        if let Some(end) = after_ver.find(' ') {
            return Ok(after_ver[..end].to_string());
        }
    }

    Err("Could not parse MySQL version".to_string())
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
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/Users/mario"));
    let script_path = format!("{}/localhost-manager/scripts/generate-all.sh", home);

    // Run script directly - it handles sudo internally with keychain
    let output = Command::new("bash")
        .arg(&script_path)
        .output()
        .map_err(|e| format!("Failed to execute generate script: {}", e))?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(stdout.to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("Generate failed: {}", stderr))
    }
}

#[tauri::command]
pub async fn apply_configs() -> Result<String, String> {
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/Users/mario"));
    let script_path = format!("{}/localhost-manager/scripts/install.sh", home);

    // Run script directly - it handles sudo internally with keychain
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

#[tauri::command]
pub async fn control_service(action: String, service: String) -> Result<String, String> {
    // Map service names to brew service names
    let brew_service = match service.as_str() {
        "apache" => "httpd",
        "mysql" => "mysql@8.4",
        "php" => "php@8.4",
        _ => return Err(format!("Unknown service: {}", service))
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

#[tauri::command]
pub async fn delete_host(domain: String) -> Result<(), String> {
    let hosts_file = get_hosts_file_path();

    if !hosts_file.exists() {
        return Err("Hosts file not found".to_string());
    }

    let content = fs::read_to_string(&hosts_file)
        .map_err(|e| format!("Failed to read hosts file: {}", e))?;

    let mut hosts: HashMap<String, serde_json::Value> = serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse hosts file: {}", e))?;

    if hosts.remove(&domain).is_none() {
        return Err(format!("Host '{}' not found", domain));
    }

    let json_content = serde_json::to_string_pretty(&hosts)
        .map_err(|e| format!("Failed to serialize hosts: {}", e))?;

    fs::write(&hosts_file, json_content)
        .map_err(|e| format!("Failed to write hosts file: {}", e))?;

    Ok(())
}
