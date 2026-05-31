// ============================================
// Configuration sharing & smart migration (v1.1.0)
// ============================================
// Two capabilities for the config window:
//   1. Share a portable hosts.json bundle (.zip or .json) with coworkers.
//   2. Migrate an existing local setup into the manager from Docker,
//      Apache (MAMP/XAMPP/WAMP/Laragon), Laravel Valet or nginx.
//
// Every write to hosts.json backs the previous file up to hosts.json.bak first
// and merges idempotently: an existing domain is NEVER overwritten, only new
// domains are added. The migration importers only *produce candidates*; nothing
// is written until the caller confirms via `apply_candidates`. Imported domains
// always arrive `active: false` so the user activates and applies them
// deliberately (their docroots/ports may differ on each machine).
//
// hosts.json is treated as a generic `Map<String, Value>` (not a fixed struct)
// to avoid schema drift with the rest of the app, which does the same.

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::io::{Read, Seek, Write};
use std::path::{Path, PathBuf};

// ---- shared types -------------------------------------------------------

/// A migration candidate surfaced for preview before the user imports it.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct HostCandidate {
    pub domain: String,
    pub docroot: Option<String>,
    pub port: Option<u16>,
    pub aliases: Vec<String>,
    pub ssl: bool,
    pub stack: String,
    pub source: String,
}

/// Result of an idempotent merge: which domains were added vs. left untouched.
#[derive(Serialize, Debug, Default, PartialEq)]
pub struct ImportPreview {
    pub added: Vec<String>,
    pub skipped: Vec<String>,
}

// ---- shared helpers -----------------------------------------------------

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

fn hosts_file_path() -> PathBuf {
    home_dir()
        .join("localhost-manager")
        .join("conf")
        .join("hosts.json")
}

/// Load hosts.json as a generic object map. Returns an empty map when the file
/// does not exist yet.
fn load_hosts_map() -> Result<Map<String, Value>, String> {
    let path = hosts_file_path();
    if !path.exists() {
        return Ok(Map::new());
    }
    let content = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
    match serde_json::from_str::<Value>(&content).map_err(|e| e.to_string())? {
        Value::Object(map) => Ok(map),
        _ => Err("hosts.json is not a JSON object".to_string()),
    }
}

/// Write hosts.json, backing the previous file up to hosts.json.bak first.
fn write_hosts_map(map: &Map<String, Value>) -> Result<(), String> {
    let path = hosts_file_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    if path.exists() {
        let backup = PathBuf::from(format!("{}.bak", path.display()));
        std::fs::copy(&path, &backup).map_err(|e| e.to_string())?;
    }
    let content =
        serde_json::to_string_pretty(&Value::Object(map.clone())).map_err(|e| e.to_string())?;
    std::fs::write(&path, content).map_err(|e| e.to_string())
}

/// Idempotent merge: add only new domains, never overwrite an existing one.
/// Newly added domains are forced `active: false`.
fn merge_into_hosts(
    existing: &mut Map<String, Value>,
    incoming: &Map<String, Value>,
) -> ImportPreview {
    let mut preview = ImportPreview::default();
    for (domain, entry) in incoming {
        if existing.contains_key(domain) {
            preview.skipped.push(domain.clone());
            continue;
        }
        let mut entry = entry.clone();
        if let Value::Object(ref mut obj) = entry {
            obj.insert("active".to_string(), Value::Bool(false));
        }
        existing.insert(domain.clone(), entry);
        preview.added.push(domain.clone());
    }
    preview.added.sort();
    preview.skipped.sort();
    preview
}

