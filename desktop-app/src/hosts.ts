// ============================================
// Virtual Hosts Manager
// ============================================

import { Command, open as openUrl } from "@tauri-apps/plugin-shell";
import { open as openDialog, ask } from '@tauri-apps/plugin-dialog';
import { invoke } from '@tauri-apps/api/core';
import Sortable from 'sortablejs';
import { showToast } from './ui';
import * as api from './api';
import type { ApacheAction, VirtualHost, ServicesStatus } from './types';

// Resolved at runtime from the per-machine app-config (no hardcoded path).
let SCRIPTS_PATH = '';
// Platform flag: macOS/Linux run bash .sh scripts; Windows runs PowerShell .ps1
// scripts under scripts/windows/. The Windows path is BETA / untested.
let IS_WINDOWS = false;

// Load scripts path + platform from the backend
async function loadScriptsPath() {
  try {
    const config: any = await invoke('get_app_config');
    SCRIPTS_PATH = config.scripts_base_path;
  } catch (error) {
    console.error('Failed to load config; scripts path is unset:', error);
  }
  try {
    const info: any = await invoke('detect_platform');
    IS_WINDOWS = String(info?.os ?? '').toLowerCase().includes('windows');
  } catch (error) {
    // Default to non-Windows (bash) if platform detection is unavailable
  }
}

loadScriptsPath();

// Stack configuration
interface StackConfig {
  name: string;
  apachePath: string;
  phpPath: string;
  mysqlPath: string;
  hostsPath: string;
  vhostPath: string;
  startCommand: string;
  stopCommand: string;
  restartCommand: string;
}

const STACK_CONFIGS: Record<string, StackConfig> = {
  native: {
    name: 'Native (Homebrew)',
    apachePath: '/opt/homebrew/bin/httpd',
    phpPath: '/opt/homebrew/bin/php',
    mysqlPath: '/opt/homebrew/bin/mysql',
    hostsPath: '/etc/hosts',
    vhostPath: '/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf',
    startCommand: '/opt/homebrew/bin/brew services start httpd',
    stopCommand: '/opt/homebrew/bin/brew services stop httpd',
    restartCommand: '/opt/homebrew/bin/brew services restart httpd'
  },
  mamp: {
    name: 'MAMP / MAMP PRO',
    apachePath: '/Applications/MAMP/Library/bin/httpd',
    phpPath: '/Applications/MAMP/bin/php',
    mysqlPath: '/Applications/MAMP/Library/bin/mysql',
    hostsPath: '/etc/hosts',
    vhostPath: '/Applications/MAMP/conf/apache/extra/httpd-vhosts.conf',
    startCommand: '/Applications/MAMP/bin/start.sh',
    stopCommand: '/Applications/MAMP/bin/stop.sh',
    restartCommand: '/Applications/MAMP/bin/stop.sh && /Applications/MAMP/bin/start.sh'
  },
  xampp: {
    name: 'XAMPP',
    apachePath: '/Applications/XAMPP/bin/httpd',
    phpPath: '/Applications/XAMPP/bin/php',
    mysqlPath: '/Applications/XAMPP/bin/mysql',
    hostsPath: '/etc/hosts',
    vhostPath: '/Applications/XAMPP/etc/extra/httpd-vhosts.conf',
    startCommand: 'sudo /Applications/XAMPP/xamppfiles/xampp start',
    stopCommand: 'sudo /Applications/XAMPP/xamppfiles/xampp stop',
    restartCommand: 'sudo /Applications/XAMPP/xamppfiles/xampp restart'
  },
  wamp: {
    name: 'WAMP / WampServer',
    apachePath: 'C:/wamp64/bin/apache/apache2.4.XX/bin/httpd.exe',
    phpPath: 'C:/wamp64/bin/php/phpX.X.XX',
    mysqlPath: 'C:/wamp64/bin/mysql/mysqlX.X.XX/bin/mysql.exe',
    hostsPath: 'C:/Windows/System32/drivers/etc/hosts',
    vhostPath: 'C:/wamp64/bin/apache/apache2.4.XX/conf/extra/httpd-vhosts.conf',
    startCommand: 'net start wampapache64',
    stopCommand: 'net stop wampapache64',
    restartCommand: 'net stop wampapache64 && net start wampapache64'
  },
  laragon: {
    name: 'Laragon',
    apachePath: 'C:/laragon/bin/apache/apache-2.4.XX/bin/httpd.exe',
    phpPath: 'C:/laragon/bin/php',
    mysqlPath: 'C:/laragon/bin/mysql/mysql-X.X.XX/bin/mysql.exe',
    hostsPath: 'C:/Windows/System32/drivers/etc/hosts',
    vhostPath: 'C:/laragon/etc/apache2/sites-enabled',
    startCommand: 'laragon start',
    stopCommand: 'laragon stop',
    restartCommand: 'laragon reload'
  },
  custom: {
    name: 'Custom Path',
    apachePath: '',
    phpPath: '',
    mysqlPath: '',
    hostsPath: '/etc/hosts',
    vhostPath: '',
    startCommand: '',
    stopCommand: '',
    restartCommand: ''
  }
};

let virtualHosts: Record<string, VirtualHost> = {};
let servicesStatus: ServicesStatus = {
  apache: false,
  mysql: false,
  php: false,
  all_running: false
};
let currentHost: VirtualHost | null = null;
// let currentStack: StackConfig = STACK_CONFIGS.native;

export async function loadVirtualHosts() {
  try {
    virtualHosts = await api.getVirtualHosts();
    renderSidebarHosts();
  } catch (error) {
    console.error('Error loading virtual hosts:', error);
    showToast('Failed to load virtual hosts', 'error');
  }
}

export async function loadServicesStatus() {
  try {
    servicesStatus = await api.getServicesStatus();
    updateServicesUI();
  } catch (error) {
    console.error('Error loading services status:', error);
  }
}

