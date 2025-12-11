mod config;
mod hosts_manager;
mod php_manager;
mod system;
mod types;

use hosts_manager::*;
use php_manager::*;
use system::*;
use tauri::{
    menu::{Menu, MenuItem, Submenu},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            // Create tray menu
            let show_item = MenuItem::with_id(app, "show", "Show Window", true, None::<&str>)?;
            let hide_item = MenuItem::with_id(app, "hide", "Hide Window", true, None::<&str>)?;
            let separator1 = MenuItem::with_id(app, "sep1", "─────────────", false, None::<&str>)?;
            let start_all = MenuItem::with_id(app, "start_all", "▶ Start All Services", true, None::<&str>)?;
            let stop_all = MenuItem::with_id(app, "stop_all", "⏹ Stop All Services", true, None::<&str>)?;
            let restart_all = MenuItem::with_id(app, "restart_all", "↻ Restart All Services", true, None::<&str>)?;
            let separator2 = MenuItem::with_id(app, "sep2", "─────────────", false, None::<&str>)?;

            // Read hosts and create submenu
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
            let hosts_file = format!("{}/localhost-manager/conf/hosts.json", home);

            let mut host_items: Vec<MenuItem<tauri::Wry>> = Vec::new();
            if let Ok(content) = std::fs::read_to_string(&hosts_file) {
                if let Ok(hosts) = serde_json::from_str::<serde_json::Value>(&content) {
                    if let Some(obj) = hosts.as_object() {
                        for (name, host) in obj.iter() {
                            let active = host.get("active").and_then(|v| v.as_bool()).unwrap_or(false);
                            let status = if active { "✓" } else { "✗" };
                            let label = format!("{} {}", status, name);
                            let item = MenuItem::with_id(app, &format!("toggle_host_{}", name), &label, true, None::<&str>)?;
                            host_items.push(item);
                        }
                    }
                }
            }

            let hosts_submenu = if host_items.is_empty() {
                let no_hosts = MenuItem::with_id(app, "no_hosts", "No hosts configured", false, None::<&str>)?;
                Submenu::with_items(app, "Hosts", true, &[&no_hosts])?
            } else {
                let refs: Vec<&dyn tauri::menu::IsMenuItem<tauri::Wry>> = host_items.iter().map(|i| i as &dyn tauri::menu::IsMenuItem<tauri::Wry>).collect();
                Submenu::with_id_and_items(app, "hosts_menu", "Hosts", true, &refs)?
            };

            let activate_hosts = MenuItem::with_id(app, "activate_hosts", "✓ Activate All", true, None::<&str>)?;
            let deactivate_hosts = MenuItem::with_id(app, "deactivate_hosts", "✗ Deactivate All", true, None::<&str>)?;
            let separator3 = MenuItem::with_id(app, "sep3", "─────────────", false, None::<&str>)?;
            let generate = MenuItem::with_id(app, "generate", "⚙ Generate Configs", true, None::<&str>)?;
            let separator4 = MenuItem::with_id(app, "sep4", "─────────────", false, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;

            let menu = Menu::with_items(
                app,
                &[
                    &show_item,
                    &hide_item,
                    &separator1,
                    &start_all,
                    &stop_all,
                    &restart_all,
                    &separator2,
                    &hosts_submenu,
                    &activate_hosts,
                    &deactivate_hosts,
                    &separator3,
                    &generate,
                    &separator4,
                    &quit_item,
                ],
            )?;

            // Build tray icon
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .tooltip("Localhost Manager")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "hide" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.hide();
                        }
                    }
                    "start_all" => {
                        // Detect and start all installed services
                        std::process::Command::new("sh")
                            .args(["-c", "brew services list | grep -E 'httpd|mysql|php' | awk '{print $1}' | xargs -I {} brew services start {}"])
                            .spawn()
                            .ok();
                    }
                    "stop_all" => {
                        // Detect and stop all installed services
                        std::process::Command::new("sh")
                            .args(["-c", "brew services list | grep -E 'httpd|mysql|php' | awk '{print $1}' | xargs -I {} brew services stop {}"])
                            .spawn()
                            .ok();
                    }
                    "restart_all" => {
                        // Detect and restart all installed services
                        std::process::Command::new("sh")
                            .args(["-c", "brew services list | grep -E 'httpd|mysql|php' | awk '{print $1}' | xargs -I {} brew services restart {}"])
                            .spawn()
                            .ok();
                    }
                    "activate_hosts" => {
                        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                        let hosts_file = format!("{}/localhost-manager/conf/hosts.json", home);
                        if let Ok(content) = std::fs::read_to_string(&hosts_file) {
                            if let Ok(mut hosts) = serde_json::from_str::<serde_json::Value>(&content) {
                                if let Some(obj) = hosts.as_object_mut() {
                                    for (_, host) in obj.iter_mut() {
                                        if let Some(h) = host.as_object_mut() {
                                            h.insert("active".to_string(), serde_json::Value::Bool(true));
                                        }
                                    }
                                    if let Ok(new_content) = serde_json::to_string_pretty(&hosts) {
                                        let _ = std::fs::write(&hosts_file, new_content);
                                    }
                                }
                            }
                        }
                    }
                    "deactivate_hosts" => {
                        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                        let hosts_file = format!("{}/localhost-manager/conf/hosts.json", home);
                        if let Ok(content) = std::fs::read_to_string(&hosts_file) {
                            if let Ok(mut hosts) = serde_json::from_str::<serde_json::Value>(&content) {
                                if let Some(obj) = hosts.as_object_mut() {
                                    for (_, host) in obj.iter_mut() {
                                        if let Some(h) = host.as_object_mut() {
                                            h.insert("active".to_string(), serde_json::Value::Bool(false));
                                        }
                                    }
                                    if let Ok(new_content) = serde_json::to_string_pretty(&hosts) {
                                        let _ = std::fs::write(&hosts_file, new_content);
                                    }
                                }
                            }
                        }
                    }
                    "generate" => {
                        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                        let script = format!("{}/localhost-manager/scripts/generate-all.sh", home);
                        std::process::Command::new("bash")
                            .arg(&script)
                            .spawn()
                            .ok();
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    id if id.starts_with("toggle_host_") => {
                        let host_name = id.strip_prefix("toggle_host_").unwrap();
                        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                        let hosts_file = format!("{}/localhost-manager/conf/hosts.json", home);
                        if let Ok(content) = std::fs::read_to_string(&hosts_file) {
                            if let Ok(mut hosts) = serde_json::from_str::<serde_json::Value>(&content) {
                                if let Some(obj) = hosts.as_object_mut() {
                                    if let Some(host) = obj.get_mut(host_name) {
                                        if let Some(h) = host.as_object_mut() {
                                            let current = h.get("active").and_then(|v| v.as_bool()).unwrap_or(false);
                                            h.insert("active".to_string(), serde_json::Value::Bool(!current));
                                            if let Ok(new_content) = serde_json::to_string_pretty(&hosts) {
                                                let _ = std::fs::write(&hosts_file, new_content);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        .on_window_event(|window, event| {
            // Hide window instead of closing when clicking the X button
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                window.hide().unwrap();
                api.prevent_close();
            }
        })
        .invoke_handler(tauri::generate_handler![
            get_available_php_versions,
            get_installed_php_versions,
            install_php_version,
            uninstall_php_version,
            get_php_config,
            update_php_ini_setting,
            get_virtual_hosts,
            save_virtual_hosts,
            generate_configs,
            apply_configs,
            control_service,
            delete_host,
            get_services_status,
            get_current_php_version,
            get_current_apache_version,
            get_current_mysql_version,
            get_system_language,
            execute_with_privileges,
            get_home_directory,
            get_scripts_path,
            detect_installed_stacks,
            setup_directories,
            create_initial_config,
            read_file,
            write_file,
            // Stack Installer
            detect_platform,
            check_package_installed,
            install_package,
            // PHP Extensions
            get_installed_php_versions_list,
            get_php_extensions,
            toggle_php_extension,
            restart_php_fpm,
            // MySQL Configuration
            check_mysql_connection,
            get_mysql_users,
            change_mysql_root_password,
            create_mysql_user,
            delete_mysql_user,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
