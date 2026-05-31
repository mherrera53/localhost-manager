// ============================================
// Configuration sharing & smart migration (v1.1.0)
// ============================================
// Export/import a portable hosts.json bundle and migrate existing local setups
// (Docker, Apache, Valet, nginx) into the manager. Everything goes through a
// preview before anything is written; imports never overwrite existing domains.

import { invoke } from '@tauri-apps/api/core';
import { open as openDialog, save as saveDialog } from '@tauri-apps/plugin-dialog';
import { showToast } from './ui';
import { loadVirtualHosts } from './hosts';

interface ImportPreview {
  added: string[];
  skipped: string[];
}

interface HostCandidate {
  domain: string;
  docroot: string | null;
  port: number | null;
  aliases: string[];
  ssl: boolean;
  stack: string;
  source: string;
}

// State carried from a preview to its confirmation step.
let pendingBundlePath: string | null = null;
let pendingCandidates: HostCandidate[] = [];

function getOrCreateModal(id: string): { show: () => void; hide: () => void } | null {
  const el = document.getElementById(id);
  if (!el) return null;
  const bs = (window as any).bootstrap;
  return bs.Modal.getInstance(el) || new bs.Modal(el);
}

function escapeHtml(value: string): string {
  const div = document.createElement('div');
  div.textContent = value;
  return div.innerHTML;
}

// ---------- Export ----------

async function exportBundle(): Promise<void> {
  try {
    const dest = await saveDialog({
      title: 'Export configuration bundle',
      defaultPath: 'localhost-manager-hosts.zip',
      filters: [
        { name: 'Bundle (zip)', extensions: ['zip'] },
        { name: 'Plain JSON', extensions: ['json'] },
      ],
    });
    if (!dest) return;
    const written = await invoke<string>('export_hosts_bundle', { dest });
    showToast(`Configuration exported to ${written}`, 'success');
  } catch (error) {
    showToast(`Export failed: ${error}`, 'error');
  }
}

// ---------- Import bundle (preview -> confirm) ----------

async function importBundle(): Promise<void> {
  try {
    const selected = await openDialog({
      title: 'Import configuration bundle',
      multiple: false,
      directory: false,
      filters: [{ name: 'Bundle', extensions: ['zip', 'json'] }],
    });
    if (typeof selected !== 'string') return;
    const preview = await invoke<ImportPreview>('preview_import', { path: selected });
    pendingBundlePath = selected;
    renderBundlePreview(preview);
    getOrCreateModal('bundlePreviewModal')?.show();
  } catch (error) {
    showToast(`Could not read bundle: ${error}`, 'error');
  }
}

function renderBundlePreview(preview: ImportPreview): void {
  const body = document.getElementById('bundle-preview-body');
  if (!body) return;
  const added = preview.added
    .map((d) => `<li class="text-success"><i class="ti ti-plus me-1"></i>${escapeHtml(d)}</li>`)
    .join('');
  const skipped = preview.skipped
    .map(
      (d) =>
        `<li class="text-muted"><i class="ti ti-equal me-1"></i>${escapeHtml(d)} <small>(already present)</small></li>`,
    )
    .join('');
  body.innerHTML = `
    <p class="mb-1"><strong>${preview.added.length}</strong> new domain(s) to add,
       <strong>${preview.skipped.length}</strong> already present (skipped).</p>
    <ul class="list-unstyled small mb-0">${added}${skipped}</ul>`;

  const confirmBtn = document.getElementById('btn-bundle-confirm') as HTMLButtonElement | null;
  if (confirmBtn) confirmBtn.disabled = preview.added.length === 0;
}

async function confirmBundleImport(): Promise<void> {
  if (!pendingBundlePath) return;
  try {
    const result = await invoke<ImportPreview>('import_hosts_bundle', { path: pendingBundlePath });
    getOrCreateModal('bundlePreviewModal')?.hide();
    showToast(`Imported ${result.added.length} new domain(s)`, 'success');
    await loadVirtualHosts();
  } catch (error) {
    showToast(`Import failed: ${error}`, 'error');
  } finally {
    pendingBundlePath = null;
  }
}

// ---------- Migrate from… (preview -> multi-select -> apply) ----------