function renderSidebarHosts() {
  const groupList = document.getElementById('group-list');
  if (!groupList) return;

  if (Object.keys(virtualHosts).length === 0) {
    groupList.innerHTML = '<p class="empty-state">No virtual hosts configured</p>';
    return;
  }

  // Group hosts by group
  const groupedHosts: Record<string, VirtualHost[]> = {};
  for (const [domain, host] of Object.entries(virtualHosts)) {
    const group = host.group || 'Uncategorized';
    if (!groupedHosts[group]) {
      groupedHosts[group] = [];
    }
    groupedHosts[group].push({...host, domain});
  }

  // Get saved group order from localStorage or use alphabetical order
  const savedOrder = localStorage.getItem('groupOrder');
  let groupOrder: string[] = [];

  if (savedOrder) {
    try {
      groupOrder = JSON.parse(savedOrder);
      // Add any new groups that aren't in the saved order
      const allGroups = Object.keys(groupedHosts);
      for (const group of allGroups) {
        if (!groupOrder.includes(group)) {
          groupOrder.push(group);
        }
      }
      // Remove groups that no longer exist
      groupOrder = groupOrder.filter(g => allGroups.includes(g));
    } catch (e) {
      groupOrder = Object.keys(groupedHosts).sort();
    }
  } else {
    groupOrder = Object.keys(groupedHosts).sort();
  }

  let html = '';
  for (const group of groupOrder) {
    const hosts = groupedHosts[group];
    if (!hosts) continue;

    const groupId = `group-${group.replace(/\s+/g, '-').toLowerCase()}`;

    // Count active hosts
    const activeCount = hosts.filter(h => h.active).length;
    const totalCount = hosts.length;
    const hasActiveHosts = activeCount > 0;
    const showByDefault = hasActiveHosts ? 'show' : '';

    html += `
      <div class="nav-group">
        <div class="nav-group-title">
          <div class="d-flex align-items-center gap-2 flex-grow-1">
            <i class="ti ti-chevron-right group-arrow ${showByDefault}" id="arrow-${groupId}"></i>
            <i class="ti ti-folder${hasActiveHosts ? '-filled' : ''}"></i>
            <span class="group-name">${group}</span>
            <span class="badge ${hasActiveHosts ? 'bg-success' : 'bg-secondary'}" style="font-size: 0.65rem; padding: 0.15rem 0.4rem;">
              ${activeCount}/${totalCount}
            </span>
          </div>
          <button class="btn btn-sm btn-icon btn-ghost-secondary group-edit-btn" data-group="${group}" title="Rename Group">
            <i class="ti ti-edit" style="font-size: 14px;"></i>
          </button>
        </div>
        <div class="nav-group-items ${showByDefault}" id="${groupId}">
    `;

    // Get saved host order for this group, or use default order
    const hostOrderKey = `hostOrder_${group}`;
    const savedHostOrder = localStorage.getItem(hostOrderKey);
    let sortedHosts = [...hosts];

    if (savedHostOrder) {
      try {
        const order = JSON.parse(savedHostOrder);
        // Sort hosts based on saved order
        sortedHosts = hosts.sort((a, b) => {
          const indexA = order.indexOf(a.domain);
          const indexB = order.indexOf(b.domain);
          // If both are in the saved order, sort by their position
          if (indexA !== -1 && indexB !== -1) {
            return indexA - indexB;
          }
          // If only A is in the order, it comes first
          if (indexA !== -1) return -1;
          // If only B is in the order, it comes first
          if (indexB !== -1) return 1;
          // If neither is in the order, keep original order
          return 0;
        });
      } catch (e) {
        console.error('Error parsing host order:', e);
      }
    }

    for (const host of sortedHosts) {
      const statusClass = host.active ? 'on' : 'off';
      const sslIcon = host.ssl ? '<i class="ti ti-lock" style="font-size: 12px; opacity: 0.5;"></i>' : '';

      html += `
        <div class="host-link" data-domain="${host.domain}">
          <div class="d-flex align-items-center gap-2 w-100">
            <div class="status-dot ${statusClass}"></div>
            <span class="flex-grow-1">${host.domain}</span>
            ${sslIcon}
          </div>
        </div>
      `;
    }

    html += `
        </div>
      </div>
    `;
  }

  groupList.innerHTML = html;

  // Add click listeners using event delegation (won't interfere with drag)
  addHostClickListenersViaDelegate();
  addGroupEditListeners();
  addGroupCollapseListeners();

  // Initialize drag & drop
  initializeDragDrop();
}

function addGroupCollapseListeners() {
  // Add click listeners to group titles for collapsing
  const groupTitles = document.querySelectorAll('.nav-group-title');
  groupTitles.forEach(title => {
    title.addEventListener('click', (e) => {
      // Don't trigger if clicking the edit button
      if ((e.target as HTMLElement).closest('.group-edit-btn')) {
        return;
      }

      const groupItems = title.nextElementSibling as HTMLElement;
      const arrow = title.querySelector('.group-arrow') as HTMLElement;

      if (groupItems && groupItems.classList.contains('nav-group-items')) {
        groupItems.classList.toggle('show');
        arrow.classList.toggle('rotated');
      }
    });
  });
}

// Use event delegation to avoid interfering with SortableJS
function addHostClickListenersViaDelegate() {
  const groupList = document.getElementById('group-list');
  if (!groupList) return;

  // Remove any existing listener
  groupList.removeEventListener('click', handleHostClick);

  // Add delegated listener
  groupList.addEventListener('click', handleHostClick);
}

function handleHostClick(e: Event) {
  const target = e.target as HTMLElement;
  const hostLink = target.closest('.host-link');

  if (hostLink && !target.closest('.sortable-drag') && !target.closest('.sortable-ghost')) {
    const domain = (hostLink as HTMLElement).getAttribute('data-domain');
    if (domain) {
      selectHost(domain, hostLink as HTMLElement);
    }
  }
}

function addGroupEditListeners() {
  const editButtons = document.querySelectorAll('.group-edit-btn');
  editButtons.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const oldGroupName = (btn as HTMLElement).getAttribute('data-group');
      if (oldGroupName) {
        renameGroup(oldGroupName);
      }
    });
  });
}

async function renameGroup(oldGroupName: string) {
  // Set up the modal
  const modal = document.getElementById('renameGroupModal');
  const input = document.getElementById('rename-group-input') as HTMLInputElement;
  const confirmBtn = document.getElementById('btn-confirm-rename-group');

  if (!modal || !input || !confirmBtn) {
    console.error('Rename group modal elements not found');
    return;
  }

  // Initialize modal value
  input.value = oldGroupName;

  // Show modal using Bootstrap
  const bootstrapModal = new (window as any).bootstrap.Modal(modal);
  bootstrapModal.show();

  // Focus on input after modal is shown
  modal.addEventListener('shown.bs.modal', () => {
    input.focus();
    input.select();
  }, { once: true });

  // Handle rename confirmation
  const handleRename = async () => {
    const newGroupName = input.value.trim();

    if (!newGroupName || newGroupName === oldGroupName) {
      bootstrapModal.hide();
      return;
    }

    // Update all hosts in this group
    let updated = 0;
    for (const [domain, host] of Object.entries(virtualHosts)) {
      if ((host.group || 'Uncategorized') === oldGroupName) {
        virtualHosts[domain] = { ...host, group: newGroupName };
        updated++;
      }
    }

    if (updated > 0) {
      try {
        // Save changes to backend
        await api.saveVirtualHosts(virtualHosts);
        showToast(`Renamed group "${oldGroupName}" to "${newGroupName}". Remember to generate configs!`, 'success');
        renderSidebarHosts();
      } catch (error) {
        console.error('Error renaming group:', error);
        showToast('Failed to save group rename', 'error');
      }
    } else {
      showToast('No hosts found in this group', 'warning');
    }

    bootstrapModal.hide();
    // Clean up
    confirmBtn.removeEventListener('click', handleRename);
  };

  // Add event listener for confirm button
  confirmBtn.addEventListener('click', handleRename, { once: true });

  // Handle Enter key in input
  const handleEnter = (e: KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleRename();
    }
  };
  input.addEventListener('keypress', handleEnter, { once: true });

  // Clean up event listeners when modal is hidden
  modal.addEventListener('hidden.bs.modal', () => {
    input.removeEventListener('keypress', handleEnter);
  }, { once: true });
}

