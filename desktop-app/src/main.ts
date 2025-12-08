// ============================================
// Main Application Entry Point
// ============================================

// Import CSS from node_modules (bundled locally)
import '@tabler/core/dist/css/tabler.min.css';
import '@tabler/icons-webfont/dist/tabler-icons.min.css';

// Import Bootstrap JS properly for Vite
import * as bootstrap from 'bootstrap';

// Make Bootstrap available globally for HTML attributes like data-bs-toggle
(window as any).bootstrap = bootstrap;

// Import local styles (includes Inter font)
import './styles.css';

import * as phpManager from './php-manager';
import * as hosts from './hosts';
import * as api from './api';
import { initI18n, setLanguage } from './i18n';
import { initSetupWizard } from './setup-wizard';
import { initStackManager } from './stack-manager';

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

  document.getElementById('btn-vscode')?.addEventListener('click', async () => {
    // Open VS Code with the user's configured projects directory
    try {
      const homeDir = await api.getHomeDirectory();
      const projectsPath = localStorage.getItem('projectsPath') || `${homeDir}/Sites/localhost`;
      window.open(`vscode://file${projectsPath}`, '_blank');
    } catch (error) {
      console.error('Error opening VS Code:', error);
    }
  });

  document.getElementById('btn-backup')?.addEventListener('click', async () => {
    // Open backup scripts location - configurable per user
    try {
      const homeDir = await api.getHomeDirectory();
      const backupPath = localStorage.getItem('backupScriptPath') || `${homeDir}/Backups`;
      window.open(`file://${backupPath}`, '_blank');
    } catch (error) {
      console.error('Error opening backup location:', error);
    }
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
  // Check if first run and show setup wizard
  await initSetupWizard();

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
  initStackManager();
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
