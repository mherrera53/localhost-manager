// ============================================
// Stack Manager - Install & Configure Stack
// ============================================

import { invoke } from "@tauri-apps/api/core";

// ============================================
// Types
// ============================================

interface PlatformInfo {
  os: string;
  packageManager: string;
  available: boolean;
}

interface ExtensionInfo {
  name: string;
  enabled: boolean;
  installed: boolean;
}

interface MysqlUser {
  user: string;
  host: string;
}

// ============================================
// Stack Installer
// ============================================

let stackInstallerModal: any = null;
let phpExtensionsModal: any = null;
let mysqlConfigModal: any = null;

export function initStackManager() {
  // Initialize modals
  const stackModalEl = document.getElementById('stackInstallerModal');
  const phpExtModalEl = document.getElementById('phpExtensionsModal');
  const mysqlModalEl = document.getElementById('mysqlConfigModal');

  if (stackModalEl) {
    stackInstallerModal = new (window as any).bootstrap.Modal(stackModalEl);
    stackModalEl.addEventListener('shown.bs.modal', onStackInstallerOpen);
  }

  if (phpExtModalEl) {
    phpExtensionsModal = new (window as any).bootstrap.Modal(phpExtModalEl);
    phpExtModalEl.addEventListener('shown.bs.modal', onPhpExtensionsOpen);
  }

  if (mysqlModalEl) {
    mysqlConfigModal = new (window as any).bootstrap.Modal(mysqlModalEl);
    mysqlModalEl.addEventListener('shown.bs.modal', onMysqlConfigOpen);
  }

  // Button listeners
  document.getElementById('btn-stack-installer')?.addEventListener('click', () => stackInstallerModal?.show());
  document.getElementById('btn-php-extensions')?.addEventListener('click', () => phpExtensionsModal?.show());
  document.getElementById('btn-mysql-config')?.addEventListener('click', () => mysqlConfigModal?.show());

  // Stack Installer buttons
  document.getElementById('btn-install-apache')?.addEventListener('click', () => installPackage('apache'));
  document.getElementById('btn-install-mysql')?.addEventListener('click', () => installPackage('mysql'));
  document.getElementById('btn-install-php')?.addEventListener('click', () => installPackage('php'));
  document.getElementById('btn-install-all')?.addEventListener('click', installCompleteStack);

  // PHP Extensions
  document.getElementById('ext-php-version')?.addEventListener('change', loadPhpExtensions);
  document.getElementById('ext-search')?.addEventListener('input', filterExtensions);
  document.getElementById('btn-restart-php')?.addEventListener('click', restartPhpFpm);

  // MySQL Config
  document.getElementById('btn-change-mysql-password')?.addEventListener('click', changeMysqlPassword);
  document.getElementById('btn-create-mysql-user')?.addEventListener('click', createMysqlUser);
}

// ============================================
// Stack Installer Functions
// ============================================

async function onStackInstallerOpen() {
  await detectPlatform();
  await checkInstalledPackages();
}

async function detectPlatform() {
  const platformEl = document.getElementById('detected-platform');
  const pmEl = document.getElementById('platform-package-manager');

  try {
    const info = await invoke<PlatformInfo>('detect_platform');

    if (platformEl) {
      platformEl.textContent = info.os;
      platformEl.className = 'badge bg-primary me-2';
    }

    if (pmEl) {
      if (info.available) {
        pmEl.innerHTML = `<i class="ti ti-check text-success me-1"></i>${info.packageManager} available`;
      } else {
        pmEl.innerHTML = `<i class="ti ti-x text-danger me-1"></i>${info.packageManager} not found`;
      }
    }
  } catch (error) {
    console.error('Failed to detect platform:', error);
    if (platformEl) {
      platformEl.textContent = 'Unknown';
      platformEl.className = 'badge bg-secondary me-2';
    }
  }
}

async function checkInstalledPackages() {
  const packages = ['apache', 'mysql', 'php'];

  for (const pkg of packages) {
    const statusEl = document.getElementById(`${pkg}-status`);
    const btnEl = document.getElementById(`btn-install-${pkg}`);

    try {
      const installed = await invoke<boolean>('check_package_installed', { package: pkg });

      if (statusEl) {
        if (installed) {
          statusEl.textContent = 'Installed';
          statusEl.className = 'badge bg-success me-2';
        } else {
          statusEl.textContent = 'Not Installed';
          statusEl.className = 'badge bg-secondary me-2';
        }
      }

      if (btnEl) {
        if (installed) {
          btnEl.textContent = 'Reinstall';
          (btnEl as HTMLButtonElement).classList.remove('btn-primary');
          (btnEl as HTMLButtonElement).classList.add('btn-outline-secondary');
        }
      }
    } catch (error) {
      console.error(`Failed to check ${pkg}:`, error);
    }
  }
}

