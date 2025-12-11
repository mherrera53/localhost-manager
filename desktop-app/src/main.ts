// ============================================
// Main Application Entry Point
// ============================================

import * as phpManager from './php-manager';
import * as hosts from './hosts';
import * as api from './api';
import { initI18n, setLanguage } from './i18n';

// ============================================
// Initialize Application
// ============================================

function initializeEventListeners() {
  // Generate configs button
  document.getElementById('btn-generate-configs')?.addEventListener('click', () => {
    hosts.generateConfigs();
  });

  // Toggle services button (header)
  document.getElementById('toggleServersBtn')?.addEventListener('click', () => {
    hosts.toggleServices();
  });

  // Stack selector
  const stackSelector = document.getElementById('stackSelector') as HTMLSelectElement;
  if (stackSelector) {
    // Load saved stack
    const savedStack = localStorage.getItem('serverStack') || 'native';
    stackSelector.value = savedStack;

    // Listen for changes
    stackSelector.addEventListener('change', (e) => {
      const stack = (e.target as HTMLSelectElement).value;
      localStorage.setItem('serverStack', stack);
      hosts.onStackChanged(stack);
    });
  }

  // Open host button
  document.getElementById('btn-open-host')?.addEventListener('click', () => {
    hosts.openCurrentHost();
  });

  // Rename domain button
  document.getElementById('btn-rename-domain')?.addEventListener('click', () => {
    hosts.renameDomain();
  });

  // Delete host button
  document.getElementById('btn-delete-host')?.addEventListener('click', () => {
    hosts.deleteCurrentHost();
  });

  // Additional sidebar buttons
  document.getElementById('btn-web-manager')?.addEventListener('click', () => {
    window.open('http://localhost:8080', '_blank');
  });

  document.getElementById('btn-vscode')?.addEventListener('click', () => {
    window.open('vscode://file/Users/mario/Sites/localhost', '_blank');
  });

  document.getElementById('btn-backup')?.addEventListener('click', () => {
    openBackupManager();
  });

  // Add host and group buttons
  document.getElementById('btn-add-host')?.addEventListener('click', () => {
    hosts.showAddHostModal();
  });

  document.getElementById('btn-add-group')?.addEventListener('click', () => {
    hosts.showAddGroupDialog();
  });

  // Add alias button
  document.getElementById('btn-add-alias')?.addEventListener('click', () => {
    const currentHost = hosts.getCurrentHost();
    if (currentHost) {
      hosts.addAlias(currentHost.domain);
    }
  });

  // Browse docroot buttons
  document.getElementById('btn-browse-detail-docroot')?.addEventListener('click', async () => {
    await hosts.browseDocrootFolder();
  });

  document.getElementById('btn-browse-docroot')?.addEventListener('click', async () => {
    await hosts.browseModalDocrootFolder();
  });

  // Language selector
  const languageSelector = document.getElementById('languageSelector') as HTMLSelectElement;
  if (languageSelector) {
    // Load saved language
    const savedLang = localStorage.getItem('language');
    if (savedLang) {
      languageSelector.value = savedLang;
    }

    // Listen for changes
    languageSelector.addEventListener('change', (e) => {
      const lang = (e.target as HTMLSelectElement).value;
      localStorage.setItem('language', lang);
      setLanguage(lang);
      console.log('Language changed to:', lang);
    });
  }

  // Host search
  document.getElementById('hostSearch')?.addEventListener('input', (e) => {
    const term = (e.target as HTMLInputElement).value.toLowerCase();
    const groups = document.querySelectorAll('.nav-group');

    groups.forEach(group => {
      let hasMatch = false;
      const items = group.querySelectorAll('.host-link');

      items.forEach(item => {
        const domain = item.getAttribute('data-domain')?.toLowerCase() || '';
        if (domain.includes(term)) {
          (item as HTMLElement).style.display = 'flex';
          hasMatch = true;
        } else {
          (item as HTMLElement).style.display = 'none';
        }
      });

      // Show/Hide group based on matches
      if (term === '') {
        (group as HTMLElement).style.display = 'block';
      } else {
        (group as HTMLElement).style.display = hasMatch ? 'block' : 'none';
      }
    });
  });

  // Version selectors
  document.getElementById('php-version-selector')?.addEventListener('change', async (e) => {
    const version = (e.target as HTMLSelectElement).value;
    if (version) {
      try {
        await api.controlService('switch', `php@${version}`);
        await phpManager.loadCurrentVersions();
      } catch (error) {
        console.error('Error switching PHP version:', error);
      }
    }
  });

  document.getElementById('apache-version-selector')?.addEventListener('change', async (e) => {
    const version = (e.target as HTMLSelectElement).value;
    if (version) {
      try {
        await api.controlService('switch', `httpd@${version}`);
        await phpManager.loadCurrentVersions();
      } catch (error) {
        console.error('Error switching Apache version:', error);
      }
    }
  });

  document.getElementById('mysql-version-selector')?.addEventListener('change', async (e) => {
    const version = (e.target as HTMLSelectElement).value;
    if (version) {
      try {
        await api.controlService('switch', `mysql@${version}`);
        await phpManager.loadCurrentVersions();
      } catch (error) {
        console.error('Error switching MySQL version:', error);
      }
    }
  });

  // Drag & Drop for document root input
  const docrootInput = document.getElementById('modal-docroot') as HTMLInputElement;
  if (docrootInput) {
    docrootInput.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
      docrootInput.classList.add('drag-over');
    });

    docrootInput.addEventListener('dragleave', (e) => {
      e.preventDefault();
      e.stopPropagation();
      docrootInput.classList.remove('drag-over');
    });

    docrootInput.addEventListener('drop', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      docrootInput.classList.remove('drag-over');

      if (e.dataTransfer?.files && e.dataTransfer.files.length > 0) {
        const file = e.dataTransfer.files[0];
        // Get the path - Tauri provides this through webkitGetAsEntry
        const entry = e.dataTransfer.items[0].webkitGetAsEntry();
        if (entry) {
          // For Tauri, we can read the path from the File object
          const path = (file as any).path || file.name;
          docrootInput.value = path;
        }
      }
    });
  }
}

