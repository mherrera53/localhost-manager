// ============================================
// UI Utilities
// ============================================

import type { ToastType } from './types';

export function showToast(message: string, type: ToastType = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  // Color mapping
  const colorMap = {
    success: 'bg-success',
    error: 'bg-danger',
    warning: 'bg-warning',
    info: 'bg-info'
  };

  // Icon mapping
  const iconMap = {
    success: 'ti-circle-check',
    error: 'ti-circle-x',
    warning: 'ti-alert-triangle',
    info: 'ti-info-circle'
  };

  const toastId = `toast-${Date.now()}`;
  const bgColor = colorMap[type] || 'bg-info';
  const icon = iconMap[type] || 'ti-info-circle';

  const toastHTML = `
    <div class="toast align-items-center text-white ${bgColor} border-0" role="alert" id="${toastId}" aria-live="assertive" aria-atomic="true">
      <div class="d-flex">
        <div class="toast-body">
          <i class="ti ${icon} me-2"></i>
          ${message}
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
      </div>
    </div>
  `;

  container.insertAdjacentHTML('beforeend', toastHTML);

  const toastElement = document.getElementById(toastId);
  if (toastElement) {
    const bsToast = new (window as any).bootstrap.Toast(toastElement, {
      autohide: true,
      delay: 3000
    });
    bsToast.show();

    // Remove from DOM after hiding
    toastElement.addEventListener('hidden.bs.toast', () => {
      toastElement.remove();
    });
  }
}

export function switchTab(tabName: string) {
  // Update tab buttons
  document.querySelectorAll('.tab').forEach(tab => {
    tab.classList.remove('active');
    if (tab.getAttribute('data-tab') === tabName) {
      tab.classList.add('active');
    }
  });

  // Update tab contents
  document.querySelectorAll('.tab-content').forEach(content => {
    content.classList.remove('active');
  });

  const activeContent = document.getElementById(`tab-${tabName}`);
  if (activeContent) {
    activeContent.classList.add('active');
  }
}

export function showModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('active');
  }
}

export function hideModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('active');
  }
}

export function getElementValue(id: string): string {
  const element = document.getElementById(id) as HTMLInputElement | HTMLSelectElement;
  return element ? element.value : '';
}

export function setElementValue(id: string, value: string) {
  const element = document.getElementById(id) as HTMLInputElement | HTMLSelectElement;
  if (element) {
    element.value = value;
  }
}

export function clearForm(...elementIds: string[]) {
  elementIds.forEach(id => setElementValue(id, ''));
}
