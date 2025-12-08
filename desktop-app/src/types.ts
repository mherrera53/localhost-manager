// ============================================
// Type Definitions
// ============================================

export interface PhpVersion {
  version: string;
  major: number;
  minor: number;
  patch: number;
  installed: boolean;
  install_path?: string;
  download_url?: string;
}

export interface PhpConfig {
  version: string;
  install_path: string;
  php_ini_path: string;
  extensions: PhpExtension[];
  settings: Record<string, string>;
}

export interface PhpExtension {
  name: string;
  enabled: boolean;
  version?: string;
}

export interface ProjectProfile {
  id: string;
  name: string;
  path: string;
  php_version: string;
  extensions: string[];
  custom_ini_settings: Record<string, string>;
}

export interface VirtualHostAlias {
  id: string;
  value: string;
  active: boolean;
}

export interface VirtualHost {
  domain: string;
  docroot: string;
  aliases: VirtualHostAlias[];
  group: string;
  active: boolean;
  ssl: boolean;
  type: string;
}

export interface ServicesStatus {
  apache: boolean;
  mysql: boolean;
  php: boolean;
  all_running: boolean;
}

export type ToastType = 'success' | 'error' | 'warning';
export type ApacheAction = 'start' | 'stop' | 'restart';