async function loadInitialData() {
  // Detect and set system language
  try {
    const systemLang = await api.getSystemLanguage();
    const languageSelector = document.getElementById('languageSelector') as HTMLSelectElement;
    if (languageSelector) {
      const savedLang = localStorage.getItem('language');
      // Use saved language if exists, otherwise use system language
      const langToUse = savedLang || systemLang;
      languageSelector.value = langToUse;
      localStorage.setItem('language', langToUse);

      // Initialize i18n with detected/saved language
      initI18n(langToUse);

      console.log(`Language set to: ${langToUse} (system: ${systemLang})`);
    }
  } catch (error) {
    console.error('Failed to detect system language:', error);
    // Fallback to English
    initI18n('en');
  }

  await hosts.loadVirtualHosts();
  await phpManager.loadAvailableVersions();
  await phpManager.loadInstalledVersions();
  hosts.startServicesPolling();
}

// ============================================
// Application Bootstrap
// ============================================

window.addEventListener('DOMContentLoaded', () => {
  initializeEventListeners();
  loadInitialData();
});

// ============================================
// Expose API to window for debugging
// ============================================

declare global {
  interface Window {
    phpManager: typeof phpManager;
    hosts: typeof hosts;
    hostsManager: typeof hosts;
  }
}

window.phpManager = phpManager;
window.hosts = hosts;
window.hostsManager = hosts;

// ============================================
// Backup Manager Functions
// ============================================

async function openBackupManager() {
  const savedPath = localStorage.getItem('backupScriptPath');
  const savedApp = localStorage.getItem('backupTerminalApp');

  // If config exists, open directly
  if (savedPath && savedApp) {
    await executeBackup(savedPath, savedApp);
    return;
  }

  // Otherwise show config modal
  await showBackupConfigModal();
}