/// Build a full hosts.json entry from a migration candidate, mirroring the
/// shape produced by scripts/import-environments.sh.
fn candidate_to_entry(c: &HostCandidate) -> Value {
    let aliases: Vec<Value> = c
        .aliases
        .iter()
        .map(|a| {
            serde_json::json!({
                "id": format!("alias_{}", uuid::Uuid::new_v4()),
                "value": a,
                "active": true,
            })
        })
        .collect();

    let stack = if c.stack.is_empty() {
        "frontend"
    } else {
        c.stack.as_str()
    };

    let mut entry = serde_json::json!({
        "domain": c.domain,
        "docroot": c.docroot.clone().unwrap_or_default(),
        "aliases": aliases,
        "group": format!("Imported ({})", c.source),
        "active": false,
        "ssl": c.ssl,
        "type": "php",
        "stack": stack,
        "php_version": Value::Null,
        "port": c.port.map(Value::from).unwrap_or(Value::Null),
        "mode": "local",
    });

    // Backend candidates carry a dev_command placeholder the user fills in.
    if stack == "backend" {
        if let Value::Object(ref mut obj) = entry {
            obj.insert("dev_command".to_string(), Value::Null);
        }
    }
    entry
}

// ---- export / import bundle --------------------------------------------

/// Export the current hosts.json as a portable bundle. Writes a `.zip`
/// (hosts.json + manifest.json) unless `dest` ends in `.json`, in which case it
/// writes a plain hosts.json. Returns the path written.
#[tauri::command]
pub fn export_hosts_bundle(dest: String) -> Result<String, String> {
    let map = load_hosts_map()?;
    let count = map.len();
    let hosts_json =
        serde_json::to_string_pretty(&Value::Object(map)).map_err(|e| e.to_string())?;

    if dest.to_lowercase().ends_with(".json") {
        std::fs::write(&dest, hosts_json).map_err(|e| e.to_string())?;
        return Ok(dest);
    }

    let manifest = serde_json::json!({
        "version": env!("CARGO_PKG_VERSION"),
        "exportedAt": chrono::Utc::now().to_rfc3339(),
        "count": count,
    });
    let manifest_json = serde_json::to_string_pretty(&manifest).map_err(|e| e.to_string())?;

    let file = std::fs::File::create(&dest).map_err(|e| e.to_string())?;
    write_bundle_zip(file, &hosts_json, &manifest_json)?;
    Ok(dest)
}

/// Write a bundle zip (hosts.json + manifest.json) to any seekable writer.
fn write_bundle_zip<W: Write + Seek>(
    writer: W,
    hosts_json: &str,
    manifest_json: &str,
) -> Result<(), String> {
    let mut zip = zip::ZipWriter::new(writer);
    let options = zip::write::SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated);

    zip.start_file("hosts.json", options)
        .map_err(|e| e.to_string())?;
    zip.write_all(hosts_json.as_bytes())
        .map_err(|e| e.to_string())?;
    zip.start_file("manifest.json", options)
        .map_err(|e| e.to_string())?;
    zip.write_all(manifest_json.as_bytes())
        .map_err(|e| e.to_string())?;
    zip.finish().map_err(|e| e.to_string())?;
    Ok(())
}

/// Read hosts.json out of a bundle zip from any seekable reader.
fn read_bundle_zip<R: Read + Seek>(reader: R) -> Result<String, String> {
    let mut archive = zip::ZipArchive::new(reader).map_err(|e| e.to_string())?;
    let mut entry = archive
        .by_name("hosts.json")
        .map_err(|_| "hosts.json not found in bundle".to_string())?;
    let mut s = String::new();
    entry.read_to_string(&mut s).map_err(|e| e.to_string())?;
    Ok(s)
}

/// Read the hosts map from a bundle (`.zip` containing hosts.json, or a plain
/// `.json`).
fn read_bundle_hosts(path: &str) -> Result<Map<String, Value>, String> {
    let content = if path.to_lowercase().ends_with(".json") {
        std::fs::read_to_string(path).map_err(|e| e.to_string())?
    } else {
        let file = std::fs::File::open(path).map_err(|e| e.to_string())?;
        read_bundle_zip(file)?
    };
    match serde_json::from_str::<Value>(&content).map_err(|e| e.to_string())? {
        Value::Object(map) => Ok(map),
        _ => Err("bundle hosts.json is not a JSON object".to_string()),
    }
}

/// Preview an import without writing anything (used for the confirmation modal).
#[tauri::command]
pub fn preview_import(path: String) -> Result<ImportPreview, String> {
    let incoming = read_bundle_hosts(&path)?;
    let mut existing = load_hosts_map()?;
    Ok(merge_into_hosts(&mut existing, &incoming))
}

