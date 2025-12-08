// ============================================
// Setup Wizard - First Run Configuration
// ============================================

import { open as openDialog } from '@tauri-apps/plugin-dialog';
import { invoke } from '@tauri-apps/api/core';
import * as api from './api';

interface SetupConfig {
  stack: string;
  projectsPath: string;
  configPath: string;
  sslPath: string;
  importHostsPath?: string;
}

interface HostEntry {
  id: string;
  host: string;
  path: string;
  ssl?: boolean;
  [key: string]: unknown;
}

let importedHosts: HostEntry[] = [];

interface DetectedStack {
  name: string;
  value: string;
  detected: boolean;
}

let currentStep = 1;
const totalSteps = 5;
let wizardModal: any = null;
let isInstalling = false;

// Check if this is the first run
export async function checkFirstRun(): Promise<boolean> {
  const hasCompletedSetup = localStorage.getItem('setupCompleted');
  return !hasCompletedSetup;
}

// Initialize and show the wizard
export async function initSetupWizard() {
  const isFirstRun = await checkFirstRun();

  if (!isFirstRun) {
    return;
  }

  // Show wizard modal
  const modalElement = document.getElementById('setupWizardModal');
  if (!modalElement) {
    console.error('Setup wizard modal not found');
    return;
  }

  wizardModal = new (window as any).bootstrap.Modal(modalElement);
  wizardModal.show();

  // Initialize event listeners
  initWizardListeners();

  // Set default paths
  await setDefaultPaths();
}

function initWizardListeners() {
  const nextBtn = document.getElementById('wizard-btn-next');
  const backBtn = document.getElementById('wizard-btn-back');

  nextBtn?.addEventListener('click', handleNext);
  backBtn?.addEventListener('click', handleBack);

  // Browse buttons
  document.getElementById('btn-browse-projects')?.addEventListener('click', () => browseFolder('setup-projects-path'));
  document.getElementById('btn-browse-config')?.addEventListener('click', () => browseFolder('setup-config-path'));
  document.getElementById('btn-browse-ssl')?.addEventListener('click', () => browseFolder('setup-ssl-path'));

  // Import hosts toggle and browse
  const importCheckbox = document.getElementById('setup-import-hosts') as HTMLInputElement;
  const importSection = document.getElementById('import-hosts-section');

  importCheckbox?.addEventListener('change', () => {
    if (importSection) {
      importSection.classList.toggle('d-none', !importCheckbox.checked);
    }
    if (!importCheckbox.checked) {
      importedHosts = [];
      const importPath = document.getElementById('setup-import-path') as HTMLInputElement;
      const importPreview = document.getElementById('import-preview');
      if (importPath) importPath.value = '';
      if (importPreview) importPreview.classList.add('d-none');
    }
  });

  document.getElementById('btn-browse-import')?.addEventListener('click', browseHostsFile);
}

async function setDefaultPaths() {
  try {
    const homeDir = await api.getHomeDirectory();
    const isWin = navigator.platform.toLowerCase().includes('win');
    const sep = isWin ? '\\' : '/';

    const projectsInput = document.getElementById('setup-projects-path') as HTMLInputElement;
    const configInput = document.getElementById('setup-config-path') as HTMLInputElement;
    const sslInput = document.getElementById('setup-ssl-path') as HTMLInputElement;

    if (projectsInput) {
      projectsInput.value = isWin
        ? `${homeDir}${sep}Sites`
        : `${homeDir}/Sites`;
    }

    if (configInput) {
      configInput.value = `${homeDir}${sep}localhost-manager`;
    }

    if (sslInput) {
      sslInput.value = `${homeDir}${sep}localhost-manager${sep}ssl`;
    }
  } catch (error) {
    console.error('Error setting default paths:', error);
  }
}

async function handleNext() {
  if (currentStep === 2) {
    // Save selected stack
    const selectedStack = document.querySelector('input[name="stack"]:checked') as HTMLInputElement;
    if (selectedStack) {
      localStorage.setItem('serverStack', selectedStack.value);
    }
  }

  // Step 3: Install components if any selected
  if (currentStep === 3) {
    await installSelectedComponents();
    if (isInstalling) {
      return; // Don't proceed while installing
    }
  }

  if (currentStep === totalSteps) {
    // Finish setup
    await completeSetup();
    return;
  }

  currentStep++;
  updateWizardUI();

  // Trigger step-specific actions
  if (currentStep === 2) {
    detectInstalledStacks();
  } else if (currentStep === 3) {
    checkInstalledComponents();
  } else if (currentStep === 5) {
    runSetup();
  }
}

function handleBack() {
  if (currentStep > 1) {
    currentStep--;
    updateWizardUI();
  }
}