async function installPackage(packageName: string) {
  const logContainer = document.getElementById('install-log-container');
  const logEl = document.getElementById('install-log');
  const btnEl = document.getElementById(`btn-install-${packageName}`) as HTMLButtonElement;

  if (logContainer) logContainer.classList.remove('d-none');
  if (logEl) logEl.textContent = `Installing ${packageName}...\n`;
  if (btnEl) {
    btnEl.disabled = true;
    btnEl.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Installing...';
  }

  try {
    // Get PHP version if installing PHP
    let version = '';
    if (packageName === 'php') {
      const versionSelect = document.getElementById('php-version-select') as HTMLSelectElement;
      version = versionSelect?.value || '8.3';
    }

    const result = await invoke<string>('install_package', {
      package: packageName,
      version
    });

    if (logEl) logEl.textContent += result + '\n';

    await checkInstalledPackages();
    showToast('Success', `${packageName} installed successfully!`, 'success');
  } catch (error) {
    if (logEl) logEl.textContent += `Error: ${error}\n`;
    showToast('Error', `Failed to install ${packageName}: ${error}`, 'danger');
  } finally {
    if (btnEl) {
      btnEl.disabled = false;
      btnEl.innerHTML = '<i class="ti ti-download me-1"></i>Install';
    }
  }
}

async function installCompleteStack() {
  const btn = document.getElementById('btn-install-all') as HTMLButtonElement;
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Installing...';
  }

  try {
    await installPackage('apache');
    await installPackage('mysql');
    await installPackage('php');
    showToast('Success', 'Complete stack installed successfully!', 'success');
  } catch (error) {
    showToast('Error', `Failed to install stack: ${error}`, 'danger');
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="ti ti-package me-2"></i>Install Complete Stack (Apache + MySQL + PHP)';
    }
  }
}

// ============================================
// PHP Extensions Functions
// ============================================

async function onPhpExtensionsOpen() {
  await loadPhpVersions();
}

async function loadPhpVersions() {
  const select = document.getElementById('ext-php-version') as HTMLSelectElement;
  if (!select) return;

  try {
    const versions = await invoke<string[]>('get_installed_php_versions_list');

    select.innerHTML = '';
    for (const version of versions) {
      const option = document.createElement('option');
      option.value = version;
      option.textContent = `PHP ${version}`;
      select.appendChild(option);
    }

    if (versions.length > 0) {
      await loadPhpExtensions();
    } else {
      const grid = document.getElementById('extensions-grid');
      if (grid) {
        grid.innerHTML = '<div class="col-12 text-center py-4 text-muted">No PHP versions installed</div>';
      }
    }
  } catch (error) {
    console.error('Failed to load PHP versions:', error);
    select.innerHTML = '<option value="">Error loading versions</option>';
  }
}

