# Changelog

## v1.0.1

### Fixed
- **Idempotent setup**: `create_initial_config` (the setup wizard) now creates
  `hosts.json` only if it does not already exist, so re-running the wizard or a
  clean reinstall never wipes an existing host configuration.

### Signing
- macOS release `.dmg`/`.app` are now signed with Developer ID, notarized and
  stapled (both the app and the dmg) via CI.

## v1.0.0

First stable release. Cross-platform, hardened and portable.

### Added
- **Environment import**: bring existing virtual hosts from **MAMP / MAMP PRO /
  XAMPP / WAMP / Laragon** into the manager. `scripts/import-environments.sh`
  (macOS/Linux) and `scripts/windows/import-environments.ps1` (Windows) detect
  installed stacks, parse their Apache `<VirtualHost>` blocks and merge them into
  `hosts.json` (imported hosts start inactive; `--dry-run` previews).
- **Windows support (BETA)**: PowerShell scripts under `scripts/windows/` and
  OS-aware command wiring in the app. Not yet tested on a real Windows machine.
- **DNS flush** on every hosts change and on local/production mode switch
  (`scripts/flush-dns.sh`, `ipconfig /flushdns` on Windows).
- **CI release** (`release.yml`): builds the macOS `.dmg` and Windows `.exe/.msi`
  and publishes a draft GitHub Release on a `v*` tag.

### Changed
- **Parent-driven aliases**: a domain's aliases are now served whenever the
  parent domain is active (whitelabel domains share one docroot). Applies to
  certs (SAN), Apache `ServerAlias`, `/etc/hosts` and the Windows equivalents.
- Certificates are regenerated when their SAN no longer covers the current
  aliases (previously a valid-but-stale cert was wrongly skipped).
- Fully portable: all machine-specific paths come from `app-config.json` / `$HOME`
  (no hardcoded user paths in scripts or UI).

### Security
- Removed legacy scripts that stored/piped the sudo password via Keychain.
- Apache start/stop/restart now elevate via `osascript` (Touch ID), never a
  stored password.
- `app-config.json` and `conf/settings.json` are gitignored (no machine paths or
  state committed); private keys and `hosts.json` were already ignored.
