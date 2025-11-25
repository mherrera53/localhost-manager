// ============================================
// Application State
// ============================================

import type { PhpVersion, PhpConfig, ProjectProfile } from './types';

export class AppState {
  availableVersions: PhpVersion[] = [];
  installedVersions: PhpVersion[] = [];
  currentConfig: PhpConfig | null = null;
  projects: ProjectProfile[] = [];

  setAvailableVersions(versions: PhpVersion[]) {
    this.availableVersions = versions;
  }

  setInstalledVersions(versions: PhpVersion[]) {
    this.installedVersions = versions;
  }

  setCurrentConfig(config: PhpConfig | null) {
    this.currentConfig = config;
  }

  setProjects(projects: ProjectProfile[]) {
    this.projects = projects;
  }

  addProject(project: ProjectProfile) {
    this.projects.push(project);
  }

  removeProject(id: string) {
    this.projects = this.projects.filter(p => p.id !== id);
  }
}

export const state = new AppState();