function selectHost(domain: string, linkElement: HTMLElement) {
  const host = virtualHosts[domain];
  if (!host) {
    showToast(`Host ${domain} not found`, 'error');
    return;
  }

  currentHost = {...host, domain};

  // Update sidebar active state
  document.querySelectorAll('.host-link').forEach(el => el.classList.remove('active'));
  linkElement.classList.add('active');

  // Update main content
  const emptyState = document.getElementById('emptyState');
  const hostDetails = document.getElementById('hostDetails');
  const hostActions = document.getElementById('hostActions');
  const selectedHostTitle = document.getElementById('selectedHostTitle');

  if (emptyState) emptyState.classList.add('d-none');
  if (hostDetails) hostDetails.classList.remove('d-none');
  if (hostActions) hostActions.style.display = 'block';
  if (selectedHostTitle) selectedHostTitle.textContent = domain;

  // Populate details
  const detailDomain = document.getElementById('detail-domain') as HTMLInputElement;
  const detailDocroot = document.getElementById('detail-docroot') as HTMLInputElement;
  const detailGroup = document.getElementById('detail-group') as HTMLSelectElement;
  const detailStatus = document.getElementById('detail-status');
  const detailSsl = document.getElementById('detail-ssl');
  const btnRenameHost = document.getElementById('btn-rename-host');

  // Domain editable input
  if (detailDomain) {
    detailDomain.value = domain;
    // Store original domain for rename
    detailDomain.dataset.originalDomain = domain;
  }

  // Rename host button
  if (btnRenameHost) {
    const newBtn = btnRenameHost.cloneNode(true) as HTMLButtonElement;
    btnRenameHost.parentNode?.replaceChild(newBtn, btnRenameHost);

    newBtn.addEventListener('click', async () => {
      const originalDomain = detailDomain?.dataset.originalDomain;
      const newDomain = detailDomain?.value.trim();

      if (!originalDomain || !newDomain || originalDomain === newDomain) {
        return;
      }

      if (virtualHosts[newDomain]) {
        showToast(`Domain ${newDomain} already exists`, 'error');
        return;
      }

      try {
        // Create new host with new domain name
        const hostData = { ...virtualHosts[originalDomain] };
        virtualHosts[newDomain] = hostData;
        delete virtualHosts[originalDomain];

        await api.saveVirtualHosts(virtualHosts);
        renderSidebarHosts();

        // Re-select the renamed host
        setTimeout(() => {
          const hostLink = document.querySelector(`.host-link[data-domain="${newDomain}"]`) as HTMLElement;
          if (hostLink) selectHost(newDomain, hostLink);
        }, 100);

        showToast(`Host renamed to ${newDomain}`, 'success');
      } catch (error) {
        console.error('Error renaming host:', error);
        showToast('Failed to rename host', 'error');
      }
    });
  }

  // Docroot editable input
  if (detailDocroot) {
    detailDocroot.value = host.docroot;
    // Remove previous listener
    const newDocroot = detailDocroot.cloneNode(true) as HTMLInputElement;
    detailDocroot.parentNode?.replaceChild(newDocroot, detailDocroot);

    // Save on change or blur
    const saveDocroot = async () => {
      const newValue = newDocroot.value.trim();
      if (newValue && newValue !== host.docroot) {
        await updateHostField(domain, 'docroot', newValue);
        showToast('Document root updated', 'success');
      }
    };

    newDocroot.addEventListener('change', saveDocroot);
    newDocroot.addEventListener('blur', saveDocroot);
  }

  // Group editable select - populate with all groups
  if (detailGroup) {
    const allGroups = new Set<string>();
    Object.values(virtualHosts).forEach(h => {
      allGroups.add(h.group || 'Uncategorized');
    });

    detailGroup.innerHTML = Array.from(allGroups).sort().map(g =>
      `<option value="${g}" ${g === (host.group || 'Uncategorized') ? 'selected' : ''}>${g}</option>`
    ).join('');

    // Remove previous listener
    const newGroup = detailGroup.cloneNode(true) as HTMLSelectElement;
    detailGroup.parentNode?.replaceChild(newGroup, detailGroup);

    newGroup.addEventListener('change', async () => {
      await updateHostField(domain, 'group', newGroup.value);
    });
  }

  if (detailStatus) {
    detailStatus.textContent = host.active ? 'Active' : 'Inactive';
    detailStatus.className = `badge ${host.active ? 'bg-success' : 'bg-secondary'}`;
  }

  // Set toggle state
  const activeToggle = document.getElementById('detail-active-toggle') as HTMLInputElement;
  if (activeToggle) {
    activeToggle.checked = host.active;
    // Remove previous listener if any
    const newToggle = activeToggle.cloneNode(true) as HTMLInputElement;
    activeToggle.parentNode?.replaceChild(newToggle, activeToggle);

    newToggle.addEventListener('change', async () => {
      await toggleHostActive(domain, newToggle.checked);
    });
  }

  if (detailSsl) {
    detailSsl.style.display = host.ssl ? 'inline-block' : 'none';
  }

  // === Development Server fields ===

  // Type select
  const detailType = document.getElementById('detail-type') as HTMLSelectElement;
  if (detailType) {
    const newType = detailType.cloneNode(true) as HTMLSelectElement;
    detailType.parentNode?.replaceChild(newType, detailType);
    newType.value = host.type || 'static';
    newType.addEventListener('change', () => updateHostField(domain, 'type', newType.value));
  }

  // Stack select
  const detailStack = document.getElementById('detail-stack') as HTMLSelectElement;
  if (detailStack) {
    const newStack = detailStack.cloneNode(true) as HTMLSelectElement;
    detailStack.parentNode?.replaceChild(newStack, detailStack);
    newStack.value = host.stack || 'frontend';
    newStack.addEventListener('change', () => updateHostField(domain, 'stack', newStack.value));
  }

  // Port input
  const detailPort = document.getElementById('detail-port') as HTMLInputElement;
  if (detailPort) {
    const newPort = detailPort.cloneNode(true) as HTMLInputElement;
    detailPort.parentNode?.replaceChild(newPort, detailPort);
    newPort.value = host.port ? String(host.port) : '';

    const savePort = () => {
      const val = newPort.value.trim();
      const portNum = val ? parseInt(val, 10) : null;
      updateHostField(domain, 'port', portNum);
    };
    newPort.addEventListener('change', savePort);
    newPort.addEventListener('blur', savePort);
  }

  // Clear port button
  const btnClearPort = document.getElementById('btn-clear-port');
  if (btnClearPort) {
    const newClearBtn = btnClearPort.cloneNode(true) as HTMLButtonElement;
    btnClearPort.parentNode?.replaceChild(newClearBtn, btnClearPort);
    newClearBtn.addEventListener('click', () => {
      const portInput = document.getElementById('detail-port') as HTMLInputElement;
      if (portInput) portInput.value = '';
      updateHostField(domain, 'port', null);
    });
  }

  // Dev Command - parse "npm run dev" into pkg="npm", cmd="run dev"
  const detailPkgManager = document.getElementById('detail-pkg-manager') as HTMLSelectElement;
  const detailDevCommand = document.getElementById('detail-dev-command') as HTMLInputElement;
  if (detailPkgManager && detailDevCommand) {
    const devCmd = host.dev_command || '';
    const parts = devCmd.split(/\s+/);
    const knownPkgManagers = ['npm', 'yarn', 'pnpm'];
    let pkg = 'npm';
    let cmd = devCmd;
    if (parts.length > 0 && knownPkgManagers.includes(parts[0])) {
      pkg = parts[0];
      cmd = parts.slice(1).join(' ');
    }

    const newPkg = detailPkgManager.cloneNode(true) as HTMLSelectElement;
    detailPkgManager.parentNode?.replaceChild(newPkg, detailPkgManager);
    newPkg.value = pkg;

    const newCmd = detailDevCommand.cloneNode(true) as HTMLInputElement;
    detailDevCommand.parentNode?.replaceChild(newCmd, detailDevCommand);
    newCmd.value = cmd;

    const saveDevCommand = () => {
      const cmdVal = newCmd.value.trim();
      const fullCmd = cmdVal ? `${newPkg.value} ${cmdVal}` : '';
      updateHostField(domain, 'dev_command', fullCmd);
    };

    newPkg.addEventListener('change', saveDevCommand);
    newCmd.addEventListener('change', saveDevCommand);
    newCmd.addEventListener('blur', saveDevCommand);
  }

  // Autostart toggle
  const detailAutostart = document.getElementById('detail-autostart') as HTMLInputElement;
  if (detailAutostart) {
    const newAutostart = detailAutostart.cloneNode(true) as HTMLInputElement;
    detailAutostart.parentNode?.replaceChild(newAutostart, detailAutostart);
    newAutostart.checked = host.autostart || false;
    newAutostart.addEventListener('change', () => updateHostField(domain, 'autostart', newAutostart.checked));
  }

  // Auto-detect dev command button
  const btnDetectCommand = document.getElementById('btn-detect-command');
  if (btnDetectCommand) {
    const newDetectBtn = btnDetectCommand.cloneNode(true) as HTMLButtonElement;
    btnDetectCommand.parentNode?.replaceChild(newDetectBtn, btnDetectCommand);
    newDetectBtn.addEventListener('click', async () => {
      try {
        const detected = await api.detectDevCommand(host.docroot);
        if (detected) {
          const parts = detected.split(/\s+/);
          const knownPkgManagers = ['npm', 'yarn', 'pnpm'];
          const pkgEl = document.getElementById('detail-pkg-manager') as HTMLSelectElement;
          const cmdEl = document.getElementById('detail-dev-command') as HTMLInputElement;
          if (pkgEl && cmdEl) {
            if (knownPkgManagers.includes(parts[0])) {
              pkgEl.value = parts[0];
              cmdEl.value = parts.slice(1).join(' ');
            } else {
              cmdEl.value = detected;
            }
            await updateHostField(domain, 'dev_command', detected);
          }
          showToast(`Detected: ${detected}`, 'success');
        } else {
          showToast('Could not detect dev command', 'warning');
        }
      } catch (error) {
        console.error('Error detecting dev command:', error);
        showToast('Failed to detect dev command', 'error');
      }
    });
  }

  // Start/Stop dev server button
  const btnStartDevserver = document.getElementById('btn-start-devserver');
  if (btnStartDevserver) {
    const newStartBtn = btnStartDevserver.cloneNode(true) as HTMLButtonElement;
    btnStartDevserver.parentNode?.replaceChild(newStartBtn, btnStartDevserver);
    newStartBtn.addEventListener('click', async () => {
      const pkgEl = document.getElementById('detail-pkg-manager') as HTMLSelectElement;
      const cmdEl = document.getElementById('detail-dev-command') as HTMLInputElement;
      const portEl = document.getElementById('detail-port') as HTMLInputElement;

      const fullCommand = pkgEl && cmdEl ? `${pkgEl.value} ${cmdEl.value}`.trim() : '';
      const port = portEl?.value ? parseInt(portEl.value, 10) : 3000;

      if (!fullCommand) {
        showToast('No dev command configured', 'warning');
        return;
      }

      try {
        const result = await api.startBackendService(domain, host.docroot, port, fullCommand);
        showToast(`Dev server started (PID: ${result.pid})`, 'success');
      } catch (error) {
        console.error('Error starting dev server:', error);
        showToast(`Failed to start dev server: ${error}`, 'error');
      }
    });
  }

  // Render aliases with remove buttons
  renderAliases(domain);
}