async function scanMigrationSource(): Promise<void> {
  const select = document.getElementById('migrate-source') as HTMLSelectElement | null;
  const source = select?.value ?? 'docker';
  try {
    let candidates: HostCandidate[] = [];

    if (source === 'docker') {
      const file = await openDialog({
        title: 'Select docker-compose.yml',
        multiple: false,
        directory: false,
        filters: [{ name: 'Compose', extensions: ['yml', 'yaml'] }],
      });
      if (typeof file !== 'string') return;
      candidates = await invoke<HostCandidate[]>('migrate_from_docker', { composePath: file });
    } else if (source === 'apache') {
      const file = await openDialog({
        title: 'Select Apache vhosts file',
        multiple: false,
        directory: false,
        filters: [{ name: 'Apache config', extensions: ['conf'] }],
      });
      if (typeof file !== 'string') return;
      candidates = await invoke<HostCandidate[]>('migrate_from_apache', { file });
    } else if (source === 'nginx') {
      const dir = await openDialog({
        title: 'Select nginx sites-enabled folder',
        multiple: false,
        directory: true,
      });
      if (typeof dir !== 'string') return;
      candidates = await invoke<HostCandidate[]>('migrate_from_nginx', { dir });
    } else if (source === 'valet') {
      candidates = await invoke<HostCandidate[]>('migrate_from_valet');
    }

    if (candidates.length === 0) {
      showToast('No importable hosts found in that source', 'warning');
      return;
    }
    pendingCandidates = candidates;
    renderMigratePreview(candidates);
    getOrCreateModal('migratePreviewModal')?.show();
  } catch (error) {
    showToast(`Scan failed: ${error}`, 'error');
  }
}

function renderMigratePreview(candidates: HostCandidate[]): void {
  const body = document.getElementById('migrate-preview-body');
  if (!body) return;
  body.innerHTML = candidates
    .map((c, i) => {
      const target = c.port != null ? `:${c.port}` : c.docroot ? escapeHtml(c.docroot) : '--';
      const ssl = c.ssl ? ' <i class="ti ti-lock text-success" title="SSL"></i>' : '';
      return `
        <tr>
          <td><input type="checkbox" class="migrate-row" data-index="${i}" checked></td>
          <td>${escapeHtml(c.domain)}${ssl}</td>
          <td><small>${target}</small></td>
          <td><span class="badge bg-secondary">${escapeHtml(c.stack)}</span></td>
          <td><small class="text-muted">${escapeHtml(c.source)}</small></td>
        </tr>`;
    })
    .join('');

  const selectAll = document.getElementById('migrate-select-all') as HTMLInputElement | null;
  if (selectAll) selectAll.checked = true;
}

async function applyMigration(): Promise<void> {
  const checks = Array.from(document.querySelectorAll<HTMLInputElement>('.migrate-row'));
  const selected = checks
    .filter((c) => c.checked)
    .map((c) => pendingCandidates[Number(c.dataset.index)])
    .filter(Boolean);

  if (selected.length === 0) {
    showToast('Select at least one host to import', 'warning');
    return;
  }
  try {
    const result = await invoke<ImportPreview>('apply_candidates', { candidates: selected });
    getOrCreateModal('migratePreviewModal')?.hide();
    const skippedNote = result.skipped.length ? `, ${result.skipped.length} already present` : '';
    showToast(`Imported ${result.added.length} host(s)${skippedNote}`, 'success');
    await loadVirtualHosts();
  } catch (error) {
    showToast(`Migration failed: ${error}`, 'error');
  } finally {
    pendingCandidates = [];
  }
}

export function initMigrationListeners(): void {
  document.getElementById('btn-export-bundle')?.addEventListener('click', exportBundle);
  document.getElementById('btn-import-bundle')?.addEventListener('click', importBundle);
  document.getElementById('btn-migrate-scan')?.addEventListener('click', scanMigrationSource);
  document.getElementById('btn-bundle-confirm')?.addEventListener('click', confirmBundleImport);
  document.getElementById('btn-migrate-apply')?.addEventListener('click', applyMigration);

  document.getElementById('migrate-select-all')?.addEventListener('change', (e) => {
    const checked = (e.target as HTMLInputElement).checked;
    document.querySelectorAll<HTMLInputElement>('.migrate-row').forEach((c) => {
      c.checked = checked;
    });
  });
}