function updateWizardUI() {
  // Update step visibility
  for (let i = 1; i <= totalSteps; i++) {
    const stepContent = document.getElementById(`wizard-step-${i}`);
    if (stepContent) {
      stepContent.classList.toggle('d-none', i !== currentStep);
    }

    // Update step indicators
    const stepIndicator = document.querySelector(`.wizard-step[data-step="${i}"]`);
    if (stepIndicator) {
      stepIndicator.classList.toggle('active', i <= currentStep);
      stepIndicator.classList.toggle('completed', i < currentStep);
    }
  }

  // Update progress bar
  const progressBar = document.getElementById('wizard-progress-bar');
  if (progressBar) {
    progressBar.style.width = `${(currentStep / totalSteps) * 100}%`;
  }

  // Update buttons
  const backBtn = document.getElementById('wizard-btn-back') as HTMLButtonElement;
  const nextBtn = document.getElementById('wizard-btn-next');

  if (backBtn) {
    backBtn.disabled = currentStep === 1;
  }

  if (nextBtn) {
    if (currentStep === totalSteps) {
      nextBtn.innerHTML = 'Finish <i class="ti ti-check ms-1"></i>';
    } else {
      nextBtn.innerHTML = 'Next <i class="ti ti-arrow-right ms-1"></i>';
    }
  }

  // Update title
  const titles = ['Welcome to Localhost Manager', 'Select Platform', 'Install Components', 'Configure Paths', 'Setup'];
  const titleEl = document.getElementById('wizard-title');
  if (titleEl) {
    titleEl.textContent = titles[currentStep - 1];
  }
}

// ============================================
// Component Installation Functions
// ============================================

async function checkInstalledComponents() {
  const statusEl = document.getElementById('wizard-components-status');
  const packages = ['apache', 'mysql', 'php'];

  if (statusEl) {
    statusEl.innerHTML = `
      <div class="d-flex align-items-center text-muted">
        <div class="spinner-border spinner-border-sm me-2"></div>
        Checking installed components...
      </div>
    `;
  }

  let allInstalled = true;
  let installedCount = 0;

  for (const pkg of packages) {
    const statusBadge = document.getElementById(`wizard-${pkg}-status`);
    const checkbox = document.getElementById(`wizard-install-${pkg}`) as HTMLInputElement;

    try {
      const installed = await invoke<boolean>('check_package_installed', { package: pkg });

      if (statusBadge) {
        if (installed) {
          statusBadge.textContent = 'Installed';
          statusBadge.className = 'badge bg-success me-2';
          installedCount++;
        } else {
          statusBadge.textContent = 'Not Installed';
          statusBadge.className = 'badge bg-secondary me-2';
          allInstalled = false;
        }
      }

      if (checkbox) {
        checkbox.checked = !installed; // Auto-check if not installed
        checkbox.disabled = installed; // Disable if already installed
      }
    } catch (error) {
      console.error(`Failed to check ${pkg}:`, error);
      if (statusBadge) {
        statusBadge.textContent = 'Unknown';
        statusBadge.className = 'badge bg-warning me-2';
      }
    }
  }

  if (statusEl) {
    if (allInstalled) {
      statusEl.innerHTML = `
        <div class="alert alert-success">
          <i class="ti ti-check me-2"></i>
          All components are already installed! You can skip this step.
        </div>
      `;
    } else {
      statusEl.innerHTML = `
        <div class="alert alert-info">
          <i class="ti ti-info-circle me-2"></i>
          ${installedCount}/3 components installed. Toggle switches to install missing components.
        </div>
      `;
    }
  }
}