function renderAliases(domain: string) {
  const aliasesList = document.getElementById('detail-aliases');
  if (!aliasesList) return;

  const host = virtualHosts[domain];
  if (!host) return;

  if (host.aliases && host.aliases.length > 0) {
    aliasesList.innerHTML = host.aliases.map(alias => {
      const aliasValue = typeof alias === 'string' ? alias : (alias.value || '');
      const aliasId = typeof alias === 'string' ? alias : (alias.id || alias.value || '');

      return `
        <div class="d-inline-flex align-items-center gap-1 mb-1 me-1">
          <span class="badge" style="background-color: #e0e7ff; color: #3730a3; font-weight: 500;">${aliasValue}</span>
          <button class="btn btn-sm btn-ghost-danger p-0"
                  onclick="window.hostsManager.removeAlias('${domain}', '${aliasId}')"
                  style="width: 20px; height: 20px; line-height: 1;">
            <i class="ti ti-x" style="font-size: 12px;"></i>
          </button>
        </div>
      `;
    }).join('');
  } else {
    aliasesList.innerHTML = '<small class="text-muted">No aliases configured</small>';
  }
}

async function updateHostField(domain: string, field: string, value: any) {
  try {
    const host = virtualHosts[domain];
    if (!host) return;

    virtualHosts[domain] = { ...host, [field]: value };

    await api.saveVirtualHosts(virtualHosts);
    showToast(`${field} updated`, 'success');

    // Refresh sidebar if group changed
    if (field === 'group') {
      renderSidebarHosts();
      // Re-select the host after sidebar refresh
      setTimeout(() => {
        const hostLink = document.querySelector(`.host-link[data-domain="${domain}"]`) as HTMLElement;
        if (hostLink) selectHost(domain, hostLink);
      }, 100);
    }
  } catch (error) {
    console.error(`Error updating ${field}:`, error);
    showToast(`Failed to update ${field}`, 'error');
  }
}

