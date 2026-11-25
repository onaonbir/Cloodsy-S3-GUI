<script setup lang="ts">
// Versioning, public read, WebDAV, quota, storage directory, image variants,
// incomplete multipart uploads and the danger zone (2.0 settings_tab.dart).
import { computed, onMounted, reactive, ref } from 'vue';
import { FileUp, FolderCog, Gauge, Globe, HardDrive, History, Image, Loader2, MoreHorizontal, RefreshCw, ToggleRight, Database } from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import Toggle from '@/components/ui/Toggle.vue';
import Panel from '../buckets/Panel.vue';
import QuotaDialog from './dialogs/QuotaDialog.vue';
import StorageDialog from './dialogs/StorageDialog.vue';
import { useBucket } from '../buckets/bucketStore';
import { deleteBucketFlow } from '../buckets/flows';
import { hasQuota, reprocessConflictMessage, versioningEnabled } from '../buckets/logic';
import { has, status } from '@/stores/session';
import { runAction, toast, toastError } from '@/stores/toasts';
import { confirm } from '@/lib/dialogs';
import { openDialog } from '@/lib/overlay';
import { openMenu } from '@/lib/menu';
import type { ApiError } from '@/lib/ipc';
import { formatBytes, formatDateTime, formatRelative } from '@/lib/format';
import { t, tn } from '@/lib/i18n';

const store = useBucket();
const s = store.state;
const b = computed(() => s.bucket!);

// ---- toggles
type ToggleKey = 'versioning' | 'public' | 'webdav';
const busy = reactive<Record<ToggleKey, boolean>>({ versioning: false, public: false, webdav: false });

async function toggle(key: ToggleKey, on: boolean) {
  const title = { versioning: t('Versioning'), public: t('Public read'), webdav: t('WebDAV access') }[key];
  let question: string | null = null;
  if (key === 'versioning' && !on && versioningEnabled(b.value)) {
    question = t('Suspend versioning? Existing versions are kept, but new overwrites replace the current object.');
  }
  if (key === 'public' && on) question = t('Make every object in “{b}” readable without authentication?', { b: b.value.name });
  if (question) {
    const ok = await confirm({ title, message: question, confirmLabel: on ? t('Enable') : t('Disable'), danger: true });
    if (!ok) return;
  }
  busy[key] = true;
  const fn = key === 'versioning' ? store.setVersioning : key === 'public' ? store.setPublicRead : store.setWebDAV;
  await runAction(() => fn(on), on ? t('{what} enabled', { what: title }) : t('{what} disabled', { what: title }));
  busy[key] = false;
}

const versioningText = computed(() => {
  if (versioningEnabled(b.value)) return t('Every overwrite and delete keeps the previous version.');
  if (b.value.versioning === 'Suspended') return t('Suspended: existing versions are kept, new writes replace the current object.');
  return t('Overwrites and deletes are permanent.');
});
const webdavText = computed(() => {
  if (!status.value?.webdav?.enabled) return t('WebDAV is disabled on this server (webdav.enabled).');
  return b.value.webdav_enabled ? t('Mountable as a network drive with an access key.') : t('Not mountable over WebDAV.');
});

// ---- storage
async function editQuota() {
  const ok = await openDialog<boolean>(QuotaDialog, { current: b.value.quota_bytes ?? 0, apply: store.setQuota });
  if (ok) toast(t('Quota updated'));
}

async function editStorage() {
  const ok = await openDialog<boolean>(StorageDialog, { current: b.value.storage_dir ?? '', apply: store.setStorage });
  if (ok) toast(t('Storage directory updated'));
}

const reprocessing = ref(false);
async function reprocess() {
  reprocessing.value = true;
  try {
    await store.reprocess();
    toast(t('Reprocessing started'));
  } catch (e) {
    const err = e as ApiError;
    if (err.status === -1) return;
    toast(err.status === 409 ? reprocessConflictMessage(err.message) : err.message, true);
  } finally {
    reprocessing.value = false;
  }
}

// ---- incomplete uploads
const multipart = computed(() => has('multipart'));
const uploadsError = ref<string | null>(null);
const uploadsLoading = ref(false);
const aborting = ref<string | null>(null);
const uploadBytes = computed(() => s.uploads.reduce((sum, u) => sum + (u.bytes ?? 0), 0));

