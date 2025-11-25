// ============================================
// System Utilities
// ============================================

use std::env;

/// Get the system's current language/locale
#[tauri::command]
pub fn get_system_language() -> String {
    // Try to get the system locale
    #[cfg(target_os = "macos")]
    {
        if let Ok(output) = std::process::Command::new("defaults")
            .args(["read", "-g", "AppleLanguages"])
            .output()
        {
            if let Ok(lang_list) = String::from_utf8(output.stdout) {
                // Parse the output which looks like: (\n    en,\n    "en-US"\n)
                if let Some(first_lang) = lang_list.lines().nth(1).and_then(|line| {
                    line.trim()
                        .trim_matches('"')
                        .trim_matches(',')
                        .split('-')
                        .next()
                }) {
                    return map_language_code(first_lang);
                }
            }
        }
    }

    #[cfg(target_os = "windows")]
    {
        // Use GetUserDefaultLocaleName on Windows
        // For now, use env var as fallback
    }

    // Fallback to environment variables
    if let Ok(lang) = env::var("LANG") {
        let lang_code = lang
            .split('.')
            .next()
            .unwrap_or("en")
            .split('_')
            .next()
            .unwrap_or("en");
        return map_language_code(lang_code);
    }

    // Final fallback
    "en".to_string()
}

fn map_language_code(code: &str) -> String {
    match code.to_lowercase().as_str() {
        "en" | "en_us" | "en_gb" => "en".to_string(),
        "es" | "es_es" | "es_mx" => "es".to_string(),
        "fr" | "fr_fr" | "fr_ca" => "fr".to_string(),
        "de" | "de_de" => "de".to_string(),
        "pt" | "pt_br" | "pt_pt" => "pt".to_string(),
        _ => "en".to_string(), // Default to English
    }
}

/// Execute a command with administrator/root privileges
/// On macOS: Uses AppleScript to show native password dialog
/// On Windows: Uses UAC elevation
/// On Linux: Uses pkexec or similar
#[tauri::command]
pub async fn execute_with_privileges(command: String, args: Vec<String>) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        execute_with_applescript_sudo(command, args).await
    }

    #[cfg(target_os = "windows")]
    {
        execute_with_uac(command, args).await
    }

    #[cfg(target_os = "linux")]
    {
        execute_with_pkexec(command, args).await
    }
}

#[cfg(target_os = "macos")]
async fn execute_with_applescript_sudo(
    command: String,
    args: Vec<String>,
) -> Result<String, String> {
    // Build the full command
    let full_command = format!("{} {}", command, args.join(" "));

    // Use AppleScript to request admin privileges
    let script = format!(
        r#"do shell script "{}" with administrator privileges"#,
        full_command.replace("\"", "\\\"")
    );

    let output = std::process::Command::new("osascript")
        .args(["-e", &script])
        .output()
        .map_err(|e| format!("Failed to execute: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[cfg(target_os = "windows")]
async fn execute_with_uac(command: String, args: Vec<String>) -> Result<String, String> {
    use std::os::windows::process::CommandExt;

    // CREATE_NO_WINDOW = 0x08000000
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    let output = std::process::Command::new("powershell")
        .args(&[
            "-Command",
            &format!(
                "Start-Process -FilePath '{}' -ArgumentList '{}' -Verb RunAs -Wait -WindowStyle Hidden",
                command,
                args.join(" ")
            ),
        ])
        .creation_flags(CREATE_NO_WINDOW)
        .output()
        .map_err(|e| format!("Failed to execute: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[cfg(target_os = "linux")]
async fn execute_with_pkexec(command: String, args: Vec<String>) -> Result<String, String> {
    // Try pkexec first (PolicyKit - GNOME/KDE)
    let mut cmd = std::process::Command::new("pkexec");
    cmd.arg(&command);
    cmd.args(&args);

    let output = cmd
        .output()
        .map_err(|e| format!("Failed to execute with pkexec: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}