async function toggleHostActive(domain: string, active: boolean) {
  try {
    const host = virtualHosts[domain];
    if (!host) return;

    host.active = active;

    // Aliases follow the parent: cascade the active state to all of them so the
    // stored data and the sidebar/panel chips stay consistent with the domain.
    if (Array.isArray(host.aliases)) {
      host.aliases = host.aliases.map((a: any) =>
        typeof a === 'string' ? a : { ...a, active }
      ) as any;
    }

    // Save to backend
    await api.saveVirtualHosts(virtualHosts);

    // Auto start/stop dev server if it's a backend project (macOS/Linux only;
    // Windows backend autostart is not wired yet).
    if (host.stack === 'backend' && !IS_WINDOWS) {
      const action = active ? 'start' : 'stop';
      const scriptPath = `${SCRIPTS_PATH}/manage-backend.sh`;

      try {
        const command = Command.create('bash', [scriptPath, action, domain]);
        const output = await command.execute();
        
        if (output.code === 0) {
          showToast(`Dev server ${active ? 'started' : 'stopped'} for ${domain}`, 'success');
        } else {
          console.error(`Failed to ${action} dev server:`, output.stderr);
        }
      } catch (err) {
        console.error(`Error managing dev server:`, err);
      }
    }

    // Update UI
    const detailStatus = document.getElementById('detail-status');
    if (detailStatus) {
      detailStatus.textContent = active ? 'Active' : 'Inactive';
      detailStatus.className = `badge ${active ? 'bg-success' : 'bg-secondary'}`;
    }

    // Update sidebar host status dot
    renderSidebarHosts();

    showToast(`Host ${active ? 'activated' : 'deactivated'}`, 'success');
    
    // Auto-regenerate Apache configs to reflect the change
    try {
      showToast('Updating configuration...', 'warning');

      // macOS/Linux: elevate once via sudo (Touch ID through pam_tid). Windows
      // (BETA): elevate via UAC and run the PowerShell hosts update.
      const applyCmd = IS_WINDOWS
        ? Command.create('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
            `Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','${SCRIPTS_PATH}\\windows\\update-hosts.ps1'`
          ])
        : Command.create('sh', ['-c',
            `sudo bash ${SCRIPTS_PATH}/apply-all-with-sudo.sh`
          ]);
      await applyCmd.execute();
      
      showToast('Configuration updated successfully!', 'success');
    } catch (err) {
      console.error('Error regenerating configs:', err);
      showToast('Failed to update configuration', 'error');
    }
  } catch (error) {
    console.error('Error toggling host:', error);
    showToast('Failed to update host status', 'error');
  }
}

export async function removeAlias(domain: string, aliasId: string) {
  try {
    const host = virtualHosts[domain];
    if (!host) return;

    // Remove alias by id or value
    host.aliases = host.aliases.filter((a: any) => {
      const id = typeof a === 'string' ? a : (a.id || a.value || '');
      return id !== aliasId;
    });

    await api.saveVirtualHosts(virtualHosts);

    renderAliases(domain);
    showToast('Alias removed successfully', 'success');
  } catch (error) {
    console.error('Error removing alias:', error);
    showToast('Failed to remove alias', 'error');
  }
}

export async function addAlias(domain: string) {
  // Set up the modal
  const modal = document.getElementById('addAliasModal');
  const input = document.getElementById('add-alias-input') as HTMLInputElement;
  const confirmBtn = document.getElementById('btn-confirm-add-alias');

  if (!modal || !input || !confirmBtn) {
    console.error('Add alias modal elements not found');
    return;
  }

  // Clear input
  input.value = '';

  // Show modal using Bootstrap
  const bootstrapModal = new (window as any).bootstrap.Modal(modal);
  bootstrapModal.show();

  // Focus on input after modal is shown
  modal.addEventListener('shown.bs.modal', () => {
    input.focus();
  }, { once: true });

  // Handle add confirmation
  const handleAdd = async () => {
    const aliasValue = input.value.trim();

    if (!aliasValue) {
      bootstrapModal.hide();
      return;
    }

    try {
      const host = virtualHosts[domain];
      if (!host) return;

      // Generate unique ID
      const newAlias = {
        id: `alias_${Math.random().toString(36).substr(2, 9)}`,
        value: aliasValue,
        active: true
      };

      if (!host.aliases) host.aliases = [];
      host.aliases.push(newAlias);

      await api.saveVirtualHosts(virtualHosts);

      renderAliases(domain);
      showToast('Alias added successfully. Remember to generate configs!', 'success');
    } catch (error) {
      console.error('Error adding alias:', error);
      showToast('Failed to add alias', 'error');
    }

    bootstrapModal.hide();
    confirmBtn.removeEventListener('click', handleAdd);
  };

  // Add event listener for confirm button
  confirmBtn.addEventListener('click', handleAdd, { once: true });

  // Handle Enter key in input
  const handleEnter = (e: KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAdd();
    }
  };
  input.addEventListener('keypress', handleEnter, { once: true });

  // Clean up event listeners when modal is hidden
  modal.addEventListener('hidden.bs.modal', () => {
    input.removeEventListener('keypress', handleEnter);
  }, { once: true });
}

export async function renameDomain() {
  if (!currentHost) {
    showToast('No host selected', 'warning');
    return;
  }

  const oldDomain = currentHost.domain;

  // Show rename modal
  const modalEl = document.getElementById('renameModal');
  const input = document.getElementById('rename-domain-input') as HTMLInputElement;
  const btnConfirm = document.getElementById('btn-confirm-rename');

  if (!modalEl || !input || !btnConfirm) {
    showToast('Rename modal not found', 'error');
    return;
  }

  // Set current value
  input.value = oldDomain;

  // Show modal
  const modal = new (window as any).bootstrap.Modal(modalEl);
  modal.show();

  // Focus input after modal is shown
  modalEl.addEventListener('shown.bs.modal', () => {
    input.focus();
    input.select();
  }, { once: true });

  // Handle confirm button
  const handleConfirm = async () => {
    const newDomain = input.value.trim();

    if (!newDomain || newDomain === oldDomain) {
      modal.hide();
      return;
    }

    // Check if new domain already exists
    if (virtualHosts[newDomain]) {
      showToast('Domain already exists', 'error');
      return;
    }

    try {
      // Copy host with new domain
      virtualHosts[newDomain] = { ...virtualHosts[oldDomain] };

      // Delete old domain
      delete virtualHosts[oldDomain];

      // Save changes
      await api.saveVirtualHosts(virtualHosts);

      modal.hide();
      showToast(`Domain renamed to "${newDomain}". Remember to generate configs!`, 'success');

      // Refresh sidebar and select new host
      renderSidebarHosts();
      setTimeout(() => {
        const hostLink = document.querySelector(`.host-link[data-domain="${newDomain}"]`) as HTMLElement;
        if (hostLink) selectHost(newDomain, hostLink);
      }, 100);
    } catch (error) {
      console.error('Error renaming domain:', error);
      showToast('Failed to rename domain', 'error');
    }
  };

  // Remove previous listeners and add new one
  const newBtn = btnConfirm.cloneNode(true) as HTMLButtonElement;
  btnConfirm.parentNode?.replaceChild(newBtn, btnConfirm);
  newBtn.addEventListener('click', handleConfirm);

  // Handle Enter key
  const handleEnter = (e: KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleConfirm();
    }
  };
  input.addEventListener('keypress', handleEnter);

  // Cleanup on modal hide
  modalEl.addEventListener('hidden.bs.modal', () => {
    input.removeEventListener('keypress', handleEnter);
  }, { once: true });
}