async function loadUploads() {
  uploadsLoading.value = true;
  try {
    await store.loadUploads();
    uploadsError.value = null;
  } catch (e) {
    uploadsError.value = (e as Error).message;
  } finally {
    uploadsLoading.value = false;
  }
}
onMounted(() => {
  if (multipart.value) void loadUploads();
});

async function abortOne(id: string) {
  aborting.value = id;
  await runAction(() => store.abortUpload(id), t('Upload aborted'));
  aborting.value = null;
}

async function abortMany(olderThanDays?: number) {
  const ok = await confirm({
    title: t('Abort uploads'),
    message: olderThanDays
      ? t('Abort incomplete uploads started more than {n} days ago?', { n: olderThanDays })
      : t('Abort every incomplete upload in this bucket? Clients still uploading will fail.'),
    confirmLabel: t('Abort'),
    danger: true,
  });
  if (!ok) return;
  uploadsLoading.value = true;
  try {
    const n = await store.abortUploads(olderThanDays);
    toast(tn(n, '{n} upload aborted', '{n} uploads aborted'));
  } catch (e) {
    toastError(e);
  } finally {
    uploadsLoading.value = false;
  }
}

function uploadsMenu(e: MouseEvent) {
  openMenu(e, [
    { label: t('Abort older than 7 days'), action: () => void abortMany(7) },
    { label: t('Abort all'), danger: true, action: () => void abortMany() },
  ]);
}
</script>

