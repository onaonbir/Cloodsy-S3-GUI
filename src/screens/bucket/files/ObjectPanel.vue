<script setup lang="ts">
// Details of one object: preview, actions, facts, where it lives on disk and
// its metadata. A 380 px side panel in wide windows, else inside a dialog.
// (2.0 object_panel.dart)
import { computed, onBeforeUnmount, ref, shallowRef, watch } from 'vue';
import {
  CircleAlert, ClipboardCopy, Copy, Download, Eye, FolderInput, FolderSearch, History, Image as ImageIcon, Link, Music, Pencil, Play,
  Tags, Trash2, Video, X, FileText,
} from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import CopyValue from '@/components/ui/CopyValue.vue';
import { ipc } from '@/lib/ipc';
import type { ObjectInfo, S3Object } from '@/lib/api';
import { formatBytes, formatCount, formatDateTime, formatRelative, guessContentType } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import { has, server, serverId, status, useApi } from '@/stores/session';
import { enqueueDownload, whenDone } from '@/stores/transfers';
import { copyText, toast, toastError } from '@/stores/toasts';
import ImageViewer from './ImageViewer.vue';
import PdfViewer from './PdfViewer.vue';
import { fileIcon } from './icons';
import {
  MAX_IMAGE_BYTES, MAX_PDF_BYTES, MAX_TEXT_BYTES, MAX_TEXT_NO_RANGE, fileName, isAudio, isJson, prettyJson, previewKind,
} from './helpers';
import type { ObjectActions } from './types';

const props = defineProps<{ bucket: string; object: S3Object; actions: ObjectActions }>();
const emit = defineEmits<{ close: [] }>();

const o = computed(() => props.object);
const name = computed(() => fileName(o.value.key));
const kind = computed(() => previewKind(o.value.key, o.value.content_type ?? ''));
const canDownload = computed(() => has('object-download'));
const canInfo = computed(() => has('object-info'));

const info = shallowRef<ObjectInfo | null>(null);
const infoError = ref<string | null>(null);
const imageUrl = ref<string | null>(null);
const imageBroken = ref(false);
const text = ref<string | null>(null);
const textTruncated = ref(false);
const loadingPreview = ref(false);
const previewError = ref<string | null>(null);
const tooLarge = ref(false);
const opening = ref(false);
const pdfLoading = ref(false);
const pdfData = shallowRef<ArrayBuffer | null>(null);
const showImage = ref(false);
/** Local paths of server paths (when the server runs on this machine). */
const local = ref<Record<string, string | null>>({});
let loadSeq = 0;

function revokeImage() {
  if (imageUrl.value) URL.revokeObjectURL(imageUrl.value);
  imageUrl.value = null;
}

async function load() {
  const seq = ++loadSeq;
  const obj = o.value;
  info.value = null;
  infoError.value = null;
  revokeImage();
  imageBroken.value = false;
  text.value = null;
  textTruncated.value = false;
  previewError.value = null;
  tooLarge.value = false;
  loadingPreview.value = false;

  if (canInfo.value) {
    useApi()
      .objectInfo(props.bucket, obj.key)
      .then((i) => {
        if (seq !== loadSeq) return;
        info.value = i;
        void resolveLocal([i.disk_path, i.variant?.exists ? i.variant.disk_path : undefined]);
      })
      .catch((e: Error) => {
        if (seq === loadSeq) infoError.value = e.message;
      });
  }
  const sid = serverId.value;
  if (!canDownload.value || !sid) return;
  try {
    if (kind.value === 'image') {
      if (obj.size > MAX_IMAGE_BYTES) {
        tooLarge.value = true;
        return;
      }
      loadingPreview.value = true;
      const bytes = await ipc.readObject(sid, props.bucket, obj.key, null);
      if (seq !== loadSeq) return;
      const type = obj.content_type && obj.content_type.startsWith('image/') ? obj.content_type : guessContentType(obj.key);
      imageUrl.value = URL.createObjectURL(new Blob([bytes], { type }));
    } else if (kind.value === 'text') {
      // Without Range support the server sends everything: only read small objects then.
      if (!has('object-range') && obj.size > MAX_TEXT_NO_RANGE) {
        tooLarge.value = true;
        return;
      }
      loadingPreview.value = true;
      const bytes = await ipc.readObject(sid, props.bucket, obj.key, MAX_TEXT_BYTES);
      if (seq !== loadSeq) return;
      let s = new TextDecoder('utf-8', { fatal: false }).decode(bytes);
      const truncated = obj.size > bytes.byteLength;
      if (!truncated && isJson(obj.key, obj.content_type ?? '')) s = prettyJson(s);
      text.value = s;
      textTruncated.value = truncated;
    }
  } catch (e) {
    if (seq === loadSeq) previewError.value = (e as Error).message;
  } finally {
    if (seq === loadSeq) loadingPreview.value = false;
  }
}

