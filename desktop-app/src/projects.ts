// ============================================
// Project Profiles Manager
// ============================================

import { state } from './state';
import { showToast, showModal, hideModal, getElementValue, clearForm } from './ui';
import type { ProjectProfile } from './types';
import { open } from "@tauri-apps/plugin-dialog";

const STORAGE_KEY = 'localhost-manager-projects';

export function load() {
  const stored = localStorage.getItem(STORAGE_KEY);
  const projects = stored ? JSON.parse(stored) : [];
  state.setProjects(projects);
  render();
}

export function save() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.projects));
}

export function render() {
  const container = document.getElementById('projects-list');
  if (!container) return;

  if (state.projects.length === 0) {
    container.innerHTML = '<p class="empty-state">No projects configured. Click "Add Project" to get started.</p>';
    return;
  }

  container.innerHTML = state.projects.map(project => `
    <div class="project-card">
      <div class="project-name">${project.name}</div>
      <div class="project-path">${project.path}</div>
      <div class="project-php-version">PHP ${project.php_version}</div>
    </div>
  `).join('');
}

export function showAddModal() {
  showModal('project-modal');
}

export function hideAddModal() {
  hideModal('project-modal');
  clearForm('project-name', 'project-path', 'project-php-version');
}

export async function browsePath() {
  try {
    const selected = await open({
      directory: true,
      multiple: false,
    });

    if (selected) {
      const pathInput = document.getElementById('project-path') as HTMLInputElement;
      if (pathInput) {
        pathInput.value = selected as string;
      }
    }
  } catch (error) {
    console.error('Error browsing path:', error);
  }
}

export function saveProject() {
  const name = getElementValue('project-name');
  const path = getElementValue('project-path');
  const phpVersion = getElementValue('project-php-version');

  if (!name || !path || !phpVersion) {
    showToast('Please fill all fields', 'error');
    return;
  }

  const project: ProjectProfile = {
    id: Date.now().toString(),
    name,
    path,
    php_version: phpVersion,
    extensions: [],
    custom_ini_settings: {}
  };

  state.addProject(project);
  save();
  render();
  hideAddModal();
  showToast('Project added successfully', 'success');
}