/// Import a bundle: idempotent merge into hosts.json (backup first). Existing
/// domains are never overwritten.
#[tauri::command]
pub fn import_hosts_bundle(path: String) -> Result<ImportPreview, String> {
    let incoming = read_bundle_hosts(&path)?;
    let mut existing = load_hosts_map()?;
    let preview = merge_into_hosts(&mut existing, &incoming);
    if !preview.added.is_empty() {
        write_hosts_map(&existing)?;
    }
    Ok(preview)
}

/// Apply chosen migration candidates: idempotent merge into hosts.json
/// (backup first).
#[tauri::command]
pub fn apply_candidates(candidates: Vec<HostCandidate>) -> Result<ImportPreview, String> {
    let mut incoming = Map::new();
    for c in &candidates {
        incoming.insert(c.domain.clone(), candidate_to_entry(c));
    }
    let mut existing = load_hosts_map()?;
    let preview = merge_into_hosts(&mut existing, &incoming);
    if !preview.added.is_empty() {
        write_hosts_map(&existing)?;
    }
    Ok(preview)
}

// ---- Docker ------------------------------------------------------------

/// Extract the host-side port from a docker-compose `ports` entry.
/// Handles `"8080:80"`, `"127.0.0.1:8080:80"`, `"8080:80/tcp"`, bare `8080`,
/// and the long syntax mapping `{ target: 80, published: 8080 }`.
fn docker_host_port(v: &serde_yaml::Value) -> Option<u16> {
    if let Some(s) = v.as_str() {
        return parse_port_mapping(s);
    }
    if let Some(n) = v.as_u64() {
        return u16::try_from(n).ok();
    }
    if let Some(published) = v.get("published") {
        if let Some(s) = published.as_str() {
            return s.parse().ok();
        }
        if let Some(n) = published.as_u64() {
            return u16::try_from(n).ok();
        }
    }
    None
}

fn parse_port_mapping(s: &str) -> Option<u16> {
    let s = s.split('/').next().unwrap_or(s); // strip "/tcp"
    let parts: Vec<&str> = s.split(':').collect();
    let host = match parts.len() {
        3 => parts[1], // ip:host:container
        2 => parts[0], // host:container
        1 => parts[0], // bare value
        _ => return None,
    };
    host.trim().parse::<u16>().ok()
}

/// Prefer an explicit `manager.domain` label (map or list form) for the domain.
fn docker_label_domain(service: &serde_yaml::Value) -> Option<String> {
    let labels = service.get("labels")?;
    if let Some(map) = labels.as_mapping() {
        for (k, val) in map {
            if k.as_str() == Some("manager.domain") {
                return val.as_str().map(|s| s.to_string());
            }
        }
    }
    if let Some(seq) = labels.as_sequence() {
        for item in seq {
            if let Some(rest) = item
                .as_str()
                .and_then(|s| s.strip_prefix("manager.domain="))
            {
                return Some(rest.to_string());
            }
        }
    }
    None
}

/// Parse a docker-compose document into backend candidates. Only services that
/// publish a host port are included.
pub fn parse_docker_compose(yaml: &str) -> Vec<HostCandidate> {
    let doc: serde_yaml::Value = match serde_yaml::from_str(yaml) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    let services = match doc.get("services").and_then(|s| s.as_mapping()) {
        Some(m) => m,
        None => return Vec::new(),
    };

    let mut out = Vec::new();
    for (name, service) in services.iter() {
        let service_name = match name.as_str() {
            Some(n) => n,
            None => continue,
        };
        let port = service
            .get("ports")
            .and_then(|p| p.as_sequence())
            .and_then(|seq| seq.iter().find_map(docker_host_port));
        let port = match port {
            Some(p) => p,
            None => continue, // only services with a published port
        };
        let domain = docker_label_domain(service).unwrap_or_else(|| {
            let base = service
                .get("container_name")
                .and_then(|c| c.as_str())
                .unwrap_or(service_name);
            format!("{base}.test")
        });
        out.push(HostCandidate {
            domain,
            docroot: None,
            port: Some(port),
            aliases: Vec::new(),
            ssl: false,
            stack: "backend".to_string(),
            source: "docker".to_string(),
        });
    }
    out
}

