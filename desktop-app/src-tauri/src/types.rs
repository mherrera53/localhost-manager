use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhpVersion {
    pub version: String,
    pub major: u8,
    pub minor: u8,
    pub patch: u8,
    pub installed: bool,
    pub install_path: Option<String>,
    pub download_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhpExtension {
    pub name: String,
    pub enabled: bool,
    pub version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhpConfig {
    pub version: String,
    pub install_path: String,
    pub php_ini_path: String,
    pub extensions: Vec<PhpExtension>,
    pub settings: std::collections::HashMap<String, String>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectProfile {
    pub id: String,
    pub name: String,
    pub path: String,
    pub php_version: String,
    pub extensions: Vec<String>,
    pub custom_ini_settings: std::collections::HashMap<String, String>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadProgress {
    pub downloaded: u64,
    pub total: u64,
    pub percentage: f64,
    pub speed: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VirtualHostAlias {
    pub id: String,
    pub value: String,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VirtualHost {
    pub domain: String,
    pub docroot: String,
    pub aliases: Vec<VirtualHostAlias>,
    pub group: String,
    pub active: bool,
    pub ssl: bool,
    #[serde(rename = "type")]
    pub host_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServicesStatus {
    pub apache: bool,
    pub mysql: bool,
    pub php: bool,
    pub all_running: bool,
}