async function loadPhpExtensions() {
  const versionSelect = document.getElementById('ext-php-version') as HTMLSelectElement;
  const grid = document.getElementById('extensions-grid');

  if (!versionSelect || !grid) return;

  const version = versionSelect.value;
  if (!version) return;

  grid.innerHTML = '<div class="col-12 text-center py-4"><div class="spinner-border text-primary"></div></div>';

  try {
    const extensions = await invoke<ExtensionInfo[]>('get_php_extensions', { version });

    grid.innerHTML = '';

    // Common extensions to highlight
    const commonExtensions = [
      'curl', 'gd', 'mbstring', 'mysql', 'mysqli', 'pdo', 'pdo_mysql',
      'zip', 'xml', 'json', 'openssl', 'soap', 'intl', 'bcmath',
      'imagick', 'redis', 'memcached', 'xdebug', 'opcache'
    ];

    // Sort: common first, then alphabetical
    extensions.sort((a, b) => {
      const aCommon = commonExtensions.some(c => a.name.includes(c));
      const bCommon = commonExtensions.some(c => b.name.includes(c));
      if (aCommon && !bCommon) return -1;
      if (!aCommon && bCommon) return 1;
      return a.name.localeCompare(b.name);
    });

    for (const ext of extensions) {
      const col = document.createElement('div');
      col.className = 'col-md-4 col-sm-6 extension-item';
      col.dataset.name = ext.name.toLowerCase();

      const isCommon = commonExtensions.some(c => ext.name.includes(c));

      col.innerHTML = `
        <div class="card card-sm ${isCommon ? 'border-primary' : ''}">
          <div class="card-body py-2 px-3">
            <div class="d-flex justify-content-between align-items-center">
              <div>
                <span class="fw-medium">${ext.name}</span>
                ${isCommon ? '<span class="badge bg-primary-lt ms-1">Popular</span>' : ''}
              </div>
              <label class="form-check form-switch mb-0">
                <input class="form-check-input ext-toggle" type="checkbox"
                       data-ext="${ext.name}"
                       ${ext.enabled ? 'checked' : ''}
                       ${!ext.installed ? 'disabled' : ''}>
              </label>
            </div>
          </div>
        </div>
      `;

      grid.appendChild(col);
    }

    // Add toggle listeners
    document.querySelectorAll('.ext-toggle').forEach(toggle => {
      toggle.addEventListener('change', async (e) => {
        const checkbox = e.target as HTMLInputElement;
        const extName = checkbox.dataset.ext;
        const enabled = checkbox.checked;

        try {
          await invoke('toggle_php_extension', {
            version,
            extension: extName,
            enable: enabled
          });
          showToast('Success', `${extName} ${enabled ? 'enabled' : 'disabled'}`, 'success');
        } catch (error) {
          checkbox.checked = !enabled; // Revert
          showToast('Error', `Failed to toggle ${extName}: ${error}`, 'danger');
        }
      });
    });

  } catch (error) {
    console.error('Failed to load extensions:', error);
    grid.innerHTML = `<div class="col-12 text-center py-4 text-danger">Error: ${error}</div>`;
  }
}

function filterExtensions() {
  const search = (document.getElementById('ext-search') as HTMLInputElement)?.value.toLowerCase() || '';
  const items = document.querySelectorAll('.extension-item');

  items.forEach(item => {
    const name = (item as HTMLElement).dataset.name || '';
    (item as HTMLElement).style.display = name.includes(search) ? '' : 'none';
  });
}

async function restartPhpFpm() {
  const btn = document.getElementById('btn-restart-php') as HTMLButtonElement;
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Restarting...';
  }

  try {
    await invoke('restart_php_fpm');
    showToast('Success', 'PHP-FPM restarted successfully', 'success');
  } catch (error) {
    showToast('Error', `Failed to restart PHP-FPM: ${error}`, 'danger');
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="ti ti-refresh me-1"></i>Restart PHP-FPM';
    }
  }
}

// ============================================
// MySQL Configuration Functions
// ============================================

async function onMysqlConfigOpen() {
  await checkMysqlConnection();
  await loadMysqlUsers();
}

async function checkMysqlConnection() {
  const statusEl = document.getElementById('mysql-connection-status');
  const textEl = document.getElementById('mysql-connection-text');

  if (!statusEl || !textEl) return;

  try {
    const connected = await invoke<boolean>('check_mysql_connection');

    if (connected) {
      statusEl.className = 'alert alert-success mb-4';
      textEl.textContent = 'Connected to MySQL';
    } else {
      statusEl.className = 'alert alert-warning mb-4';
      textEl.textContent = 'MySQL is not running or not accessible';
    }
  } catch (error) {
    statusEl.className = 'alert alert-danger mb-4';
    textEl.textContent = `Connection failed: ${error}`;
  }
}