<template>
  <div class="tab">
    <Panel :title="t('Access & features')" :icon="ToggleRight" flush>
      <div class="item">
        <History :size="18" class="lead" />
        <div class="grow"><div class="t-label-lg">{{ t('Versioning') }}</div><div class="t-body">{{ versioningText }}</div></div>
        <Loader2 v-if="busy.versioning" :size="16" class="spin" />
        <Toggle :model-value="versioningEnabled(b)" :busy="busy.versioning" @update:model-value="(v) => toggle('versioning', v)" />
      </div>
      <div class="item">
        <Globe :size="18" class="lead" :class="{ 'warning-text': b.public_read }" />
        <div class="grow">
          <div class="t-label-lg">{{ t('Public read') }}</div>
          <div class="t-body">{{ b.public_read ? t('Anyone with the URL can download objects.') : t('Requests must be signed with an access key.') }}</div>
        </div>
        <Loader2 v-if="busy.public" :size="16" class="spin" />
        <Toggle :model-value="b.public_read" :busy="busy.public" @update:model-value="(v) => toggle('public', v)" />
      </div>
      <div class="item">
        <HardDrive :size="18" class="lead" />
        <div class="grow"><div class="t-label-lg">{{ t('WebDAV access') }}</div><div class="t-body">{{ webdavText }}</div></div>
        <Loader2 v-if="busy.webdav" :size="16" class="spin" />
        <Toggle :model-value="b.webdav_enabled" :busy="busy.webdav" @update:model-value="(v) => toggle('webdav', v)" />
      </div>
    </Panel>

    <Panel :title="t('Storage')" :icon="Database" flush>
      <div class="item">
        <Gauge :size="18" class="lead" />
        <div class="grow">
          <div class="t-label-lg">{{ t('Quota') }}</div>
          <div class="t-body">{{ hasQuota(b) ? t('{used} of {total} used', { used: formatBytes(b.usage_bytes ?? 0), total: formatBytes(b.quota_bytes) }) : t('Unlimited') }}</div>
        </div>
        <button class="btn sm" @click="editQuota">{{ t('Change') }}</button>
      </div>
      <div class="item">
        <FolderCog :size="18" class="lead" />
        <div class="grow">
          <div class="t-label-lg">{{ t('Storage directory') }}</div>
          <div class="t-body ellipsis" :class="{ mono: b.storage_dir }" :title="b.storage_dir || ''">{{ b.storage_dir || t('Default data directory') }}</div>
        </div>
        <button class="btn sm" @click="editStorage">{{ t('Move') }}</button>
      </div>
      <div class="item">
        <Image :size="18" class="lead" />
        <div class="grow">
          <div class="t-label-lg">{{ t('Image variants') }}</div>
          <div class="t-body">{{ t('Regenerate optimized image variants for every object (runs in the background).') }}</div>
        </div>
        <button class="btn sm" :disabled="reprocessing" @click="reprocess"><Loader2 v-if="reprocessing" :size="13" class="spin" />{{ t('Reprocess') }}</button>
      </div>
    </Panel>

    <Panel
      v-if="multipart" :title="t('Incomplete uploads')" :icon="FileUp"
      :subtitle="s.uploads.length ? tn(s.uploads.length, '{n} upload holding {size}', '{n} uploads holding {size}', { size: formatBytes(uploadBytes) }) : undefined"
    >
      <template #actions>
        <button class="btn ghost icon sm" :title="t('Refresh')" :disabled="uploadsLoading" @click="loadUploads">
          <Loader2 v-if="uploadsLoading" :size="14" class="spin" /><RefreshCw v-else :size="14" />
        </button>
        <button v-if="s.uploads.length" class="btn ghost icon sm" :title="t('More')" @click="uploadsMenu"><MoreHorizontal :size="16" /></button>
      </template>
      <Callout v-if="uploadsError" tone="danger">{{ uploadsError }}</Callout>
      <div v-else-if="!s.uploadsLoaded" class="progress"><div class="progress-bar" /></div>
      <p v-else-if="!s.uploads.length" class="t-body">{{ t('None. Every multipart upload was completed or cleaned up.') }}</p>
      <div v-else class="uploads">
        <div v-for="u in s.uploads.slice(0, 50)" :key="u.upload_id" class="upload">
          <div class="grow">
            <div class="mono ellipsis selectable" :title="u.key">{{ u.key }}</div>
            <div class="t-body-sm" :title="formatDateTime(u.initiated)">
              {{ t('Started {when} · {n} parts · {size}', { when: formatRelative(u.initiated), n: u.parts, size: formatBytes(u.bytes ?? 0) }) }}
            </div>
          </div>
          <button class="btn ghost sm" :disabled="aborting === u.upload_id" @click="abortOne(u.upload_id)">
            <Loader2 v-if="aborting === u.upload_id" :size="13" class="spin" />{{ t('Abort') }}
          </button>
        </div>
        <p v-if="s.uploads.length > 50" class="t-body-sm">{{ t('…and {n} more', { n: s.uploads.length - 50 }) }}</p>
      </div>
    </Panel>

    <div class="card danger-zone">
      <div class="grow">
        <div class="t-title-sm">{{ t('Delete bucket') }}</div>
        <div class="t-body">{{ t('Removes the bucket and its access keys, rules and webhooks.') }}</div>
      </div>
      <button class="btn danger" @click="deleteBucketFlow(b.name)">{{ t('Delete bucket…') }}</button>
    </div>
  </div>
</template>

<style scoped>
.tab { display: flex; flex-direction: column; gap: var(--space-lg); }
.item { display: flex; align-items: center; gap: 14px; padding: 10px 12px; border-radius: var(--radius-md); }
.item + .item { border-top: 1px solid var(--border); border-radius: 0; }
.lead { color: var(--muted); }
.item .t-body { margin-top: 1px; }
.spin { animation: spin 0.9s linear infinite; color: var(--primary); }
@keyframes spin { to { transform: rotate(360deg); } }
.uploads { display: flex; flex-direction: column; gap: 2px; }
.upload { display: flex; align-items: center; gap: 10px; padding: 4px 0; }
.progress { height: 2px; background: var(--hover); overflow: hidden; border-radius: 2px; position: relative; }
.progress-bar { position: absolute; top: 0; bottom: 0; width: 30%; background: var(--primary); animation: slide 1.1s ease-in-out infinite; }
@keyframes slide { from { left: -30%; } to { left: 100%; } }
.danger-zone { display: flex; align-items: center; gap: 12px; padding: 18px; border-color: color-mix(in srgb, var(--danger) 40%, transparent); }
.danger-zone .btn { border-color: color-mix(in srgb, var(--danger) 50%, transparent); }
</style>