async function resolveLocal(paths: (string | undefined)[]) {
  const st = status.value;
  const url = server.value?.url;
  if (!st?.host || !url) return;
  for (const p of paths) {
    if (!p || p in local.value) continue;
    try {
      const l = await ipc.localPath(url, st.host.os ?? '', st.host.hostname ?? '', st.host.wsl_distro ?? '', p);
      local.value = { ...local.value, [p]: l };
    } catch {
      local.value = { ...local.value, [p]: null };
    }
  }
}

watch(() => [o.value.key, o.value.etag, o.value.last_modified], load, { immediate: true });
onBeforeUnmount(() => {
  loadSeq++;
  revokeImage();
});

/**
 * Opens the object in the default app through a temp copy with the real
 * file name (the stored file carries the server's own suffix, so opening it
 * in place would pick the wrong application).
 */
async function openExternally() {
  if (opening.value) return;
  opening.value = true;
  try {
    const obj = o.value;
    const path = await ipc.previewPath(fileName(obj.key));
    const id = enqueueDownload(props.bucket, obj.key, obj.size, path, null);
    if (await whenDone(id)) await ipc.openPath(path);
  } catch (e) {
    toastError(e);
  } finally {
    opening.value = false;
  }
}

async function openPdf() {
  const sid = serverId.value;
  if (!sid || pdfLoading.value) return;
  pdfLoading.value = true;
  try {
    pdfData.value = await ipc.readObject(sid, props.bucket, o.value.key, null);
  } catch (e) {
    toastError(e);
  } finally {
    pdfLoading.value = false;
  }
}

function pdfExternal() {
  pdfData.value = null;
  void openExternally();
}

async function showInFolder(path: string) {
  try {
    await ipc.revealPath(path);
  } catch {
    toast(t('Could not open the file manager'), true);
  }
}

const versionCount = computed(() => {
  const v = info.value?.versions;
  return typeof v === 'number' ? v : Array.isArray(v) ? v.length : 0;
});
const contentType = computed(() => info.value?.content_type || o.value.content_type || '');
const metadata = computed(() => Object.entries(info.value?.metadata ?? {}));
const s3Uri = computed(() => `s3://${props.bucket}/${o.value.key}`);
const placeholderIcon = computed(() => {
  if (kind.value === 'media') return isAudio(o.value.key, o.value.content_type ?? '') ? Music : Video;
  if (kind.value === 'image') return ImageIcon;
  if (kind.value === 'pdf' || kind.value === 'text') return FileText;
  return fileIcon(o.value.key);
});
</script>