#[tauri::command]
pub fn migrate_from_docker(compose_path: String) -> Result<Vec<HostCandidate>, String> {
    let content = std::fs::read_to_string(&compose_path).map_err(|e| e.to_string())?;
    Ok(parse_docker_compose(&content))
}

// ---- Apache ------------------------------------------------------------

const APACHE_SKIP_NAMES: [&str; 3] = ["___default___", "_default_", "default"];

/// Extract a directive value when `line` begins with `name` followed by
/// whitespace. `lower` is the lowercased `line` (directive names are ASCII).
fn apache_directive(lower: &str, line: &str, name: &str) -> Option<String> {
    if !lower.starts_with(name) {
        return None;
    }
    let rest = &line[name.len()..];
    if !rest.starts_with(|c: char| c.is_whitespace()) {
        return None;
    }
    let val = rest.trim();
    if val.is_empty() {
        None
    } else {
        Some(val.to_string())
    }
}

/// Parse Apache `<VirtualHost>` blocks into frontend candidates. Ports the
/// logic from scripts/import-environments.sh (ServerName/ServerAlias/
/// DocumentRoot, `:443` or `SSLEngine on` => ssl). Entries without a
/// DocumentRoot are skipped, matching the reference importer.
pub fn parse_apache_vhosts(text: &str) -> Vec<HostCandidate> {
    use std::collections::BTreeMap;
    // domain -> (docroot, aliases, ssl)
    let mut merged: BTreeMap<String, (Option<String>, Vec<String>, bool)> = BTreeMap::new();

    let mut in_block = false;
    let mut port: Option<u32> = None;
    let mut domain: Option<String> = None;
    let mut docroot: Option<String> = None;
    let mut aliases: Vec<String> = Vec::new();
    let mut ssl = false;

    for raw in text.lines() {
        let line = raw.trim();
        let lower = line.to_lowercase();

        if lower.starts_with("<virtualhost") {
            in_block = true;
            port = None;
            domain = None;
            docroot = None;
            aliases = Vec::new();
            ssl = false;
            // Port from the address, e.g. "<VirtualHost *:443>".
            if let Some(end) = line.find('>') {
                let inside = &line[..end];
                if let Some(colon) = inside.rfind(':') {
                    let digits: String = inside[colon + 1..]
                        .chars()
                        .take_while(|c| c.is_ascii_digit())
                        .collect();
                    port = digits.parse().ok();
                }
            }
        } else if lower.starts_with("</virtualhost") {
            if let Some(d) = domain.take() {
                let block_ssl = ssl || port == Some(443);
                let entry = merged.entry(d).or_insert((None, Vec::new(), false));
                if entry.0.is_none() {
                    entry.0 = docroot.clone();
                }
                for a in &aliases {
                    if !entry.1.contains(a) {
                        entry.1.push(a.clone());
                    }
                }
                entry.2 = entry.2 || block_ssl;
            }
            in_block = false;
        } else if in_block {
            if let Some(v) = apache_directive(&lower, line, "servername") {
                if !APACHE_SKIP_NAMES.contains(&v.as_str()) {
                    domain = Some(v);
                }
            } else if let Some(v) = apache_directive(&lower, line, "serveralias") {
                for a in v.split_whitespace() {
                    if !a.is_empty() && !APACHE_SKIP_NAMES.contains(&a) {
                        aliases.push(a.to_string());
                    }
                }
            } else if let Some(v) = apache_directive(&lower, line, "documentroot") {
                docroot = Some(v.trim_matches('"').to_string());
            } else if lower.starts_with("sslengine") && lower.contains("on") {
                ssl = true;
            }
        }
    }

    merged
        .into_iter()
        .filter_map(|(domain, (docroot, aliases, ssl))| {
            docroot.as_ref()?; // skip vhosts without a DocumentRoot
            Some(HostCandidate {
                domain,
                docroot,
                port: None,
                aliases,
                ssl,
                stack: "frontend".to_string(),
                source: "apache".to_string(),
            })
        })
        .collect()
}

#[tauri::command]
pub fn migrate_from_apache(file: String) -> Result<Vec<HostCandidate>, String> {
    let content = std::fs::read_to_string(&file).map_err(|e| e.to_string())?;
    Ok(parse_apache_vhosts(&content))
}

