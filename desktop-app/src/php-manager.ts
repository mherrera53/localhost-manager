// ============================================
// PHP Version Manager
// ============================================

import { state } from './state';
import * as api from './api';
import { showToast } from './ui';

export async function loadAvailableVersions() {
  try {
    const versions = await api.getAvailablePhpVersions();
    state.setAvailableVersions(versions);
    renderAvailableVersions();
  } catch (error) {
    console.error('Error loading available versions:', error);
    showToast('Failed to load available PHP versions', 'error');
  }
}

export async function loadInstalledVersions() {
  try {
    const versions = await api.getInstalledPhpVersions();
    state.setInstalledVersions(versions);
    renderInstalledVersions();
    populateVersionSelects();
    loadCurrentVersions();
  } catch (error) {
    console.error('Error loading installed versions:', error);
    showToast('Failed to load installed PHP versions', 'error');
  }
}

export async function loadCurrentVersions() {
  // Load PHP current version
  try {
    const phpVersion = await api.getCurrentPhpVersion();
    const phpCurrentEl = document.getElementById('php-current-version');
    if (phpCurrentEl) {
      phpCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: ${phpVersion}`;
    }
  } catch (error) {
    console.error('Error loading current PHP version:', error);
    const phpCurrentEl = document.getElementById('php-current-version');
    if (phpCurrentEl) {
      phpCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: <span data-i18n="versions.notInstalled">Not installed</span>`;
    }
  }

  // Load Apache current version
  try {
    const apacheVersion = await api.getCurrentApacheVersion();
    const apacheCurrentEl = document.getElementById('apache-current-version');
    if (apacheCurrentEl) {
      apacheCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: ${apacheVersion}`;
    }
  } catch (error) {
    console.error('Error loading current Apache version:', error);
    const apacheCurrentEl = document.getElementById('apache-current-version');
    if (apacheCurrentEl) {
      apacheCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: <span data-i18n="versions.notInstalled">Not installed</span>`;
    }
  }

  // Load MySQL current version
  try {
    const mysqlVersion = await api.getCurrentMysqlVersion();
    const mysqlCurrentEl = document.getElementById('mysql-current-version');
    if (mysqlCurrentEl) {
      mysqlCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: ${mysqlVersion}`;
    }
  } catch (error) {
    console.error('Error loading current MySQL version:', error);
    const mysqlCurrentEl = document.getElementById('mysql-current-version');
    if (mysqlCurrentEl) {
      mysqlCurrentEl.innerHTML = `<span data-i18n="versions.current">Current</span>: <span data-i18n="versions.notInstalled">Not installed</span>`;
    }
  }
}

export function renderAvailableVersions() {
  const container = document.getElementById('available-versions');
  if (!container) return;

  const { availableVersions } = state;

  if (availableVersions.length === 0) {
    container.innerHTML = '<p class="empty-state">No versions available</p>';
    return;
  }

  container.innerHTML = availableVersions.map(version => `
    <div class="version-item">
      <div class="version-info">
        <span class="version-number">PHP ${version.version}</span>
        <span class="version-badge available">Available</span>
      </div>
      <div class="version-actions">
        ${version.installed
          ? '<button class="btn btn-sm btn-secondary" disabled>Installed</button>'
          : `<button class="btn btn-sm btn-primary" onclick="window.phpManager.install('${version.version}')">Install</button>`
        }
      </div>
    </div>
  `).join('');
}

export function renderInstalledVersions() {
  const container = document.getElementById('installed-versions');
  if (!container) return;

  const { installedVersions } = state;

  if (installedVersions.length === 0) {
    container.innerHTML = '<p class="empty-state">No versions installed</p>';
    return;
  }

  container.innerHTML = installedVersions.map(version => `
    <div class="version-item">
      <div class="version-info">
        <span class="version-number">PHP ${version.version}</span>
        <span class="version-badge installed">Installed</span>
      </div>
      <div class="version-actions">
        <button class="btn btn-sm btn-danger" onclick="window.phpManager.uninstall('${version.version}')">Uninstall</button>
      </div>
    </div>
  `).join('');
}

export async function install(version: string) {
  try {
    showToast(`Installing PHP ${version}...`, 'warning');

    const result = await api.installPhpVersion(version);

    showToast(result, 'success');
    await loadInstalledVersions();
    await loadAvailableVersions();
  } catch (error) {
    console.error('Installation error:', error);
    showToast(`Installation failed: ${error}`, 'error');
  }
}

export async function uninstall(version: string) {
  if (!confirm(`Are you sure you want to uninstall PHP ${version}?`)) {
    return;
  }

  try {
    showToast(`Uninstalling PHP ${version}...`, 'warning');

    const result = await api.uninstallPhpVersion(version);

    showToast(result, 'success');
    await loadInstalledVersions();
    await loadAvailableVersions();
  } catch (error) {
    console.error('Uninstallation error:', error);
    showToast(`Uninstallation failed: ${error}`, 'error');
  }
}

export function populateVersionSelects() {
  const selects = [
    document.getElementById('config-version-select'),
    document.getElementById('project-php-version')
  ];

  const { installedVersions } = state;

  selects.forEach(select => {
    if (!select) return;

    const currentValue = (select as HTMLSelectElement).value;
    select.innerHTML = '<option value="">Select PHP Version...</option>';

    installedVersions.forEach(version => {
      const option = document.createElement('option');
      option.value = version.version;
      option.textContent = `PHP ${version.version}`;
      select.appendChild(option);
    });

    if (currentValue) {
      (select as HTMLSelectElement).value = currentValue;
    }
  });

  // Populate server version selects
  populateServerVersionSelects();
}

async function populateServerVersionSelects() {
  // PHP versions select
  const phpSelect = document.getElementById('php-version-selector') as HTMLSelectElement;
  if (phpSelect) {
    try {
      const currentVersion = await api.getCurrentPhpVersion();
      const installedVersions = await api.getInstalledPhpVersions();

      phpSelect.innerHTML = '';

      if (installedVersions.length === 0) {
        const option = document.createElement('option');
        option.value = '';
        option.textContent = 'No PHP versions installed';
        phpSelect.appendChild(option);
      } else {
        installedVersions.forEach(version => {
          const option = document.createElement('option');
          option.value = version.version;
          option.textContent = `PHP ${version.version}`;
          if (version.version === currentVersion) {
            option.selected = true;
          }
          phpSelect.appendChild(option);
        });
      }
    } catch (error) {
      console.error('Error populating PHP versions:', error);
      phpSelect.innerHTML = '<option value="">Error loading versions</option>';
    }
  }

  // Apache versions select
  const apacheSelect = document.getElementById('apache-version-selector') as HTMLSelectElement;
  if (apacheSelect) {
    try {
      const currentVersion = await api.getCurrentApacheVersion();
      apacheSelect.innerHTML = '';

      // Common Apache versions via Homebrew
      const apacheVersions = ['2.4.62', '2.4.61', '2.4.60'];

      if (currentVersion && !apacheVersions.includes(currentVersion)) {
        // Add current version if not in list
        apacheVersions.unshift(currentVersion);
      }

      apacheVersions.forEach(version => {
        const option = document.createElement('option');
        option.value = version;
        option.textContent = `Apache ${version}`;
        if (version === currentVersion) {
          option.selected = true;
        }
        apacheSelect.appendChild(option);
      });
    } catch (error) {
      console.error('Error populating Apache versions:', error);
      apacheSelect.innerHTML = '<option value="">Error loading versions</option>';
    }
  }

  // MySQL versions select
  const mysqlSelect = document.getElementById('mysql-version-selector') as HTMLSelectElement;
  if (mysqlSelect) {
    try {
      const currentVersion = await api.getCurrentMysqlVersion();
      mysqlSelect.innerHTML = '';

      // Common MySQL versions via Homebrew
      const mysqlVersions = ['8.4.7', '8.4.3', '8.0.40', '5.7.44'];

      if (currentVersion && !mysqlVersions.includes(currentVersion)) {
        // Add current version if not in list
        mysqlVersions.unshift(currentVersion);
      }

      mysqlVersions.forEach(version => {
        const option = document.createElement('option');
        option.value = version;
        option.textContent = `MySQL ${version}`;
        if (version === currentVersion) {
          option.selected = true;
        }
        mysqlSelect.appendChild(option);
      });
    } catch (error) {
      console.error('Error populating MySQL versions:', error);
      mysqlSelect.innerHTML = '<option value="">Error loading versions</option>';
    }
  }
}

export async function loadConfig(version: string) {
  if (!version) {
    clearConfig();
    return;
  }

  try {
    const config = await api.getPhpConfig(version);
    state.setCurrentConfig(config);
    renderIniSettings();
    renderExtensions();
  } catch (error) {
    console.error('Error loading PHP config:', error);
    showToast(`Failed to load config for PHP ${version}`, 'error');
  }
}

function clearConfig() {
  state.setCurrentConfig(null);
  const settingsContainer = document.getElementById('php-ini-settings');
  const extensionsContainer = document.getElementById('php-extensions');

  if (settingsContainer) {
    settingsContainer.innerHTML = '<p class="empty-state">Select a PHP version to view settings</p>';
  }

  if (extensionsContainer) {
    extensionsContainer.innerHTML = '<p class="empty-state">Select a PHP version to view extensions</p>';
  }
}

function renderIniSettings() {
  const container = document.getElementById('php-ini-settings');
  if (!container || !state.currentConfig) return;

  const settings = Object.entries(state.currentConfig.settings).slice(0, 20);

  if (settings.length === 0) {
    container.innerHTML = '<p class="empty-state">No settings found</p>';
    return;
  }

  container.innerHTML = settings.map(([key, value]) => `
    <div class="setting-item">
      <span class="setting-key">${key}</span>
      <span class="setting-value">${value}</span>
    </div>
  `).join('');
}

function renderExtensions() {
  const container = document.getElementById('php-extensions');
  if (!container || !state.currentConfig) return;

  if (state.currentConfig.extensions.length === 0) {
    container.innerHTML = '<p class="empty-state">No extensions found</p>';
    return;
  }

  container.innerHTML = state.currentConfig.extensions.map(ext => `
    <div class="extension-item">
      <span class="extension-name">${ext.name}</span>
      <div class="extension-toggle ${ext.enabled ? 'enabled' : ''}"></div>
    </div>
  `).join('');
}