async function loadMysqlUsers() {
  const tbody = document.getElementById('mysql-users-list');
  if (!tbody) return;

  try {
    const currentPassword = (document.getElementById('mysql-current-password') as HTMLInputElement)?.value || '';
    const users = await invoke<MysqlUser[]>('get_mysql_users', { rootPassword: currentPassword });

    tbody.innerHTML = '';

    for (const user of users) {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${user.user}</td>
        <td><code>${user.host}</code></td>
        <td>
          ${user.user !== 'root' ? `
            <button class="btn btn-sm btn-outline-danger btn-delete-user"
                    data-user="${user.user}" data-host="${user.host}">
              <i class="ti ti-trash"></i>
            </button>
          ` : '<span class="text-muted">-</span>'}
        </td>
      `;
      tbody.appendChild(tr);
    }

    // Add delete listeners
    document.querySelectorAll('.btn-delete-user').forEach(btn => {
      btn.addEventListener('click', async () => {
        const user = (btn as HTMLElement).dataset.user;
        const host = (btn as HTMLElement).dataset.host;
        if (confirm(`Delete user '${user}'@'${host}'?`)) {
          await deleteMysqlUser(user!, host!);
        }
      });
    });

  } catch (error) {
    tbody.innerHTML = `<tr><td colspan="3" class="text-center text-danger py-3">Error: ${error}</td></tr>`;
  }
}

async function changeMysqlPassword() {
  const currentPassword = (document.getElementById('mysql-current-password') as HTMLInputElement)?.value || '';
  const newPassword = (document.getElementById('mysql-new-password') as HTMLInputElement)?.value || '';
  const confirmPassword = (document.getElementById('mysql-confirm-password') as HTMLInputElement)?.value || '';

  if (newPassword !== confirmPassword) {
    showToast('Error', 'Passwords do not match', 'danger');
    return;
  }

  if (!newPassword) {
    showToast('Error', 'New password cannot be empty', 'danger');
    return;
  }

  const btn = document.getElementById('btn-change-mysql-password') as HTMLButtonElement;
  if (btn) btn.disabled = true;

  try {
    await invoke('change_mysql_root_password', { currentPassword, newPassword });
    showToast('Success', 'Root password changed successfully', 'success');

    // Update the current password field
    (document.getElementById('mysql-current-password') as HTMLInputElement).value = newPassword;
    (document.getElementById('mysql-new-password') as HTMLInputElement).value = '';
    (document.getElementById('mysql-confirm-password') as HTMLInputElement).value = '';
  } catch (error) {
    showToast('Error', `Failed to change password: ${error}`, 'danger');
  } finally {
    if (btn) btn.disabled = false;
  }
}

async function createMysqlUser() {
  const rootPassword = (document.getElementById('mysql-current-password') as HTMLInputElement)?.value || '';
  const username = (document.getElementById('mysql-new-username') as HTMLInputElement)?.value || '';
  const password = (document.getElementById('mysql-new-user-password') as HTMLInputElement)?.value || '';
  const host = (document.getElementById('mysql-user-host') as HTMLSelectElement)?.value || 'localhost';
  const grantAll = (document.getElementById('mysql-grant-all') as HTMLInputElement)?.checked || false;

  if (!username || !password) {
    showToast('Error', 'Username and password are required', 'danger');
    return;
  }

  const btn = document.getElementById('btn-create-mysql-user') as HTMLButtonElement;
  if (btn) btn.disabled = true;

  try {
    await invoke('create_mysql_user', { rootPassword, username, password, host, grantAll });
    showToast('Success', `User '${username}'@'${host}' created successfully`, 'success');

    // Clear form
    (document.getElementById('mysql-new-username') as HTMLInputElement).value = '';
    (document.getElementById('mysql-new-user-password') as HTMLInputElement).value = '';

    // Reload users
    await loadMysqlUsers();
  } catch (error) {
    showToast('Error', `Failed to create user: ${error}`, 'danger');
  } finally {
    if (btn) btn.disabled = false;
  }
}

async function deleteMysqlUser(username: string, host: string) {
  const rootPassword = (document.getElementById('mysql-current-password') as HTMLInputElement)?.value || '';

  try {
    await invoke('delete_mysql_user', { rootPassword, username, host });
    showToast('Success', `User '${username}'@'${host}' deleted`, 'success');
    await loadMysqlUsers();
  } catch (error) {
    showToast('Error', `Failed to delete user: ${error}`, 'danger');
  }
}

// ============================================
// Utility Functions
// ============================================

function showToast(title: string, message: string, type: 'success' | 'danger' | 'warning' | 'info' = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast show bg-${type} text-white`;
  toast.innerHTML = `
    <div class="toast-header bg-${type} text-white">
      <strong class="me-auto">${title}</strong>
      <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast"></button>
    </div>
    <div class="toast-body">${message}</div>
  `;

  container.appendChild(toast);

  setTimeout(() => toast.remove(), 5000);
}

// Export for window access
(window as any).stackManager = {
  init: initStackManager
};