// ---- Laravel Valet -----------------------------------------------------

/// Parse a Valet config.json into (tld, parked paths).
fn parse_valet_config(json: &str) -> (String, Vec<String>) {
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return ("test".to_string(), Vec::new()),
    };
    let tld = value
        .get("tld")
        .and_then(|v| v.as_str())
        .unwrap_or("test")
        .to_string();
    let paths = value
        .get("paths")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|p| p.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();
    (tld, paths)
}

#[tauri::command]
pub fn migrate_from_valet() -> Result<Vec<HostCandidate>, String> {
    let config = home_dir().join(".config").join("valet").join("config.json");
    if !config.exists() {
        return Ok(Vec::new());
    }
    let content = std::fs::read_to_string(&config).map_err(|e| e.to_string())?;
    let (tld, paths) = parse_valet_config(&content);

    let mut out = Vec::new();
    for parked in paths {
        let entries = match std::fs::read_dir(&parked) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            let name = match path.file_name().and_then(|n| n.to_str()) {
                Some(n) if !n.starts_with('.') => n.to_string(),
                _ => continue,
            };
            out.push(HostCandidate {
                domain: format!("{name}.{tld}"),
                docroot: Some(path.to_string_lossy().to_string()),
                port: None,
                aliases: Vec::new(),
                ssl: false,
                stack: "frontend".to_string(),
                source: "valet".to_string(),
            });
        }
    }
    Ok(out)
}

// ---- nginx -------------------------------------------------------------