export async function deleteCurrentHost() {
  if (!currentHost) {
    showToast('No host selected', 'warning');
    return;
  }

  const domain = currentHost.domain;

  const confirmed = await ask(`Are you sure you want to delete "${domain}"? This action cannot be undone.`, {
    title: 'Delete Host',
    kind: 'warning'
  });

  if (!confirmed) {
    return;
  }

  try {
    // Delete from local state
    delete virtualHosts[domain];

    // Save changes
    await api.saveVirtualHosts(virtualHosts);

    // Also delete from backend
    await api.deleteHost(domain);

    showToast(`Host "${domain}" deleted. Remember to generate configs!`, 'success');

    // Hide host details and show empty state
    const emptyState = document.getElementById('emptyState');
    const hostDetails = document.getElementById('hostDetails');
    const hostActions = document.getElementById('hostActions');

    if (emptyState) emptyState.classList.remove('d-none');
    if (hostDetails) hostDetails.classList.add('d-none');
    if (hostActions) hostActions.style.display = 'none';

    currentHost = null;

    // Refresh sidebar
    renderSidebarHosts();
  } catch (error) {
    console.error('Error deleting host:', error);
    showToast('Failed to delete host', 'error');
  }
}

export function getCurrentHost() {
  return currentHost;
}

export async function openCurrentHost() {
  if (!currentHost) {
    showToast('No host selected', 'warning');
    return;
  }

  const protocol = currentHost.ssl ? 'https://' : 'http://';
  const url = `${protocol}${currentHost.domain}`;

  try {
    await openUrl(url);
    showToast(`Opening ${currentHost.domain}...`, 'success');
  } catch (error) {
    console.error('Error opening URL:', error);
    showToast('Failed to open host in browser', 'error');
  }
}

function updateServicesUI() {
  const apacheLed = document.getElementById('led-apache');
  const mysqlLed = document.getElementById('led-mysql');
  const phpLed = document.getElementById('led-php');

  if (apacheLed) {
    apacheLed.className = `service-led ${servicesStatus.apache ? 'on' : ''}`;
  }

  if (mysqlLed) {
    mysqlLed.className = `service-led ${servicesStatus.mysql ? 'on' : ''}`;
  }

  if (phpLed) {
    phpLed.className = `service-led ${servicesStatus.php ? 'on' : ''}`;
  }

  // Update toggle button
  const toggleBtn = document.getElementById('toggleServersBtn');
  if (toggleBtn) {
    if (servicesStatus.all_running) {
      toggleBtn.className = 'btn btn-sm btn-icon btn-danger';
      toggleBtn.title = 'Stop Services';
    } else {
      toggleBtn.className = 'btn btn-sm btn-icon btn-success';
      toggleBtn.title = 'Start Services';
    }
  }
}

export async function executeApacheCommand(action: ApacheAction) {
  try {
    // macOS/Linux: bash <action>-apache-native.sh. Windows (BETA): the
    // matching PowerShell script under scripts/windows/.
    const command = IS_WINDOWS
      ? Command.create('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', `${SCRIPTS_PATH}\\windows\\${action}-apache.ps1`])
      : Command.create('bash', [`${SCRIPTS_PATH}/${action}-apache-native.sh`]);

    const actionVerb = action.charAt(0).toUpperCase() + action.slice(1);
    showToast(`${actionVerb}ing Apache...`, 'warning');

    const output = await command.execute();

    if (output.code === 0) {
      showToast(`Apache ${action}ed successfully`, 'success');
      // Reload services status after a delay
      setTimeout(() => loadServicesStatus(), 2000);
    } else {
      showToast(`Failed to ${action} Apache`, 'error');
    }
  } catch (error) {
    console.error(`Error ${action}ing Apache:`, error);
    showToast(`Failed to ${action} Apache`, 'error');
  }
}

export async function generateConfigs() {
  try {
    showToast('Applying configuration (Touch ID)…', 'warning');

    // Centralized elevation: one privileged run (Touch ID via sudo/pam_tid on
    // macOS) that regenerates certs + vhosts AND applies /etc/hosts + Apache --
    // exactly the same path used when toggling a host, so there is a single prompt.
    const command = IS_WINDOWS
      ? Command.create('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
          `Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','${SCRIPTS_PATH}\\windows\\update-hosts.ps1'`
        ])
      : Command.create('sh', ['-c',
          `sudo bash ${SCRIPTS_PATH}/apply-all-with-sudo.sh`
        ]);
    const output = await command.execute();

    if (output.code === 0) {
      showToast('Configuration applied successfully!', 'success');
    } else {
      showToast('Configuration finished with warnings', 'warning');
      console.error('apply stderr:', output.stderr);
    }

    // Reload hosts and services after applying
    await loadVirtualHosts();
    await loadServicesStatus();
  } catch (error) {
    console.error('Error applying configuration:', error);
    showToast(`Apply failed: ${error}`, 'error');
  }
}

