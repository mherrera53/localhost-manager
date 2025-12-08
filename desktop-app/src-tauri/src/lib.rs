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
