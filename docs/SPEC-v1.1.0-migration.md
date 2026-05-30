# SPEC v1.1.0 -- Configuration Sharing & Smart Migration

Status: **ready to implement** (designed 2026-05-30, not yet built).
Target version: **1.1.0**.

## Goal
Make the Localhost Manager config window able to (a) **share a config** with
coworkers as a portable bundle, and (b) **migrate** an existing local setup from
many sources, so people already working manually can adopt the manager without
re-typing everything.

User decisions that scope this:
- The shared **bundle = `hosts.json` only** (the domains). Scripts ship with the
  manager, so they are NOT part of the bundle. No certs in the bundle.
- Migration **sources to support**: Docker / docker-compose, MAMP/XAMPP/WAMP/
  Laragon (Apache -- parser already exists), loose JSON, Valet / nginx / Vite.
- Deliver as one **v1.1.0**, but build/verify each piece before moving on.

---

## Repository & environment facts (read before coding)
- GitHub: `github.com/mherrera53/localhost-manager`. Local working copy:
  `~/PARA/3_Recursos/Tools/localhost-manager` (this is a symlink/alias into
  `~/Library/CloudStorage/OneDrive-Personal/PARA/3_Recursos/Tools/localhost-manager`).
- **`main` is branch-protected**: every change MUST go through a PR (no direct
  push, `enforce_admins: true`, no force-push, no deletions). Create a branch ->
  PR -> wait for "Lint and Test" -> squash-merge.
- App is **Tauri v2**. Frontend TS in `desktop-app/src/`, Rust backend in
  `desktop-app/src-tauri/src/`. Tauri commands are registered in
  `desktop-app/src-tauri/src/lib.rs` inside `tauri::generate_handler![ ... ]`.
- Runtime data lives in `~/localhost-manager/` (NOT in the repo):
  `conf/hosts.json` (the host map), `app-config.json` (paths), `certs/`,
  `scripts/`. `app-config.json` holds `scripts_base_path` etc.
- `hosts.json` shape (one entry per domain):
  ```json
  {
    "app.example.com": {
      "domain": "app.example.com",
      "docroot": "/abs/path/to/dist",
      "aliases": [{ "id": "alias_xxx", "value": "www.example.com", "active": true }],
      "group": "MyGroup",
      "active": false,
      "ssl": true,
      "type": "vue",
      "stack": "frontend",     // or "backend"
      "php_version": null,
      "port": null,            // backend dev-server port (proxied) when stack=backend
      "mode": "local",
      "dev_command": "yarn dev:fast"
    }
  }
  ```
  Aliases are **parent-driven**: an alias is served whenever its parent domain is
  active (the per-alias `active` flag is ignored by the generators). Keep that.

## What already exists (reuse, don't rebuild)
- `scripts/import-environments.sh` and `scripts/windows/import-environments.ps1`
  already detect MAMP / MAMP PRO / XAMPP / WAMP / Laragon and parse their Apache
  `<VirtualHost>` blocks (ServerName/ServerAlias/DocumentRoot/SSL) into hosts.json
  with an idempotent merge + backup. The Apache-vhost parsing logic there is the
  reference for `migrate_from_apache`.
- `desktop-app/src-tauri/src/recovered.rs` has `PathsConfig`, `get_app_config`,
  `save_app_config`, `reset_app_config`, `validate_config_paths`,
  `detect_dev_command` (prefers `dev:fast`, uses idiomatic `yarn <script>`),
  `start/stop_backend_service`, `detect_server_paths`. Put new migration commands
  in a new `migration.rs` module (cleaner) and register them in `lib.rs`.
- `desktop-app/src/app-config.ts` already wires the config modal incl. folder
  pickers (`data-browse` / `data-browse-file`) and `detect_server_paths`
  (Auto-detect). Add the new Import/Share UI next to it.

---

## Backend (Rust) -- new module `desktop-app/src-tauri/src/migration.rs`

Add the `zip` crate to `desktop-app/src-tauri/Cargo.toml`
(`zip = "2"`), and also bump `Cargo.lock` (or let CI regenerate it).

