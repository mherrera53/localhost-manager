// ============================================
// Tauri API Calls
// ============================================

import { invoke } from "@tauri-apps/api/core";
import type { PhpVersion, PhpConfig, VirtualHost, ServicesStatus } from './types';

export async function getAvailablePhpVersions(): Promise<PhpVersion[]> {
  return await invoke<PhpVersion[]>('get_available_php_versions');
}

export async function getInstalledPhpVersions(): Promise<PhpVersion[]> {
  return await invoke<PhpVersion[]>('get_installed_php_versions');
}

export async function installPhpVersion(version: string): Promise<string> {
  return await invoke<string>('install_php_version', { version });
}

export async function uninstallPhpVersion(version: string): Promise<string> {
  return await invoke<string>('uninstall_php_version', { version });
}

export async function getPhpConfig(version: string): Promise<PhpConfig> {
  return await invoke<PhpConfig>('get_php_config', { version });
}

export async function updatePhpIniSetting(
  version: string,
  key: string,
  value: string
): Promise<void> {
  await invoke('update_php_ini_setting', { version, key, value });
}

export async function getVirtualHosts(): Promise<Record<string, VirtualHost>> {
  return await invoke<Record<string, VirtualHost>>('get_virtual_hosts');
}

export async function saveVirtualHosts(hosts: Record<string, VirtualHost>): Promise<void> {
  await invoke('save_virtual_hosts', { hosts });
}

export async function getServicesStatus(): Promise<ServicesStatus> {
  return await invoke<ServicesStatus>('get_services_status');
}

export async function getSystemLanguage(): Promise<string> {
  return await invoke<string>('get_system_language');
}

export async function executeWithPrivileges(command: string, args: string[]): Promise<string> {
  return await invoke<string>('execute_with_privileges', { command, args });
}

export async function getCurrentPhpVersion(): Promise<string> {
  return await invoke<string>('get_current_php_version');
}

export async function getCurrentApacheVersion(): Promise<string> {
  return await invoke<string>('get_current_apache_version');
}

export async function getCurrentMysqlVersion(): Promise<string> {
  return await invoke<string>('get_current_mysql_version');
}

export async function generateConfigs(): Promise<string> {
  return await invoke<string>('generate_configs');
}

export async function applyConfigs(): Promise<string> {
  return await invoke<string>('apply_configs');
}

export async function controlService(action: string, service: string): Promise<string> {
  return await invoke<string>('control_service', { action, service });
}

export async function deleteHost(domain: string): Promise<void> {
  await invoke('delete_host', { domain });
}