<template>
  <div class="panel">
    <header>
      <component :is="fileIcon(o.key)" :size="18" class="muted" />
      <span class="title grow selectable" :title="o.key">{{ name }}</span>
      <button class="btn ghost icon sm" :title="t('Close (Esc)')" @click="emit('close')"><X :size="16" /></button>
    </header>

    <div class="scroll">
      <!-- Preview -->
      <div v-if="!canDownload" class="frame placeholder">
        <component :is="fileIcon(o.key)" :size="30" />
        <span>{{ t('Preview needs a newer server') }}</span>
      </div>
      <div v-else-if="loadingPreview" class="frame placeholder"><span class="spinner" /></div>
      <div v-else-if="previewError" class="frame placeholder">
        <CircleAlert :size="30" />
        <span class="selectable">{{ previewError }}</span>
        <button class="btn sm" @click="load">{{ t('Try again') }}</button>
      </div>
      <template v-else-if="kind === 'image'">
        <div v-if="imageUrl && !imageBroken" class="frame image" :title="t('Click to enlarge')" @click="showImage = true">
          <img :src="imageUrl" :alt="name" @error="imageBroken = true" />
        </div>
        <div v-else-if="imageBroken" class="frame placeholder">
          <ImageIcon :size="30" />
          <span>{{ t('Not a decodable image') }}</span>
          <button class="btn sm" :disabled="opening" @click="openExternally">{{ t('Open with default app') }}</button>
        </div>
        <div v-else class="frame placeholder">
          <ImageIcon :size="30" />
          <span>{{ t('Too large to preview ({size})', { size: formatBytes(o.size) }) }}</span>
          <button class="btn sm" :disabled="opening" @click="openExternally">{{ t('Open') }}</button>
        </div>
      </template>
      <template v-else-if="kind === 'text'">
        <div v-if="text !== null" class="frame text">
          <pre class="selectable">{{ text }}</pre>
          <div v-if="textTruncated" class="truncated">{{ t('Showing the first {size}', { size: formatBytes(MAX_TEXT_BYTES) }) }}</div>
          <div class="text-actions">
            <button class="btn ghost sm" @click="copyText(text, t('Text'))"><Copy :size="14" />{{ t('Copy') }}</button>
          </div>
        </div>
        <div v-else class="frame placeholder">
          <FileText :size="30" />
          <span v-if="tooLarge">{{ t('Too large to preview ({size})', { size: formatBytes(o.size) }) }}</span>
          <button class="btn sm" :disabled="opening" @click="openExternally">{{ t('Open with default app') }}</button>
        </div>
      </template>
      <div v-else-if="kind === 'pdf'" class="frame placeholder">
        <FileText :size="30" />
        <span>{{ t('PDF document') }}</span>
        <button v-if="o.size <= MAX_PDF_BYTES" class="btn primary sm" :disabled="pdfLoading" @click="openPdf">
          <span v-if="pdfLoading" class="spinner small" /><Eye v-else :size="15" />{{ t('Preview') }}
        </button>
        <button class="btn sm" :class="{ primary: o.size > MAX_PDF_BYTES }" :disabled="opening" @click="openExternally">{{ t('Open with default app') }}</button>
      </div>
      <div v-else-if="kind === 'media'" class="frame placeholder">
        <component :is="placeholderIcon" :size="30" />
        <span>{{ t('Plays in your default media player') }}</span>
        <button class="btn primary sm" :disabled="opening" @click="openExternally"><Play :size="15" />{{ t('Open') }}</button>
      </div>
      <div v-else class="frame placeholder">
        <component :is="placeholderIcon" :size="30" />
        <span>{{ t('No preview for this type') }}</span>
        <button class="btn sm" :disabled="opening" @click="openExternally">{{ t('Open with default app') }}</button>
      </div>

      <!-- Actions -->
      <div class="chips">
        <button v-if="actions.download" class="btn primary sm" @click="actions.download(o)"><Download :size="15" />{{ t('Download') }}</button>
        <button class="btn sm" @click="actions.share(o)"><Link :size="15" />{{ t('Share') }}</button>
        <button v-if="actions.rename" class="btn sm" @click="actions.rename(o)"><Pencil :size="15" />{{ t('Rename') }}</button>
        <button v-if="actions.moveCopy" class="btn sm" @click="actions.moveCopy(o)"><FolderInput :size="15" />{{ t('Move / copy') }}</button>
        <button v-if="actions.editMetadata" class="btn sm" @click="actions.editMetadata(o, info)"><Tags :size="15" />{{ t('Metadata') }}</button>
        <button v-if="actions.versions" class="btn sm" @click="actions.versions(o)"><History :size="15" />{{ t('Versions') }}</button>
        <button class="btn sm danger" @click="actions.delete(o)"><Trash2 :size="15" />{{ t('Delete') }}</button>
      </div>

      <!-- Object -->
      <section>
        <h3>{{ t('Object') }}</h3>
        <dl>
          <dt>{{ t('Size') }}</dt>
          <dd>{{ formatBytes(o.size) }} <span class="subtle">({{ formatCount(o.size) }} B)</span></dd>
          <dt>{{ t('Type') }}</dt>
          <dd class="mono">{{ contentType || '—' }}</dd>
          <dt>{{ t('Modified') }}</dt>
          <dd>{{ formatDateTime(o.last_modified) }} · {{ formatRelative(o.last_modified) }}</dd>
          <dt>{{ t('ETag') }}</dt>
          <dd class="mono">{{ o.etag || '—' }}</dd>
          <template v-if="info?.version_id">
            <dt>{{ t('Version') }}</dt>
            <dd class="mono">{{ info.version_id }}</dd>
          </template>
        </dl>
        <div class="field">
          <label>{{ t('Key') }}</label>
          <CopyValue :value="o.key" :label="t('Key')" />
        </div>
        <div class="field">
          <label>{{ t('S3 URI') }}</label>
          <CopyValue :value="s3Uri" :label="t('S3 URI')" />
        </div>
      </section>

      <!-- On disk -->
      <section>
        <h3>{{ t('On disk') }}</h3>
        <p v-if="!canInfo" class="t-body-sm">{{ t('Update the server to see where this object is stored.') }}</p>
        <Callout v-else-if="infoError" tone="danger">{{ infoError }}</Callout>
        <div v-else-if="!info" class="progress"><div /></div>
        <template v-else>
          <p v-if="!info.disk_path" class="t-body-sm">{{ t('No file (the current version is a delete marker).') }}</p>
          <div v-else class="field">
            <label>{{ t('File') }}</label>
            <CopyValue :value="info.disk_path" :label="t('Path')" />
            <div v-if="local[info.disk_path]" class="disk-actions">
              <button class="btn ghost sm" @click="showInFolder(local[info.disk_path]!)"><FolderSearch :size="15" />{{ t('Show in folder') }}</button>
              <button class="btn ghost sm" @click="copyText(local[info.disk_path]!, t('Local path'))"><ClipboardCopy :size="15" />{{ t('Copy local path') }}</button>
            </div>
          </div>
          <div v-if="info.variant?.exists && info.variant.disk_path" class="field">
            <label>{{ t('Optimized variant · {size}', { size: formatBytes(info.variant.size ?? 0) }) }}</label>
            <CopyValue :value="info.variant.disk_path" :label="t('Path')" />
            <div v-if="local[info.variant.disk_path]" class="disk-actions">
              <button class="btn ghost sm" @click="showInFolder(local[info.variant.disk_path]!)"><FolderSearch :size="15" />{{ t('Show in folder') }}</button>
              <button class="btn ghost sm" @click="copyText(local[info.variant.disk_path]!, t('Local path'))"><ClipboardCopy :size="15" />{{ t('Copy local path') }}</button>
            </div>
          </div>
          <p v-if="versionCount > 1" class="t-body-sm">{{ tn(versionCount, '{n} version is kept; see Versions for each file.', '{n} versions are kept; see Versions for each file.') }}</p>
        </template>
      </section>

      <!-- Metadata -->
      <section v-if="metadata.length">
        <h3>{{ t('Metadata') }}</h3>
        <dl>
          <template v-for="[k, v] in metadata" :key="k">
            <dt class="mono">{{ k }}</dt>
            <dd class="mono">{{ v }}</dd>
          </template>
        </dl>
      </section>
    </div>

    <ImageViewer v-if="showImage && imageUrl" :src="imageUrl" :name="name" @close="showImage = false" />
    <PdfViewer v-if="pdfData" :data="pdfData" :name="name" @close="pdfData = null" @open-external="pdfExternal" />
  </div>