Reuse this helper from existing code: hosts.json path =
`$HOME/localhost-manager/conf/hosts.json`. A shared `HostEntry`/`serde_json::Value`
representation is fine -- keep hosts.json as generic `Map<String, Value>` to avoid
schema drift, and only set the fields shown above when creating new entries
(`active:false`, `group:"Imported (<src>)"`, etc.).

Commands (all `#[tauri::command]`, registered in `lib.rs`):

1. `export_hosts_bundle(dest: String) -> Result<String, String>`
   - Writes a `.zip` containing `hosts.json` (and a small `manifest.json` with
     `{version, exportedAt, count}`) to `dest`. If `dest` ends in `.json`, write
     plain hosts.json instead. Return the path written.

2. `import_hosts_bundle(path: String) -> Result<ImportPreview, String>`
   - Accepts a `.zip` or `.json`. Extracts/reads the incoming hosts map.
   - Does an **idempotent merge**: never overwrite an existing domain; add only
     new domains; backup `hosts.json` -> `hosts.json.bak` first.
   - Returns `ImportPreview { added: Vec<String>, skipped: Vec<String> }`.
   - IMPORTANT: do NOT wipe existing config (mirror the idempotency fix in
     `hosts_manager::create_initial_config`).

3. `preview_import(path: String) -> Result<ImportPreview, String>`
   - Same parsing as #2 but **does not write** -- used to show a confirmation
     preview in the UI before applying. (Add a `dry_run: bool` param to #2 if you
     prefer one command.)

4. `migrate_from_docker(compose_path: String) -> Result<Vec<HostCandidate>, String>`
   - Parse `docker-compose.yml` (YAML). For each service with a published port
     (`ports: ["8080:80"]` -> host port 8080) build a candidate:
     `domain = (container_name || service_name) + ".test"`,
     `stack="backend"`, `port = <host port>`, `mode="local"`, `active=false`.
     If a service has a `labels` like `manager.domain=foo.test`, prefer it.
   - Return candidates for preview; caller decides what to import.

5. `migrate_from_apache(file: String) -> Result<Vec<HostCandidate>, String>`
   - Port the Apache `<VirtualHost>` parser from `import-environments.sh`
     (ServerName, ServerAlias[], DocumentRoot, `:443`/SSLEngine => ssl).

6. `migrate_from_valet() -> Result<Vec<HostCandidate>, String>`
   - Read `~/.config/valet/config.json` (`paths` = parked dirs) and the `tld`
     (default `test`). Each subdir of a parked path => `dir.<tld>` with
     `docroot = that subdir`, `stack="frontend"`.

7. `migrate_from_nginx(dir: String) -> Result<Vec<HostCandidate>, String>`
   - Parse `*.conf` in an nginx `sites-enabled` dir: `server_name`, `root`, and
     `proxy_pass http://127.0.0.1:PORT` (=> backend+port) or `root` (=> frontend).

8. `apply_candidates(candidates: Vec<HostCandidate>) -> Result<ImportPreview, String>`
   - Idempotent merge of chosen candidates into hosts.json (backup first).

Types:
```rust
#[derive(Serialize, Deserialize, Clone)]
struct HostCandidate { domain: String, docroot: Option<String>, port: Option<u16>,
  aliases: Vec<String>, ssl: bool, stack: String, source: String }
#[derive(Serialize)]
struct ImportPreview { added: Vec<String>, skipped: Vec<String> }
```

Vite/Next proxy: optional, low priority -- detect a `vite.config.*` `server.proxy`
or `package.json` dev port and offer it as a single backend candidate. Can ship
in v1.1.1 if time-boxed.

---

## Frontend (TS + HTML)

New module `desktop-app/src/migration.ts` and a new section in the config modal
(`desktop-app/index.html`, near the Application Configuration modal):

UI "Import / Share":
- **Export config** button -> `save` dialog (`@tauri-apps/plugin-dialog` `save`)
  -> `invoke('export_hosts_bundle', { dest })` -> toast with path.