async function detectInstalledTerminals(): Promise<string[]> {
  const terminals = [
    { name: 'Warp', path: '/Applications/Warp.app' },
    { name: 'iTerm', path: '/Applications/iTerm.app' },
    { name: 'Terminal', path: '/System/Applications/Utilities/Terminal.app' },
    { name: 'Hyper', path: '/Applications/Hyper.app' },
    { name: 'Alacritty', path: '/Applications/Alacritty.app' },
    { name: 'Kitty', path: '/Applications/kitty.app' },
    { name: 'VS Code', path: '/Applications/Visual Studio Code.app' },
  ];

  const installed: string[] = [];

  try {
    const { Command } = await import('@tauri-apps/plugin-shell');

    for (const term of terminals) {
      try {
        const cmd = Command.create('sh', ['-c', `[ -d "${term.path}" ] && echo "yes" || echo "no"`]);
        const output = await cmd.execute();
        if (output.stdout.trim() === 'yes') {
          installed.push(term.name);
        }
      } catch {
        // Ignore errors for individual checks
      }
    }
  } catch (error) {
    console.error('Error detecting terminals:', error);
  }

  // Always add Finder as fallback
  installed.push('Finder');

  return installed.length > 1 ? installed : ['Terminal', 'Finder'];
}

async function showBackupConfigModal() {
  const modal = document.getElementById('backupConfigModal');
  const pathInput = document.getElementById('backup-script-path') as HTMLInputElement;
  const appSelect = document.getElementById('backup-terminal-app') as HTMLSelectElement;
  const saveBtn = document.getElementById('btn-save-backup-config');
  const browseBtn = document.getElementById('btn-browse-backup-script');

  if (!modal || !pathInput || !appSelect || !saveBtn) {
    console.error('Backup modal elements not found');
    return;
  }

  // Detect and populate installed terminals
  const installedTerminals = await detectInstalledTerminals();
  appSelect.innerHTML = installedTerminals.map(t =>
    `<option value="${t}">${t}${t === 'Finder' ? ' (just open folder)' : ''}</option>`
  ).join('');

  // Load saved values
  pathInput.value = localStorage.getItem('backupScriptPath') || '';
  const savedApp = localStorage.getItem('backupTerminalApp');
  if (savedApp && installedTerminals.includes(savedApp)) {
    appSelect.value = savedApp;
  }

  // Show modal
  const bootstrapModal = new (window as any).bootstrap.Modal(modal);
  bootstrapModal.show();

  // Setup event handlers (remove old ones first)
  const newBrowseBtn = browseBtn?.cloneNode(true) as HTMLElement;
  browseBtn?.parentNode?.replaceChild(newBrowseBtn, browseBtn);

  const newSaveBtn = saveBtn.cloneNode(true) as HTMLElement;
  saveBtn.parentNode?.replaceChild(newSaveBtn, saveBtn);

  // Browse button handler
  newBrowseBtn?.addEventListener('click', async () => {
    try {
      const { open } = await import('@tauri-apps/plugin-dialog');
      const selected = await open({
        directory: true,
        multiple: false,
        title: 'Select backup script or folder'
      });
      if (selected && typeof selected === 'string') {
        pathInput.value = selected;
      }
    } catch (error) {
      console.error('Error browsing:', error);
    }
  });

  // Save button handler
  newSaveBtn.addEventListener('click', async () => {
    const path = pathInput.value.trim();
    const app = appSelect.value;

    if (!path) {
      alert('Please enter a path');
      return;
    }

    localStorage.setItem('backupScriptPath', path);
    localStorage.setItem('backupTerminalApp', app);

    bootstrapModal.hide();

    // Small delay to let modal close
    setTimeout(async () => {
      await executeBackup(path, app);
    }, 300);
  });
}

async function executeBackup(path: string, app: string) {
  try {
    const { Command } = await import('@tauri-apps/plugin-shell');

    console.log(`Opening ${path} with ${app}`);

    if (app === 'Finder') {
      const command = Command.create('open', [path]);
      const result = await command.execute();
      console.log('Finder result:', result);
    } else {
      const command = Command.create('open', ['-a', app, path]);
      const result = await command.execute();
      console.log('Terminal result:', result);
    }
  } catch (error) {
    console.error('Error executing backup:', error);
    alert(`Error opening: ${error}`);
  }
}
