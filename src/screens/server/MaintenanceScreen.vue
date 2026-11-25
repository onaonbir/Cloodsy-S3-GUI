<script setup lang="ts">
// Consistency scan (read-only): orphan bucket folders, objects whose file is
// missing, files no object points to. Orphan folders can be deleted (type
// "delete"); the page scans again afterwards.
import { computed, ref, shallowRef } from 'vue';
import { CheckCircle2, FileQuestion, FileX, FolderX, ScanSearch } from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import States from '@/components/ui/States.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import Panel from './parts/Panel.vue';
import Spinner from './parts/Spinner.vue';
import { useApi } from '@/stores/session';
import { toast, toastError } from '@/stores/toasts';
import { confirm } from '@/lib/dialogs';
import { formatBytes, formatCount, formatDateTime } from '@/lib/format';
import { t } from '@/lib/i18n';
import type { ScanResult } from '@/lib/api';

/** Rows shown per list (the server caps its lists too). */
const SHOWN = 200;

const report = shallowRef<ScanResult | null>(null);
const scannedAt = ref<Date | null>(null);
const scanning = ref(false);
const deleting = ref(false);
const error = ref<string | null>(null);

async function scan() {
  if (scanning.value) return;
  scanning.value = true;
  error.value = null;
  try {
    const r = await useApi().scan();
    report.value = { ...r, orphan_dirs: r.orphan_dirs ?? [], missing_files: r.missing_files ?? [], untracked_files: r.untracked_files ?? [] };
    scannedAt.value = new Date();
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    scanning.value = false;
  }
}

const clean = computed(() => {
  const r = report.value;
  return !!r && !r.orphan_dirs.length && !r.missing_files.length && !r.untracked_files.length;
});

const summary = computed(() => {
  const r = report.value;
  if (!r) return '';
  if (clean.value) return t('All {n} objects are consistent with the disk.', { n: formatCount(r.scanned_objects) });
  const s = t('Scanned {n} objects at {t}.', { n: formatCount(r.scanned_objects), t: formatDateTime(scannedAt.value?.toISOString()) });
  return r.truncated ? `${s} ${t('Lists are capped; fix and scan again to see more.')}` : s;
});

async function deleteOrphans() {
  const r = report.value;
  if (!r?.orphan_dirs.length) return;
  const ok = await confirm({
    title: t('Delete orphan folders'),
    message: t('Permanently delete {n} folder(s) ({size}) from the server disk? The server re-checks each path first.', {
      n: r.orphan_dirs.length,
      size: formatBytes(r.orphan_dirs.reduce((s, d) => s + (d.bytes ?? 0), 0)),
    }),
    typeToConfirm: 'delete',
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  deleting.value = true;
  try {
    const res = await useApi().deleteOrphans(r.orphan_dirs.map((d) => d.path));
    const failed = res.failed ?? [];
    await scan();
    if (!failed.length) toast(t('{n} folder(s) deleted', { n: res.deleted ?? 0 }));
    else toast(`${t('{ok} deleted, {failed} failed', { ok: res.deleted ?? 0, failed: failed.length })}: ${failed[0].path}: ${failed[0].error}`, true);
  } catch (e) {
    toastError(e);
  } finally {
    deleting.value = false;
  }
}

const missingText = (m: ScanResult['missing_files'][number]) =>
  `${m.bucket}/${m.key}${m.version_id ? `  (${t('version {v}', { v: m.version_id })})` : ''}`;

const lists = computed(() => {
  const r = report.value;
  if (!r) return [];
  return [
    {
      id: 'orphans', icon: FolderX, title: t('Orphan folders'), count: r.orphan_dirs.length,
      explain: t('Bucket-named folders with no bucket in the database (e.g. left over after a delete).'),
      rows: r.orphan_dirs.slice(0, SHOWN).map((d) => ({ text: d.path, bytes: d.bytes as number | null })),
    },
    {
      id: 'missing', icon: FileX, title: t('Missing files'), count: r.missing_files.length,
      explain: t('Objects in the database whose file is gone. Downloads of these fail.'),
      rows: r.missing_files.slice(0, SHOWN).map((m) => ({ text: missingText(m), bytes: null as number | null })),
    },
    {
      id: 'untracked', icon: FileQuestion, title: t('Untracked files'), count: r.untracked_files.length,
      explain: t('Files inside bucket folders that no object points to. They use space but are invisible to clients.'),
      rows: r.untracked_files.slice(0, SHOWN).map((u) => ({ text: u.path, bytes: u.bytes as number | null })),
    },
  ];
});
</script>

<template>
  <Page :max="1000">
    <PageHead :title="t('Maintenance')" :subtitle="t('Check that the database and the files on disk agree.')">
      <button class="btn primary" :disabled="scanning || deleting" @click="scan">
        <Spinner v-if="scanning" /><ScanSearch v-else :size="16" />{{ report ? t('Scan again') : t('Run scan') }}
      </button>
    </PageHead>

    <Callout v-if="error" tone="danger">{{ error }}</Callout>

    <div v-if="!report" class="card">
      <States v-if="scanning" kind="loading" compact />
      <States v-else kind="empty" compact :title="t('No scan yet')" :message="t('The scan is read-only. It lists leftover bucket folders, objects whose file is missing and files no object points to.')">
        <template #icon><ScanSearch :size="22" /></template>
      </States>
    </div>

    <template v-else>
      <Callout :tone="clean ? 'success' : 'warning'">{{ summary }}</Callout>
      <Panel v-for="l in lists" :key="l.id" :icon="l.icon" :title="`${l.title} (${formatCount(l.count)})`" :subtitle="l.explain">
        <template v-if="l.id === 'orphans' && l.count" #actions>
          <button class="btn ghost sm danger" :disabled="deleting || scanning" @click="deleteOrphans">
            <Spinner v-if="deleting" :size="13" />{{ t('Delete all…') }}
          </button>
        </template>
        <div v-if="!l.count" class="row nothing"><CheckCircle2 :size="15" class="success-text" /><span class="t-body">{{ t('Nothing found') }}</span></div>
        <div v-else class="items">
          <div v-for="(row, i) in l.rows" :key="i" class="item">
            <span class="mono selectable path">{{ row.text }}</span>
            <span v-if="row.bytes !== null" class="t-body-sm size">{{ formatBytes(row.bytes) }}</span>
          </div>
          <div v-if="l.count > l.rows.length" class="t-body-sm more">{{ t('{n} more not shown', { n: formatCount(l.count - l.rows.length) }) }}</div>
        </div>
      </Panel>
    </template>
  </Page>
</template>

<style scoped>
.nothing { gap: 8px; }
.items { display: flex; flex-direction: column; }
.item { display: flex; align-items: baseline; gap: 12px; padding: 3px 0; }
.path { flex: 1; min-width: 0; font-size: 12px; color: var(--foreground); overflow-wrap: anywhere; }
.size { flex-shrink: 0; }
.more { padding-top: 6px; }
</style>
