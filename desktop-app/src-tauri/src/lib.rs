mod config;
mod hosts_manager;
mod php_manager;
mod system;
mod types;

use hosts_manager::*;
use php_manager::*;
use system::*;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
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
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