- **Import config** button -> `open` file dialog (filters: `.zip,.json`) ->
  `invoke('preview_import', { path })` -> show a **preview modal** listing
  `added` / `skipped` -> on confirm `invoke('import_hosts_bundle', { path })` ->
  reload hosts (`loadVirtualHosts()`).
- **Migrate from…** dropdown (Docker / Apache / Valet / nginx / JSON) +
  "Auto-detect" button:
  - Docker: pick a `docker-compose.yml` -> `migrate_from_docker` -> preview ->
    select which candidates -> `apply_candidates`.
  - Apache: reuse the existing env importer paths OR pick a vhosts file.
  - Each path runs `migrate_from_*` -> shows a **multi-select preview table**
    (domain, docroot/port, source, checkbox) -> `apply_candidates(selected)`.
- Everything goes through a **preview before apply** so nothing is overwritten by
  surprise. Imported hosts arrive `active:false`; the user activates + applies.

Wiring lives in `initConfigListeners()` (or a new `initMigrationListeners()` call
from `main.ts`). Follow the existing `data-browse` pattern and `app-config.ts`
style. `openDialog`/`save` come from `@tauri-apps/plugin-dialog` (already a dep).

---

## Build / release / verify (do NOT skip -- lessons from the v1.0.x incident)
1. Work on a branch off `origin/main`; main is protected.
2. Before committing: `cd desktop-app/src-tauri && cargo fmt && cargo clippy -- -D warnings`
   (CI runs `cargo fmt --check`, `clippy -D warnings`, `cargo test`), and
   `cd desktop-app && node node_modules/typescript/bin/tsc --noEmit`.
   **Both must pass locally** -- the broken release happened from skipping this.
3. Bump version to **1.0.4 (deps/audit)** then **1.1.0** in: `desktop-app/package.json`,
   `desktop-app/src-tauri/tauri.conf.json`, `desktop-app/src-tauri/Cargo.toml`,
   and `desktop-app/src-tauri/Cargo.lock` (the `[[package]] name="desktop-app"` entry).
4. NEVER `git add -A` against a partial working tree. The earlier broken build
   came from the working tree missing `src-tauri/src/*.rs`; confirm all `.rs`
   modules exist before committing. `git diff origin/main --diff-filter=D` must
   only show files you intend to delete.
5. Open PR -> Lint and Test green -> squash-merge -> `git tag v1.1.0 origin/main &&
   git push origin v1.1.0`. `release.yml` signs + notarizes + staples + publishes.
6. Signing/notarization secrets already configured (APPLE_CERTIFICATE [single
   Developer ID p12], APPLE_CERTIFICATE_PASSWORD, APPLE_SIGNING_IDENTITY, APPLE_ID,
   APPLE_PASSWORD, APPLE_TEAM_ID = SRVK53YUSF). Local signed build:
   `APPLE_SIGNING_IDENTITY="Developer ID Application: Mario Herrera (SRVK53YUSF)" \
    APPLE_ID=mario-e-herrera@hotmail.com APPLE_PASSWORD=<app-specific> \
    APPLE_TEAM_ID=SRVK53YUSF npm run tauri build`.
7. Reinstall by replacing `/Applications/Localhost Manager.app` (keeps
   `~/Library/WebKit/com.localhost-manager.app` localStorage and `~/localhost-manager`
   data). The setup wizard must never run on an existing install.

## Acceptance criteria
- Export produces a `.zip` (or `.json`) with just hosts.json; a coworker imports
  it and gets the new domains **without losing their own** (idempotent merge,
  backup written).
- Docker/Apache/Valet/nginx migration each produce a **preview** the user
  confirms; nothing is written without confirmation.
- `cargo clippy -D warnings`, `cargo fmt --check`, `tsc`, and `cargo test` all
  pass; release `.dmg` is Developer-ID signed + notarized + stapled.
- Existing 14 hosts and `~/localhost-manager/` data are untouched by the upgrade.