async function installSelectedComponents(): Promise<boolean> {
  const apacheCheckbox = document.getElementById('wizard-install-apache') as HTMLInputElement;
  const mysqlCheckbox = document.getElementById('wizard-install-mysql') as HTMLInputElement;
  const phpCheckbox = document.getElementById('wizard-install-php') as HTMLInputElement;
  const phpVersionSelect = document.getElementById('wizard-php-version') as HTMLSelectElement;

  const toInstall: { name: string; version?: string }[] = [];

  if (apacheCheckbox?.checked && !apacheCheckbox.disabled) {
    toInstall.push({ name: 'apache' });
  }
  if (mysqlCheckbox?.checked && !mysqlCheckbox.disabled) {
    toInstall.push({ name: 'mysql' });
  }
  if (phpCheckbox?.checked && !phpCheckbox.disabled) {
    toInstall.push({ name: 'php', version: phpVersionSelect?.value || '8.3' });
  }

  if (toInstall.length === 0) {
    return false; // Nothing to install
  }

  // Show installation progress
  isInstalling = true;
  const progressDiv = document.getElementById('wizard-install-progress');
  const statusEl = document.getElementById('wizard-install-status');
  const logEl = document.getElementById('wizard-install-log');
  const nextBtn = document.getElementById('wizard-btn-next') as HTMLButtonElement;
  const backBtn = document.getElementById('wizard-btn-back') as HTMLButtonElement;

  if (progressDiv) progressDiv.classList.remove('d-none');
  if (nextBtn) nextBtn.disabled = true;
  if (backBtn) backBtn.disabled = true;
  if (logEl) logEl.textContent = '';

  try {
    for (const pkg of toInstall) {
      if (statusEl) statusEl.textContent = `Installing ${pkg.name}...`;
      if (logEl) logEl.textContent += `\n[*] Installing ${pkg.name}...\n`;

      try {
        const result = await invoke<string>('install_package', {
          package: pkg.name,
          version: pkg.version || ''
        });

        if (logEl) logEl.textContent += result + '\n';
        if (logEl) logEl.textContent += `[OK] ${pkg.name} installed successfully\n`;

        // Update status badge
        const statusBadge = document.getElementById(`wizard-${pkg.name}-status`);
        const checkbox = document.getElementById(`wizard-install-${pkg.name}`) as HTMLInputElement;
        if (statusBadge) {
          statusBadge.textContent = 'Installed';
          statusBadge.className = 'badge bg-success me-2';
        }
        if (checkbox) {
          checkbox.checked = false;
          checkbox.disabled = true;
        }
      } catch (error) {
        if (logEl) logEl.textContent += `[ERROR] Failed to install ${pkg.name}: ${error}\n`;
      }
    }

    if (statusEl) statusEl.textContent = 'Installation complete!';
    await sleep(1000);

  } finally {
    isInstalling = false;
    if (nextBtn) nextBtn.disabled = false;
    if (backBtn) backBtn.disabled = false;
    if (progressDiv) progressDiv.classList.add('d-none');
  }

  return true;
}

async function detectInstalledStacks() {
  const detectedDiv = document.getElementById('detected-stacks');
  if (!detectedDiv) return;

  try {
    const detected = await api.detectInstalledStacks();

    if (detected && detected.length > 0) {
      const detectedNames = detected.filter((s: DetectedStack) => s.detected).map((s: DetectedStack) => s.name);

      if (detectedNames.length > 0) {
        detectedDiv.innerHTML = `
          <div class="alert alert-success">
            <i class="ti ti-check me-2"></i>
            Detected: <strong>${detectedNames.join(', ')}</strong>
          </div>
        `;

        // Auto-select first detected stack
        const firstDetected = detected.find((s: DetectedStack) => s.detected);
        if (firstDetected) {
          const radio = document.querySelector(`input[name="stack"][value="${firstDetected.value}"]`) as HTMLInputElement;
          if (radio) {
            radio.checked = true;
          }
        }
      } else {
        detectedDiv.innerHTML = `
          <div class="alert alert-warning">
            <i class="ti ti-alert-triangle me-2"></i>
            No development stacks detected. Please select one manually.
          </div>
        `;
      }
    }
  } catch (error) {
    console.error('Error detecting stacks:', error);
    detectedDiv.innerHTML = `
      <div class="alert alert-info">
        <i class="ti ti-info-circle me-2"></i>
        Could not auto-detect. Please select your stack manually.
      </div>
    `;
  }
}

async function browseFolder(inputId: string) {
  try {
    const selected = await openDialog({
      directory: true,
      multiple: false,
      title: 'Select Folder'
    });

    if (selected && typeof selected === 'string') {
      const input = document.getElementById(inputId) as HTMLInputElement;
      if (input) {
        input.value = selected;
      }
    }
  } catch (error) {
    console.error('Error browsing folder:', error);
  }
}