export async function toggleServices() {
  const action = servicesStatus.all_running ? 'stop' : 'start';

  try {
    showToast(`${action === 'start' ? 'Starting' : 'Stopping'} services...`, 'warning');

    let services: string[] = [];

    if (action === 'stop') {
      // For stop: only get currently running services
      const detectCmd = Command.create('sh', ['-c', '/opt/homebrew/bin/brew services list | grep -E "httpd|mysql|php" | grep "started" | awk \'{print $1}\'']);
      const detectOutput = await detectCmd.execute();
      if (detectOutput.code === 0 && detectOutput.stdout) {
        services = detectOutput.stdout.trim().split('\n').filter(s => s);
      }
    } else {
      // For start: get services that are stopped (none status) - prefer versioned ones
      const detectCmd = Command.create('sh', ['-c', '/opt/homebrew/bin/brew services list | grep -E "httpd|mysql@|php@" | grep "none" | awk \'{print $1}\' | sort -r']);
      const detectOutput = await detectCmd.execute();
      if (detectOutput.code === 0 && detectOutput.stdout) {
        const all = detectOutput.stdout.trim().split('\n').filter(s => s);
        // Pick one mysql and one php (highest version due to sort -r)
        const mysql = all.find(s => s.startsWith('mysql@'));
        const php = all.find(s => s.startsWith('php@'));
        const httpd = all.find(s => s === 'httpd');
        if (mysql) services.push(mysql);
        if (php) services.push(php);
        if (httpd) services.push(httpd);
      }
      // Fallback defaults if nothing detected
      if (services.length === 0) {
        services = ['mysql@8.4', 'php@8.3'];
      }
    }

    if (services.length === 0) {
      showToast('No services to toggle', 'warning');
      return;
    }

    // Build command with detected services
    const serviceCommands = services.map(s => `/opt/homebrew/bin/brew services ${action} ${s}`).join(' && ');
    const command = Command.create('sh', ['-c', serviceCommands]);
    const output = await command.execute();

    if (output.code === 0) {
      showToast('Services toggled successfully', 'success');
      setTimeout(() => loadServicesStatus(), 2000);
    } else {
      showToast(`Failed to toggle services: ${output.stderr}`, 'error');
    }
  } catch (error) {
    console.error('Error toggling services:', error);
    showToast('Failed to toggle services', 'error');
  }
}

// Poll services status every 5 seconds
export function startServicesPolling() {
  loadServicesStatus();
  setInterval(loadServicesStatus, 5000);
}

export function showAddHostModal() {
  // Get modal element
  const modalElement = document.getElementById('host-modal');
  if (!modalElement) return;

  // Reset modal title and form
  const modalTitle = document.getElementById('host-modal-title');
  if (modalTitle) modalTitle.textContent = 'Add Virtual Host';

  // Clear form fields
  (document.getElementById('modal-domain') as HTMLInputElement).value = '';
  (document.getElementById('modal-docroot') as HTMLInputElement).value = '';
  (document.getElementById('modal-group') as HTMLInputElement).value = '';
  (document.getElementById('modal-type') as HTMLSelectElement).value = 'php';
  (document.getElementById('modal-active') as HTMLInputElement).checked = true;
  (document.getElementById('modal-ssl') as HTMLInputElement).checked = true;
  (document.getElementById('modal-aliases') as HTMLTextAreaElement).value = '';

  // Show modal using Bootstrap
  const modal = new (window as any).bootstrap.Modal(modalElement);
  modal.show();

  // Set up save handler
  const saveBtn = document.getElementById('btn-save-host');
  if (saveBtn) {
    // Remove previous listeners
    const newSaveBtn = saveBtn.cloneNode(true);
    saveBtn.parentNode?.replaceChild(newSaveBtn, saveBtn);

    // Add new listener
    newSaveBtn.addEventListener('click', () => saveHost(modal));
  }
}

async function saveHost(modal: any) {
  const domain = (document.getElementById('modal-domain') as HTMLInputElement).value.trim();
  const docroot = (document.getElementById('modal-docroot') as HTMLInputElement).value.trim();
  const group = (document.getElementById('modal-group') as HTMLInputElement).value.trim() || 'Uncategorized';
  const type = (document.getElementById('modal-type') as HTMLSelectElement).value;
  const active = (document.getElementById('modal-active') as HTMLInputElement).checked;
  const ssl = (document.getElementById('modal-ssl') as HTMLInputElement).checked;
  const aliasesText = (document.getElementById('modal-aliases') as HTMLTextAreaElement).value.trim();

  // Validation
  if (!domain) {
    showToast('Domain is required', 'error');
    return;
  }

  if (!docroot) {
    showToast('Document root is required', 'error');
    return;
  }

  // Parse aliases
  const aliases = aliasesText
    .split('\n')
    .map(a => a.trim())
    .filter(a => a.length > 0)
    .map(value => ({ value }));

  // Create host object
  const newHost: VirtualHost = {
    domain,
    docroot,
    group,
    type,
    active,
    ssl,
    aliases: aliases.length > 0 ? aliases as any : []
  };

  try {
    // TODO: Call Tauri backend to save host
    // For now, add to local state
    virtualHosts[domain] = newHost;

    showToast('Host added successfully. Remember to generate configs!', 'success');
    modal.hide();

    // Re-render sidebar
    renderSidebarHosts();
  } catch (error) {
    console.error('Error saving host:', error);
    showToast('Failed to save host', 'error');
  }
}

export function showAddGroupDialog() {
  // Set up the modal
  const modal = document.getElementById('addGroupModal');
  const input = document.getElementById('add-group-input') as HTMLInputElement;
  const confirmBtn = document.getElementById('btn-confirm-add-group');

  if (!modal || !input || !confirmBtn) {
    console.error('Add group modal elements not found');
    return;
  }

  // Clear input
  input.value = '';

  // Show modal using Bootstrap
  const bootstrapModal = new (window as any).bootstrap.Modal(modal);
  bootstrapModal.show();

  // Focus on input after modal is shown
  modal.addEventListener('shown.bs.modal', () => {
    input.focus();
  }, { once: true });

  // Handle add confirmation
  const handleAdd = async () => {
    const groupName = input.value.trim();

    if (!groupName) {
      bootstrapModal.hide();
      return;
    }

    // Check if group already exists
    const existingGroups = new Set<string>();
    for (const host of Object.values(virtualHosts)) {
      existingGroups.add(host.group || 'Uncategorized');
    }

    if (existingGroups.has(groupName)) {
      showToast('Group already exists', 'warning');
      bootstrapModal.hide();
      return;
    }

    // Create a placeholder host for the new group (will be removed when user adds real hosts)
    // Or just show success message
    showToast(`Group "${groupName}" created. Add hosts to this group using the Add Host button.`, 'success');

    bootstrapModal.hide();
    // Clean up
    confirmBtn.removeEventListener('click', handleAdd);
  };

  // Add event listener for confirm button
  confirmBtn.addEventListener('click', handleAdd, { once: true });

  // Handle Enter key in input
  const handleEnter = (e: KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAdd();
    }
  };
  input.addEventListener('keypress', handleEnter, { once: true });

  // Clean up event listeners when modal is hidden
  modal.addEventListener('hidden.bs.modal', () => {
    input.removeEventListener('keypress', handleEnter);
  }, { once: true });
}