/// Strip `#` comments (to end of line) from an nginx config.
fn strip_hash_comments(text: &str) -> String {
    text.lines()
        .map(|l| match l.find('#') {
            Some(idx) => &l[..idx],
            None => l,
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn matches_word_at(chars: &[char], i: usize, word: &[char]) -> bool {
    if i + word.len() > chars.len() {
        return false;
    }
    if chars[i..i + word.len()] != *word {
        return false;
    }
    if i > 0 {
        let p = chars[i - 1];
        if p.is_alphanumeric() || p == '_' {
            return false;
        }
    }
    !matches!(chars.get(i + word.len()), Some(a) if a.is_alphanumeric() || *a == '_')
}

/// Extract the bodies of top-level `server { ... }` blocks with balanced braces.
fn server_blocks(text: &str) -> Vec<String> {
    let chars: Vec<char> = text.chars().collect();
    let word: Vec<char> = "server".chars().collect();
    let n = chars.len();
    let mut out = Vec::new();
    let mut i = 0;
    while i < n {
        if matches_word_at(&chars, i, &word) {
            let mut j = i + word.len();
            while j < n && chars[j].is_whitespace() {
                j += 1;
            }
            if j < n && chars[j] == '{' {
                let start = j + 1;
                let mut depth = 0;
                let mut k = j;
                while k < n {
                    match chars[k] {
                        '{' => depth += 1,
                        '}' => {
                            depth -= 1;
                            if depth == 0 {
                                break;
                            }
                        }
                        _ => {}
                    }
                    k += 1;
                }
                out.push(chars[start..k].iter().collect());
                i = k + 1;
                continue;
            }
        }
        i += 1;
    }
    out
}

/// Value of the first `name` directive (everything after the name token up to
/// the statement terminator).
fn nginx_first_directive(block: &str, name: &str) -> Option<String> {
    for stmt in block.split([';', '{', '}']) {
        let mut it = stmt.split_whitespace();
        if it.next() == Some(name) {
            let rest: Vec<&str> = it.collect();
            if !rest.is_empty() {
                return Some(rest.join(" "));
            }
        }
    }
    None
}

/// Host port from the first `proxy_pass http://host:PORT` directive.
fn nginx_proxy_port(block: &str) -> Option<u16> {
    for stmt in block.split([';', '{', '}']) {
        let mut it = stmt.split_whitespace();
        if it.next() == Some("proxy_pass") {
            if let Some(url) = it.next() {
                let after_scheme = url.split("://").nth(1).unwrap_or(url);
                let hostport = after_scheme.split('/').next().unwrap_or(after_scheme);
                if let Some(colon) = hostport.rfind(':') {
                    let port: String = hostport[colon + 1..]
                        .chars()
                        .take_while(|c| c.is_ascii_digit())
                        .collect();
                    if let Ok(p) = port.parse::<u16>() {
                        return Some(p);
                    }
                }
            }
        }
    }
    None
}

fn nginx_has_ssl(block: &str) -> bool {
    for stmt in block.split([';', '{', '}']) {
        let lower = stmt.to_lowercase();
        let mut it = lower.split_whitespace();
        if it.next() == Some("listen") && (lower.contains("ssl") || lower.contains("443")) {
            return true;
        }
    }
    false
}

/// Parse nginx `server` blocks. A block with a `proxy_pass` becomes a backend
/// candidate (with port); otherwise a frontend candidate served from `root`.
pub fn parse_nginx_conf(text: &str) -> Vec<HostCandidate> {
    let cleaned = strip_hash_comments(text);
    let mut out = Vec::new();
    for block in server_blocks(&cleaned) {
        let server_name = match nginx_first_directive(&block, "server_name") {
            Some(s) => s,
            None => continue,
        };
        let mut names: Vec<String> = server_name
            .split_whitespace()
            .filter(|n| *n != "_" && !n.is_empty())
            .map(|s| s.to_string())
            .collect();
        if names.is_empty() {
            continue;
        }
        let domain = names.remove(0);
        let aliases = names;

        let port = nginx_proxy_port(&block);
        let ssl = nginx_has_ssl(&block);
        let (stack, docroot) = if port.is_some() {
            ("backend".to_string(), None)
        } else {
            (
                "frontend".to_string(),
                nginx_first_directive(&block, "root").map(|r| r.trim_matches('"').to_string()),
            )
        };

        out.push(HostCandidate {
            domain,
            docroot,
            port,
            aliases,
            ssl,
            stack,
            source: "nginx".to_string(),
        });
    }
    out
}

#[tauri::command]
pub fn migrate_from_nginx(dir: String) -> Result<Vec<HostCandidate>, String> {
    let path = Path::new(&dir);
    let mut out = Vec::new();
    if path.is_dir() {
        for entry in std::fs::read_dir(path)
            .map_err(|e| e.to_string())?
            .flatten()
        {
            let p = entry.path();
            if p.extension().and_then(|e| e.to_str()) == Some("conf") {
                if let Ok(content) = std::fs::read_to_string(&p) {
                    out.extend(parse_nginx_conf(&content));
                }
            }
        }
    } else if path.is_file() {
        let content = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
        out.extend(parse_nginx_conf(&content));
    }
    Ok(out)
}

// ---- tests -------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn docker_parses_published_ports_and_skips_portless() {
        let yaml = r#"
services:
  web:
    image: nginx
    ports:
      - "8080:80"
  api:
    container_name: my_api
    ports:
      - "127.0.0.1:9000:9000/tcp"
  db:
    image: postgres
"#;
        let c = parse_docker_compose(yaml);
        assert_eq!(c.len(), 2, "db has no published port and must be skipped");

        let web = c.iter().find(|c| c.domain == "web.test").unwrap();
        assert_eq!(web.port, Some(8080));
        assert_eq!(web.stack, "backend");

        let api = c.iter().find(|c| c.domain == "my_api.test").unwrap();
        assert_eq!(api.port, Some(9000), "uses container_name and middle port");
    }

    #[test]
    fn docker_prefers_manager_domain_label() {
        let yaml = r#"
services:
  api:
    ports: ["3000:3000"]
    labels:
      manager.domain: custom.test
"#;
        let c = parse_docker_compose(yaml);
        assert_eq!(c.len(), 1);
        assert_eq!(c[0].domain, "custom.test");
        assert_eq!(c[0].port, Some(3000));
    }

    #[test]
    fn docker_long_syntax_published_port() {
        let yaml = r#"
services:
  api:
    ports:
      - target: 80
        published: 8443
        protocol: tcp
"#;
        let c = parse_docker_compose(yaml);
        assert_eq!(c.len(), 1);
        assert_eq!(c[0].port, Some(8443));
    }

    #[test]
    fn apache_parses_servername_alias_docroot_ssl() {
        let conf = r#"
<VirtualHost *:443>
    ServerName example.test
    ServerAlias www.example.test cdn.example.test
    DocumentRoot "/var/www/example/public"
    SSLEngine on
</VirtualHost>
<VirtualHost *:80>
    ServerName _default_
    DocumentRoot /var/www/html
</VirtualHost>
"#;
        let c = parse_apache_vhosts(conf);
        assert_eq!(c.len(), 1, "_default_ is skipped");
        let host = &c[0];
        assert_eq!(host.domain, "example.test");
        assert_eq!(host.docroot.as_deref(), Some("/var/www/example/public"));
        assert!(host.ssl);
        assert_eq!(host.aliases.len(), 2);
        assert!(host.aliases.contains(&"www.example.test".to_string()));
        assert_eq!(host.stack, "frontend");
    }

    #[test]
    fn apache_skips_vhost_without_docroot() {
        let conf = r#"
<VirtualHost *:80>
    ServerName nodoc.test
</VirtualHost>
"#;
        assert!(parse_apache_vhosts(conf).is_empty());
    }

    #[test]
    fn nginx_proxy_is_backend_root_is_frontend() {
        let conf = r#"
server {
    listen 443 ssl;
    server_name api.test www.api.test;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
server {
    listen 80;
    server_name site.test;
    root /var/www/site/dist;
}
"#;
        let c = parse_nginx_conf(conf);
        assert_eq!(c.len(), 2);

        let api = c.iter().find(|c| c.domain == "api.test").unwrap();
        assert_eq!(api.stack, "backend");
        assert_eq!(api.port, Some(8080));
        assert!(api.ssl);
        assert_eq!(api.aliases, vec!["www.api.test".to_string()]);

        let site = c.iter().find(|c| c.domain == "site.test").unwrap();
        assert_eq!(site.stack, "frontend");
        assert_eq!(site.docroot.as_deref(), Some("/var/www/site/dist"));
        assert!(!site.ssl);
    }

    #[test]
    fn valet_config_parse_defaults_and_values() {
        let (tld, paths) =
            parse_valet_config(r#"{"tld":"dev","paths":["/Users/x/Sites","/Users/x/code"]}"#);
        assert_eq!(tld, "dev");
        assert_eq!(paths.len(), 2);

        let (tld, paths) = parse_valet_config("{}");
        assert_eq!(tld, "test", "tld defaults to test");
        assert!(paths.is_empty());
    }

    #[test]
    fn zip_bundle_round_trips() {
        use std::io::Cursor;
        let hosts = r#"{"a.test":{"domain":"a.test"}}"#;
        let manifest = r#"{"version":"1.1.0","count":1}"#;

        let mut buf = Cursor::new(Vec::new());
        write_bundle_zip(&mut buf, hosts, manifest).unwrap();

        buf.set_position(0);
        let read_back = read_bundle_zip(buf).unwrap();
        assert_eq!(read_back, hosts);
    }

    #[test]
    fn merge_is_idempotent_and_never_overwrites() {
        let mut existing = Map::new();
        existing.insert(
            "keep.test".to_string(),
            serde_json::json!({ "domain": "keep.test", "active": true, "docroot": "/original" }),
        );

        let mut incoming = Map::new();
        // collides with existing -> must be skipped, existing untouched
        incoming.insert(
            "keep.test".to_string(),
            serde_json::json!({ "domain": "keep.test", "active": true, "docroot": "/IMPOSTER" }),
        );
        // new -> added, forced inactive
        incoming.insert(
            "new.test".to_string(),
            serde_json::json!({ "domain": "new.test", "active": true }),
        );

        let preview = merge_into_hosts(&mut existing, &incoming);
        assert_eq!(preview.added, vec!["new.test".to_string()]);
        assert_eq!(preview.skipped, vec!["keep.test".to_string()]);

        // existing entry preserved verbatim
        assert_eq!(existing["keep.test"]["docroot"], "/original");
        assert_eq!(existing["keep.test"]["active"], true);
        // newly added entry forced inactive
        assert_eq!(existing["new.test"]["active"], false);
    }
}
