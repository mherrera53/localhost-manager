import { invoke } from '@tauri-apps/api/core';
import { open as openDialog } from '@tauri-apps/plugin-dialog';
import { showToast } from './ui';

interface AppConfig {
  scripts_base_path: string;
  hosts_json_path: string;
  apache_config_path: string;
  apache_vhosts_path: string;
  ssl_certificates_path: string;
  logs_path: string;
}

export async function loadConfig(): Promise<AppConfig> {
  try {
    return await invoke<AppConfig>('get_app_config');
  } catch (error) {
    console.error('Error loading config:', error);
    throw error;
  }
}

export async function saveConfig(config: AppConfig): Promise<void> {
  try {
    await invoke('save_app_config', { config });
    showToast('Configuration saved successfully', 'success');
  } catch (error) {
    console.error('Error saving config:', error);
    showToast(`Error saving config: ${error}`, 'error');
    throw error;
  }
}

export async function resetConfig(): Promise<AppConfig> {
  try {
    const config = await invoke<AppConfig>('reset_app_config');
    showToast('Configuration reset to defaults', 'success');
    return config;
  } catch (error) {
    console.error('Error resetting config:', error);
    showToast(`Error resetting config: ${error}`, 'error');
    throw error;
  }
}

export async function validateConfig(config: AppConfig): Promise<boolean> {
  try {
    await invoke('validate_config_paths', { config });
    showToast('All paths are valid', 'success');
    return true;
  } catch (error) {
    console.error('Config validation errors:', error);
    showToast(`Validation errors: ${error}`, 'error');
    return false;
  }
}

export function showConfigModal() {
  const modal = document.getElementById('configModal');
  if (modal) {
    const bsModal = new (window as any).bootstrap.Modal(modal);
    loadAndPopulateConfig();
    bsModal.show();
  }
}

export function hideConfigModal() {
  const modal = document.getElementById('configModal');
  if (modal) {
    const bsModal = (window as any).bootstrap.Modal.getInstance(modal);
    if (bsModal) {
      bsModal.hide();
    }
  }
}

async function loadAndPopulateConfig() {
  try {
    const config = await loadConfig();
    
    (document.getElementById('config-scripts-path') as HTMLInputElement).value = config.scripts_base_path;
    (document.getElementById('config-hosts-json') as HTMLInputElement).value = config.hosts_json_path;
    (document.getElementById('config-apache-path') as HTMLInputElement).value = config.apache_config_path;
    (document.getElementById('config-vhosts-path') as HTMLInputElement).value = config.apache_vhosts_path;
    (document.getElementById('config-certs-path') as HTMLInputElement).value = config.ssl_certificates_path;
    (document.getElementById('config-logs-path') as HTMLInputElement).value = config.logs_path;
  } catch (error) {
    console.error('Error loading config:', error);
  }
}

export function initConfigListeners() {
  document.getElementById('btn-settings')?.addEventListener('click', showConfigModal);

  // Folder browse buttons (data-browse) and file browse buttons (data-browse-file)
  document.querySelectorAll('[data-browse]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-browse');
      if (!id) return;
      const selected = await openDialog({ directory: true, multiple: false, title: 'Select folder' });
      if (typeof selected === 'string') {
        (document.getElementById(id) as HTMLInputElement).value = selected;
      }
    });
  });
  document.querySelectorAll('[data-browse-file]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-browse-file');
      if (!id) return;
      const selected = await openDialog({ directory: false, multiple: false, title: 'Select file' });
      if (typeof selected === 'string') {
        (document.getElementById(id) as HTMLInputElement).value = selected;
      }
    });
  });

  // Smart finder: auto-detect installed server paths
  document.getElementById('btn-config-autodetect')?.addEventListener('click', async () => {
    try {
      const detected = await invoke<Partial<AppConfig>>('detect_server_paths');
      const map: Record<string, string | undefined> = {
        'config-scripts-path': detected.scripts_base_path,
        'config-hosts-json': detected.hosts_json_path,
        'config-apache-path': detected.apache_config_path,
        'config-vhosts-path': detected.apache_vhosts_path,
        'config-certs-path': detected.ssl_certificates_path,
        'config-logs-path': detected.logs_path,
      };
      for (const [id, val] of Object.entries(map)) {
        if (val) (document.getElementById(id) as HTMLInputElement).value = val;
      }
      showToast('Detected server paths', 'success');
    } catch (error) {
      showToast(`Auto-detect failed: ${error}`, 'error');
    }
  });
  
  document.getElementById('btn-config-save')?.addEventListener('click', async () => {
    const config: AppConfig = {
      scripts_base_path: (document.getElementById('config-scripts-path') as HTMLInputElement).value,
      hosts_json_path: (document.getElementById('config-hosts-json') as HTMLInputElement).value,
      apache_config_path: (document.getElementById('config-apache-path') as HTMLInputElement).value,
      apache_vhosts_path: (document.getElementById('config-vhosts-path') as HTMLInputElement).value,
      ssl_certificates_path: (document.getElementById('config-certs-path') as HTMLInputElement).value,
      logs_path: (document.getElementById('config-logs-path') as HTMLInputElement).value,
    };
    
    try {
      await saveConfig(config);
      hideConfigModal();
    } catch (error) {
      console.error('Save failed:', error);
    }
  });
  
  document.getElementById('btn-config-validate')?.addEventListener('click', async () => {
    const config: AppConfig = {
      scripts_base_path: (document.getElementById('config-scripts-path') as HTMLInputElement).value,
      hosts_json_path: (document.getElementById('config-hosts-json') as HTMLInputElement).value,
      apache_config_path: (document.getElementById('config-apache-path') as HTMLInputElement).value,
      apache_vhosts_path: (document.getElementById('config-vhosts-path') as HTMLInputElement).value,
      ssl_certificates_path: (document.getElementById('config-certs-path') as HTMLInputElement).value,
      logs_path: (document.getElementById('config-logs-path') as HTMLInputElement).value,
    };
    
    await validateConfig(config);
  });
  
  document.getElementById('btn-config-reset')?.addEventListener('click', async () => {
    if (confirm('Are you sure you want to reset all paths to defaults?')) {
      try {
        const config = await resetConfig();
        (document.getElementById('config-scripts-path') as HTMLInputElement).value = config.scripts_base_path;
        (document.getElementById('config-hosts-json') as HTMLInputElement).value = config.hosts_json_path;
        (document.getElementById('config-apache-path') as HTMLInputElement).value = config.apache_config_path;
        (document.getElementById('config-vhosts-path') as HTMLInputElement).value = config.apache_vhosts_path;
        (document.getElementById('config-certs-path') as HTMLInputElement).value = config.ssl_certificates_path;
        (document.getElementById('config-logs-path') as HTMLInputElement).value = config.logs_path;
      } catch (error) {
        console.error('Reset failed:', error);
      }
    }
  });
  
  document.getElementById('btn-config-cancel')?.addEventListener('click', hideConfigModal);
}