export function onStackChanged(stackKey: string) {
  const stack = STACK_CONFIGS[stackKey];
  if (!stack) {
    showToast('Invalid stack selected', 'error');
    return;
  }

  // currentStack = stack;
  showToast(`Switched to ${stack.name}`, 'success');

  // TODO: Detect if stack is actually installed
  // TODO: Update service commands to use new stack
  // TODO: Auto-detect installed PHP/Apache/MySQL versions for this stack

  console.log('Stack changed to:', stack);
  console.log('Apache path:', stack.apachePath);
  console.log('PHP path:', stack.phpPath);
  console.log('MySQL path:', stack.mysqlPath);
}

// Auto-detect stack on load
export function detectInstalledStack(): string {
  // This will be called from Rust backend
  // For now, return saved preference or default
  return localStorage.getItem('serverStack') || 'native';
}

// ============================================
// Browse Folder Functions
// ============================================

export async function browseDocrootFolder() {
  try {
    const selected = await openDialog({
      directory: true,
      multiple: false,
      title: 'Select Document Root Folder'
    });

    if (selected && typeof selected === 'string') {
      const docrootInput = document.getElementById('detail-docroot') as HTMLInputElement;
      if (docrootInput && currentHost) {
        docrootInput.value = selected;
        // Trigger change event to auto-save
        await updateHostField(currentHost.domain, 'docroot', selected);
      }
    }
  } catch (error) {
    console.error('Error browsing folder:', error);
    showToast('Failed to open folder browser', 'error');
  }
}

export async function browseModalDocrootFolder() {
  try {
    const selected = await openDialog({
      directory: true,
      multiple: false,
      title: 'Select Document Root Folder'
    });

    if (selected && typeof selected === 'string') {
      const docrootInput = document.getElementById('modal-docroot') as HTMLInputElement;
      if (docrootInput) {
        docrootInput.value = selected;
      }
    }
  } catch (error) {
    console.error('Error browsing folder:', error);
    showToast('Failed to open folder browser', 'error');
  }
}

// ============================================
// Drag & Drop Functionality
// ============================================

function initializeDragDrop() {
  console.log('[DragDrop] Initializing drag & drop...');
  console.log('[DragDrop] Sortable available:', typeof Sortable !== 'undefined');

  // Initialize drag & drop for individual hosts between groups
  const groupItems = document.querySelectorAll('.nav-group-items');
  console.log(`[DragDrop] Found ${groupItems.length} group containers`);

  groupItems.forEach((groupElement, index) => {
    console.log(`[DragDrop] Setting up Sortable for group ${index}`);
    new Sortable(groupElement as HTMLElement, {
      group: 'hosts',
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      draggable: '.host-link',
      forceFallback: true,  // FORCE fallback mode for reliability
      fallbackTolerance: 3,
      fallbackOnBody: true,
      swapThreshold: 0.65,
      removeCloneOnHide: true,
      direction: 'vertical',
      scroll: true,
      scrollSensitivity: 30,
      scrollSpeed: 10,
      bubbleScroll: true,
      onStart: (evt: Sortable.SortableEvent) => {
        console.log('[DragDrop] Started dragging item');
        console.log('[DragDrop] Item:', evt.item);
      },
      onEnd: async (evt: Sortable.SortableEvent) => {
        console.log('[DragDrop] Drop event triggered');
        console.log('[DragDrop] From:', evt.from);
        console.log('[DragDrop] To:', evt.to);

        // Get domain from the dragged element
        const draggedLink = evt.item as HTMLElement;
        const domain = draggedLink.getAttribute('data-domain');

        console.log('[DragDrop] Dragged domain:', domain);

        if (!domain) {
          console.error('[DragDrop] No domain found on dragged element');
          return;
        }

        // Find the new group by looking at the parent container
        const newGroupElement = evt.to.closest('.nav-group');
        console.log('[DragDrop] New group element:', newGroupElement);

        if (!newGroupElement) {
          console.error('[DragDrop] ERROR: New group element not found');
          console.error('[DragDrop] evt.to:', evt.to);
          console.error('[DragDrop] evt.to.parentElement:', evt.to.parentElement);
          renderSidebarHosts();
          return;
        }

        const newGroupTitle = newGroupElement.querySelector('.group-name');
        console.log('[DragDrop] New group title element:', newGroupTitle);

        if (!newGroupTitle) {
          console.error('[DragDrop] ERROR: New group title not found');
          console.error('[DragDrop] newGroupElement HTML:', newGroupElement.innerHTML.substring(0, 200));
          renderSidebarHosts();
          return;
        }

        const newGroup = newGroupTitle.textContent?.trim() || 'Uncategorized';
        console.log('[DragDrop] Target group name:', newGroup);

        // Check if group actually changed
        const host = virtualHosts[domain];
        if (!host) {
          console.error('Host not found:', domain);
          renderSidebarHosts();
          return;
        }

        const oldGroup = host.group || 'Uncategorized';

        // If moved to a different group, update the host
        if (oldGroup !== newGroup) {
          try {
            await updateHostField(domain, 'group', newGroup);
            showToast(`${domain} moved to ${newGroup}`, 'success');
          } catch (error) {
            console.error('Error moving host:', error);
            showToast('Failed to move host', 'error');
            // Refresh to revert
            renderSidebarHosts();
            return;
          }
        }

        // Save the new order of hosts within the group
        const groupHosts = evt.to.querySelectorAll('.host-link');
        const hostOrder: string[] = [];
        groupHosts.forEach((link) => {
          const hostDomain = (link as HTMLElement).getAttribute('data-domain');
          if (hostDomain) {
            hostOrder.push(hostDomain);
          }
        });

        // Save to localStorage
        const hostOrderKey = `hostOrder_${newGroup}`;
        localStorage.setItem(hostOrderKey, JSON.stringify(hostOrder));

        if (oldGroup === newGroup) {
          showToast(`Reordered hosts in ${newGroup}`, 'success');
        }
      }
    });
  });

  // Initialize drag & drop for reordering entire groups/folders
  const groupList = document.getElementById('group-list');
  console.log('[DragDrop] Group list element:', groupList);

  if (groupList) {
    console.log('[DragDrop] Setting up group reordering');
    const groupCount = groupList.querySelectorAll('.nav-group').length;
    console.log(`[DragDrop] Found ${groupCount} groups to reorder`);

    new Sortable(groupList as HTMLElement, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      draggable: '.nav-group',
      handle: '.nav-group-title', // Only drag when grabbing the title area
      filter: '.group-edit-btn', // Don't start drag when clicking edit button
      preventOnFilter: false,
      onEnd: (_evt: Sortable.SortableEvent) => {
        // Save the new group order to localStorage
        const groupElements = groupList.querySelectorAll('.nav-group');
        const groupOrder: string[] = [];

        groupElements.forEach((element) => {
          const groupName = element.querySelector('.group-name')?.textContent?.trim();
          if (groupName) {
            groupOrder.push(groupName);
          }
        });

        localStorage.setItem('groupOrder', JSON.stringify(groupOrder));
        showToast('Group order saved', 'success');
      }
    });
  }
}
