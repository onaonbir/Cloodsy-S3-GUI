<script setup lang="ts">
// Every version of one object: copy id, download, delete. Closes with true
// when something was deleted (the listing refreshes). (2.0 versions_dialog.dart)
import { onMounted, ref } from 'vue';
import { Copy, Download, File, FileX, Trash2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import type { ObjectVersion } from '@/lib/api';
import type { ApiError } from '@/lib/ipc';
import { confirm } from '@/lib/dialogs';
import { formatBytes, formatDateTime, formatRelative } from '@/lib/format';
import { t } from '@/lib/i18n';
import { useApi } from '@/stores/session';
import { copyText, runAction } from '@/stores/toasts';
import { isNullVersion } from './helpers';

const props = defineProps<{
  bucket: string;
  objectKey: string;
  onDownload?: (v: ObjectVersion, versionId: string) => void;
  done: (changed: boolean | null) => void;
}>();

const versions = ref<ObjectVersion[] | null>(null);
const error = ref<ApiError | null>(null);
let changed = false;

/** The id to send: S3's "null" for unversioned objects. */
const idOf = (v: ObjectVersion) => (isNullVersion(v.version_id) ? 'null' : v.version_id);

async function load() {
  error.value = null;
  try {
    versions.value = await useApi().versions(props.bucket, props.objectKey);
  } catch (e) {
    error.value = e as ApiError;
  }
}
onMounted(load);

async function remove(v: ObjectVersion) {
  const ok = await confirm({
    title: t('Delete version'),
    message: v.is_delete_marker
      ? t('Remove this delete marker? The previous version becomes the current one again.')
      : t('Permanently delete this version? This cannot be undone.'),
    detail: idOf(v),
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  const r = await runAction(
    async () => {
      await useApi().deleteObject(props.bucket, props.objectKey, idOf(v));
      return true;
    },
    v.is_delete_marker ? t('Delete marker removed') : t('Version deleted'),
  );
  if (r) {
    changed = true;
    await load();
  }
}

const close = () => props.done(changed);
</script>

<template>
  <Modal :width="620" @close="close">
    <template #header>
      <div class="head grow">
        <h2>{{ t('Versions') }}</h2>
        <div class="sub mono ellipsis selectable" :title="objectKey">{{ objectKey }}</div>
      </div>
    </template>

    <States v-if="error" kind="error" compact :message="error.message" :connection="error.status === 0" @retry="load" />
    <States v-else-if="!versions" kind="loading" compact />
    <p v-else-if="versions.length === 0" class="t-body">{{ t('No versions recorded.') }}</p>
    <div v-else class="list">
      <div v-for="v in versions" :key="v.version_id + v.last_modified" class="ver">
        <FileX v-if="v.is_delete_marker" :size="18" class="ic marker" />
        <File v-else :size="18" class="ic" />
        <div class="grow">
          <div class="row line">
            <span class="id mono ellipsis selectable" :title="v.version_id">{{ isNullVersion(v.version_id) ? t('null (unversioned)') : v.version_id }}</span>
            <Pill v-if="v.is_latest" tone="success">{{ t('Current') }}</Pill>
            <Pill v-if="v.is_delete_marker" tone="warning">{{ t('Delete marker') }}</Pill>
          </div>
          <div class="t-body-sm" :title="formatRelative(v.last_modified)">
            {{ v.is_delete_marker ? formatDateTime(v.last_modified) : `${formatBytes(v.size)} · ${formatDateTime(v.last_modified)}` }}
          </div>
        </div>
        <button class="btn ghost icon sm" :title="t('Copy version id')" @click="copyText(idOf(v), t('Version id'))"><Copy :size="15" /></button>
        <button v-if="onDownload && !v.is_delete_marker" class="btn ghost icon sm" :title="t('Download this version')" @click="onDownload(v, idOf(v))">
          <Download :size="15" />
        </button>
        <button class="btn ghost icon sm danger" :title="t('Delete version')" @click="remove(v)"><Trash2 :size="15" /></button>
      </div>
    </div>

    <template #footer>
      <button class="btn primary" @click="close">{{ t('Close') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.sub { color: var(--muted); font-size: 12px; margin-top: 2px; }
.list { border: 1px solid var(--border); border-radius: var(--radius-md); overflow: hidden; }
.ver { display: flex; align-items: center; gap: 10px; padding: 10px 6px 10px 14px; }
.ver + .ver { border-top: 1px solid var(--border); }
.ic { color: var(--muted); }
.ic.marker { color: var(--warning); }
.line { gap: 6px; margin-bottom: 3px; }
.id { font-size: 12px; color: var(--foreground); }
</style>