</template>

<style scoped>
.panel { height: 100%; display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; min-width: 0; }
header { display: flex; align-items: center; gap: 10px; padding: 10px 6px 10px 16px; border-bottom: 1px solid var(--border); }
.title { font-weight: 600; font-size: 13.5px; line-height: 1.3; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; word-break: break-word; }
.scroll { flex: 1; min-height: 0; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 16px; }

.frame { background: var(--background); border: 1px solid var(--border); border-radius: var(--radius-md); overflow: hidden; flex-shrink: 0; }
.placeholder { min-height: 150px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; padding: 16px; color: var(--subtle); font-size: 12px; text-align: center; }
.placeholder span { max-width: 100%; overflow-wrap: anywhere; }
.placeholder .btn { margin-top: 2px; }
.image { display: grid; place-items: center; cursor: zoom-in; max-height: 260px; }
.image img { max-width: 100%; max-height: 258px; object-fit: contain; display: block; }
.text pre { margin: 0; padding: 12px; max-height: 280px; overflow: auto; font: 11.5px/1.45 var(--font-mono); color: var(--foreground); white-space: pre-wrap; word-break: break-word; }
.truncated { padding: 6px 12px; background: var(--hover); font-size: 12px; color: var(--subtle); border-top: 1px solid var(--border); }
.text-actions { display: flex; justify-content: flex-end; padding: 2px 4px; border-top: 1px solid var(--border); }

.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.chips .danger { border-color: color-mix(in srgb, var(--danger) 40%, transparent); }

section { display: flex; flex-direction: column; gap: 10px; }
h3 { font-size: 11px; font-weight: 600; letter-spacing: 0.6px; text-transform: uppercase; color: var(--subtle); }
dl { display: grid; grid-template-columns: max-content 1fr; gap: 6px 14px; margin: 0; font-size: 12.5px; }
dt { color: var(--muted); }
dd { margin: 0; min-width: 0; overflow-wrap: anywhere; user-select: text; }
dd.mono, dt.mono { font-size: 12px; }
.disk-actions { display: flex; flex-wrap: wrap; gap: 4px; }
.progress { height: 2px; border-radius: 2px; background: var(--hover); overflow: hidden; }
.progress div { width: 40%; height: 100%; background: var(--primary); animation: slide 1.1s ease-in-out infinite; }
.spinner { width: 22px; height: 22px; border-radius: 50%; border: 2.5px solid var(--primary); border-right-color: transparent; animation: spin 0.8s linear infinite; }
.spinner.small { width: 13px; height: 13px; border-width: 2px; border-color: currentColor; border-right-color: transparent; }
@keyframes spin { to { transform: rotate(360deg); } }
@keyframes slide { from { transform: translateX(-100%); } to { transform: translateX(250%); } }
</style>