async function browseHostsFile() {
  try {
    const selected = await openDialog({
      directory: false,
      multiple: false,
      title: 'Select hosts.json file',
      filters: [{
        name: 'JSON Files',
        extensions: ['json']
      }]
    });

    if (selected && typeof selected === 'string') {
      const importPath = document.getElementById('setup-import-path') as HTMLInputElement;
      const importPreview = document.getElementById('import-preview');
      const importPreviewText = document.getElementById('import-preview-text');

      if (importPath) {
        importPath.value = selected;
      }

      // Try to read and validate the file
      try {
        const content = await api.readFile(selected);
        const data = JSON.parse(content);

        // Validate structure
        if (Array.isArray(data)) {
          importedHosts = data as HostEntry[];
        } else if (data.hosts && Array.isArray(data.hosts)) {
          importedHosts = data.hosts as HostEntry[];
        } else {
          throw new Error('Invalid hosts.json format');
        }

        const hostCount = importedHosts.length;
        const sslCount = importedHosts.filter(h => h.ssl).length;

        if (importPreview && importPreviewText) {
          importPreview.classList.remove('d-none');
          importPreview.querySelector('.alert')?.classList.remove('alert-danger');
          importPreview.querySelector('.alert')?.classList.add('alert-success');
          importPreviewText.innerHTML = `Found <strong>${hostCount} hosts</strong> (${sslCount} with SSL)`;
        }
      } catch (parseError) {
        importedHosts = [];
        if (importPreview && importPreviewText) {
          importPreview.classList.remove('d-none');
          importPreview.querySelector('.alert')?.classList.remove('alert-success');
          importPreview.querySelector('.alert')?.classList.add('alert-danger');
          importPreviewText.innerHTML = `<i class="ti ti-alert-circle me-1"></i>Invalid file: ${parseError}`;
        }
      }
    }
  } catch (error) {
    console.error('Error browsing hosts file:', error);
  }
}

async function runSetup() {
  const statusEl = document.getElementById('setup-status');
  const progressDiv = document.getElementById('setup-in-progress');
  const completeDiv = document.getElementById('setup-complete');
  const nextBtn = document.getElementById('wizard-btn-next') as HTMLButtonElement;
  const backBtn = document.getElementById('wizard-btn-back') as HTMLButtonElement;

  // Disable buttons during setup
  if (nextBtn) nextBtn.disabled = true;
  if (backBtn) backBtn.disabled = true;

  const config: SetupConfig = {
    stack: (document.querySelector('input[name="stack"]:checked') as HTMLInputElement)?.value || 'native',
    projectsPath: (document.getElementById('setup-projects-path') as HTMLInputElement)?.value || '',
    configPath: (document.getElementById('setup-config-path') as HTMLInputElement)?.value || '',
    sslPath: (document.getElementById('setup-ssl-path') as HTMLInputElement)?.value || ''
  };

  try {
    // Step 1: Create directories
    if (statusEl) statusEl.textContent = 'Creating directories...';
    await api.setupDirectories(config.configPath, config.sslPath, config.projectsPath);
    await sleep(500);

    // Step 2: Create initial config
    if (statusEl) statusEl.textContent = 'Creating configuration files...';
    await api.createInitialConfig(config);
    await sleep(500);

    // Step 3: Import hosts if available
    if (importedHosts.length > 0) {
      if (statusEl) statusEl.textContent = `Importing ${importedHosts.length} hosts...`;
      const hostsPath = `${config.configPath}/hosts.json`;
      await api.writeFile(hostsPath, JSON.stringify(importedHosts, null, 2));
      await sleep(500);
    }

    // Step 4: Save settings
    if (statusEl) statusEl.textContent = 'Saving settings...';
    localStorage.setItem('serverStack', config.stack);
    localStorage.setItem('projectsPath', config.projectsPath);
    localStorage.setItem('configPath', config.configPath);
    localStorage.setItem('sslPath', config.sslPath);
    if (importedHosts.length > 0) {
      localStorage.setItem('importedHosts', String(importedHosts.length));
    }
    await sleep(500);

    // Complete!
    if (progressDiv) progressDiv.classList.add('d-none');
    if (completeDiv) completeDiv.classList.remove('d-none');

    if (nextBtn) {
      nextBtn.disabled = false;
      nextBtn.innerHTML = 'Get Started <i class="ti ti-arrow-right ms-1"></i>';
    }

  } catch (error) {
    console.error('Setup error:', error);
    if (statusEl) {
      statusEl.innerHTML = `<span class="text-danger"><i class="ti ti-alert-circle me-1"></i>Error: ${error}</span>`;
    }
    if (nextBtn) nextBtn.disabled = false;
    if (backBtn) backBtn.disabled = false;
  }
}

async function completeSetup() {
  localStorage.setItem('setupCompleted', 'true');
  localStorage.setItem('setupDate', new Date().toISOString());

  if (wizardModal) {
    wizardModal.hide();
  }

  // Reload the page to apply settings
  window.location.reload();
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Reset setup (for testing or re-configuration)
export function resetSetup() {
  localStorage.removeItem('setupCompleted');
  localStorage.removeItem('setupDate');
  localStorage.removeItem('serverStack');
  localStorage.removeItem('projectsPath');
  localStorage.removeItem('configPath');
  localStorage.removeItem('sslPath');
}

// Export for window access
(window as any).setupWizard = {
  init: initSetupWizard,
  reset: resetSetup,
  checkFirstRun
};
