<script setup lang="ts">
// The bucket's file browser: breadcrumbs, filter / server search, listing
// (500 per page, folders first, sortable), selection, uploads (pickers and
// drag & drop), downloads, object and folder actions, keyboard shortcuts and
// the object panel. (2.0 files_tab.dart + objects_controller.dart)
import { computed, nextTick, onActivated, onBeforeUnmount, onDeactivated, onMounted, ref, shallowRef, watch } from 'vue';
import {
  ArrowDown, ArrowUp, ChartPie, ChevronDown, ChevronRight, ChevronsDown, CloudUpload, Copy, CornerLeftUp, Download, Ellipsis, Files,
  Folder, FolderInput, FolderOpen, FolderPlus, FolderUp, History, Link, Package, PanelRight, Pencil, RefreshCw, Search, SearchX, Tags,
  Trash2, Upload, X,
} from 'lucide-vue-next';
import { open as openPicker, save as savePicker } from '@tauri-apps/plugin-dialog';
import { getCurrentWebview } from '@tauri-apps/api/webview';
import Callout from '@/components/ui/Callout.vue';
import States from '@/components/ui/States.vue';
import { ApiError, ipc } from '@/lib/ipc';
import type { ObjectInfo, ObjectVersion, S3Object } from '@/lib/api';
import { confirm, pending as pendingDialog, prompt } from '@/lib/dialogs';
import { formatBytes, formatCount, formatDateTime, formatRelative } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import { openMenu, SEP, type MenuItem } from '@/lib/menu';
import { openDialog, overlays } from '@/lib/overlay';
import { isMod, mod } from '@/lib/platform';
import { buckets, has, legacyServer, useApi } from '@/stores/session';
import { enqueueDownload, enqueueUploads, uploadedInto } from '@/stores/transfers';
import { copyText, runAction, toast, toastError } from '@/stores/toasts';
import { pref, setPref } from '@/stores/prefs';
import ObjectPanel from './files/ObjectPanel.vue';
import PanelDialog from './files/PanelDialog.vue';
import ShareDialog from './files/ShareDialog.vue';
import MoveCopyDialog from './files/MoveCopyDialog.vue';
import MetadataDialog from './files/MetadataDialog.vue';
import VersionsDialog from './files/VersionsDialog.vue';
import { fileIcon } from './files/icons';
import { rememberedPrefix, rememberPrefix } from './files/memory';
import type { ObjectActions } from './files/types';
import {
  UPLOAD_CONFIRM_FILES, dirName, fileName, folderName, joinPath, mergePage, nextSort, prefixOf, pruneSelection, segments as segmentsOf,
  uniquePath, upPrefix, visibleFolders, visibleObjects, type SortKey,
} from './files/helpers';

const props = defineProps<{ bucket: string; initialPrefix?: string }>();
const api = useApi();

// ------------------------------------------------------------ features

const canUpload = computed(() => has('object-upload'));
const canDownload = computed(() => has('object-download'));
const canCopy = computed(() => has('object-copy'));
const canSearch = computed(() => has('object-search'));
const canStats = computed(() => has('prefix-stats'));
const canMeta = computed(() => has('object-metadata'));
const canVersions = computed(() => has('object-versions'));

// ------------------------------------------------------------ layout

const root = ref<HTMLElement | null>(null);
const listEl = ref<HTMLElement | null>(null);
const searchEl = ref<HTMLInputElement | null>(null);
const crumbsEl = ref<HTMLElement | null>(null);
const winWidth = ref(window.innerWidth);
const sidePanel = computed(() => winWidth.value >= 1180);
const narrow = computed(() => winWidth.value < 760);
const fitHeight = ref<number | null>(null);

/** Fills the window below the tab (the list scrolls, not the page). */
function fit() {
  const el = root.value;
  if (!el) return;
  let scrolled = 0;
  let bottom = 24;
  for (let p = el.parentElement; p; p = p.parentElement) {
    if (bottom === 24 && p.classList.contains('page')) bottom = parseFloat(getComputedStyle(p).paddingBottom) || 24;
    const oy = getComputedStyle(p).overflowY;
    if (oy === 'auto' || oy === 'scroll') {
      scrolled = p.scrollTop;
      break;
    }
  }
  const top = el.getBoundingClientRect().top + scrolled;
  fitHeight.value = Math.max(420, Math.floor(window.innerHeight - top - bottom));
}

function onResize() {
  winWidth.value = window.innerWidth;
  fit();
}

// ------------------------------------------------------------ listing state

const prefix = ref(props.initialPrefix ?? rememberedPrefix(props.bucket) ?? '');
const rawFolders = shallowRef<string[]>([]);
const rawObjects = shallowRef<S3Object[]>([]);
const truncated = ref(false);
const nextMarker = ref('');
const loading = ref(false);
const loadingMore = ref(false);
const loadedOnce = ref(false);
const error = ref<ApiError | null>(null);
const filter = ref('');
const sort = ref<SortKey>('name');
const asc = ref(true);
const selected = ref(new Set<string>());
let requestSeq = 0;

// Server-side search (recursive under the open folder).
const searchQuery = ref('');
const searchResults = shallowRef<S3Object[]>([]);
const searchTruncated = ref(false);
const searchMarker = ref('');
const searching = ref(false);
let searchSeq = 0;

const searchMode = computed(() => searchQuery.value !== '');
const segs = computed(() => segmentsOf(prefix.value));
const folders = computed(() => (searchMode.value ? [] : visibleFolders(rawFolders.value, prefix.value, filter.value, sort.value, asc.value)));
const objects = computed(() => (searchMode.value ? searchResults.value : visibleObjects(rawObjects.value, prefix.value, filter.value, sort.value, asc.value)));
const hasMore = computed(() => (searchMode.value ? searchTruncated.value && searchMarker.value !== '' : truncated.value && nextMarker.value !== ''));
const moreBusy = computed(() => (searchMode.value ? searching.value : loadingMore.value));
const allSelected = computed(() => objects.value.length > 0 && objects.value.every((o) => selected.value.has(o.key)));
const someSelected = computed(() => !allSelected.value && objects.value.some((o) => selected.value.has(o.key)));
const bucketNames = computed(() => {
  const names = buckets.value.map((b) => b.name);
  return names.length ? names : [props.bucket];
});

async function refresh() {
  const seq = ++requestSeq;
  const p = prefix.value;
  loading.value = true;
  try {
    const page = await api.objects(props.bucket, p);
    if (seq !== requestSeq) return; // navigated meanwhile
    rawFolders.value = page.prefixes ?? [];
    rawObjects.value = page.objects ?? [];
    truncated.value = !!page.truncated;
    nextMarker.value = page.next_marker ?? '';
    // While searching the selection belongs to the results.
    if (!searchMode.value) selected.value = pruneSelection(selected.value, rawObjects.value);
    error.value = null;
  } catch (e) {
    if (seq !== requestSeq) return;
    const err = e instanceof ApiError ? e : new ApiError(0, String(e));
    // With a listing on screen a failed refresh only toasts.
    if (rawFolders.value.length || rawObjects.value.length) toastError(err);
    else error.value = err;
  } finally {
    if (seq === requestSeq) {
      loading.value = false;
      loadedOnce.value = true;
    }
  }
}

async function loadMore() {
  if (!hasMore.value || loadingMore.value) return;
  const seq = requestSeq;
  loadingMore.value = true;
  try {
    const page = await api.objects(props.bucket, prefix.value, nextMarker.value);
    if (seq !== requestSeq) return;
    const m = mergePage(rawFolders.value, rawObjects.value, page);
    rawFolders.value = m.folders;
    rawObjects.value = m.objects;
    truncated.value = !!page.truncated;
    nextMarker.value = page.next_marker ?? '';
  } catch (e) {
    if (seq === requestSeq) toastError(e);
  } finally {
    loadingMore.value = false;
  }
}

/** Reloads the folder and, while searching, the results (after changes). */
function reload() {
  void refresh();
  if (searchMode.value) void runSearch(searchQuery.value, false, true);
}

function resetSearch() {
  searchSeq++;
  searchQuery.value = '';
  searchResults.value = [];
  searchTruncated.value = false;
  searchMarker.value = '';
  searching.value = false;
}

/** Opens a folder ('' = bucket root). */
function openFolder(p: string) {
  prefix.value = p;
  rememberPrefix(props.bucket, p);
  filter.value = '';
  resetSearch();
  selected.value = new Set();
  focusedKey.value = null;
  dialogOpen.value = false;
  rawFolders.value = [];
  rawObjects.value = [];
  truncated.value = false;
  nextMarker.value = '';
  error.value = null;
  loadedOnce.value = false;
  void refresh();
}

function up() {
  if (prefix.value) openFolder(upPrefix(prefix.value));
}

/** `more` loads the next page; `keep` re-runs the same search without clearing the results first. */
async function runSearch(q: string, more = false, keep = false) {
  if (!more) {
    searchQuery.value = q.trim();
    if (!keep) {
      searchResults.value = [];
      searchMarker.value = '';
      searchTruncated.value = false;
    }
    if (!searchQuery.value) return;
  }
  const seq = more ? searchSeq : ++searchSeq;
  searching.value = true;
  try {
    const page = await api.search(props.bucket, searchQuery.value, prefix.value, more && searchMarker.value ? searchMarker.value : undefined);
    if (seq !== searchSeq) return;
    const list = page.objects ?? [];
    searchResults.value = more ? mergePage([], searchResults.value, { objects: list }).objects : list;
    if (keep) selected.value = pruneSelection(selected.value, searchResults.value);
    searchTruncated.value = !!page.truncated;
    searchMarker.value = page.next_marker ?? '';
  } catch (e) {
    if (seq === searchSeq) toastError(e);
  } finally {
    if (seq === searchSeq) searching.value = false;
  }
}

function clearSearch() {
  resetSearch();
}

function onFilterInput() {
  if (filter.value === '' && searchMode.value) clearSearch();
}

function onFilterKey(e: KeyboardEvent) {
  if (e.key === 'Enter' && canSearch.value) {
    e.preventDefault();
    void runSearch(filter.value);
  } else if (e.key === 'Escape') {
    e.preventDefault();
    if (filter.value || searchMode.value) clearFilter();
    else focusList();
  } else if (e.key === 'ArrowDown') {
    e.preventDefault();
    focusList();
  }
}

function clearFilter() {
  filter.value = '';
  clearSearch();
}

function setSort(s: SortKey) {
  if (searchMode.value) return;
  const n = nextSort(sort.value, asc.value, s);
  sort.value = n.sort;
  asc.value = n.asc;
}

// ------------------------------------------------------------ selection & focus

const focusedKey = ref<string | null>(null);
/** Narrow windows: the panel is open as a dialog. */
const dialogOpen = ref(false);
/** Bumped to make the panel reload (metadata saved, versions changed). */
const panelNonce = ref(0);
const focusedObj = computed(() => (focusedKey.value ? objects.value.find((o) => o.key === focusedKey.value) ?? null : null));

function toggleSelected(key: string, on?: boolean) {
  const s = new Set(selected.value);
  if (on ?? !s.has(key)) s.add(key);
  else s.delete(key);
  selected.value = s;
}

function selectAllVisible(on: boolean) {
  const s = new Set(selected.value);
  for (const o of objects.value) on ? s.add(o.key) : s.delete(o.key);
  selected.value = s;
}

function clearSelection() {
  selected.value = new Set();
}

function focusList() {
  listEl.value?.focus({ preventScroll: true });
}

/** Click on an object: the side panel, or the panel dialog in narrow windows. */
function showDetails(o: S3Object) {
  focusedKey.value = o.key;
  if (!sidePanel.value) dialogOpen.value = true;
  focusList();
}

function closePanel() {
  dialogOpen.value = false;
  if (sidePanel.value) focusedKey.value = null;
  focusList();
}

function onRowClick(e: MouseEvent, o: S3Object) {
  if (isMod(e)) toggleSelected(o.key);
  else showDetails(o);
}

function scrollFocusedIntoView() {
  void nextTick(() => listEl.value?.querySelector('.r.focused')?.scrollIntoView({ block: 'nearest' }));
}

function moveFocus(delta: number) {
  const list = objects.value;
  if (!list.length) return;
  const i = focusedKey.value ? list.findIndex((o) => o.key === focusedKey.value) : -1;
  const next = i < 0 ? (delta > 0 ? 0 : list.length - 1) : Math.min(list.length - 1, Math.max(0, i + delta));
  focusedKey.value = list[next].key;
  scrollFocusedIntoView();
}

// The panel closes when its object leaves the listing (deleted, moved).
watch(focusedObj, (o) => {
  if (!o) dialogOpen.value = false;
});

// ------------------------------------------------------------ uploads

const dragging = ref(false);
const active = ref(true);

async function pickFiles() {
  if (!canUpload.value) return;
  try {
    const r = await openPicker({ multiple: true, defaultPath: pref('last_upload_dir') || undefined, title: t('Upload files…') });
    const paths = !r ? [] : Array.isArray(r) ? r : [r];
    if (!paths.length) return;
    void setPref('last_upload_dir', dirName(paths[0]));
    await uploadPaths(paths);
  } catch (e) {
    toastError(e);
  }
}

async function pickFolder() {
  if (!canUpload.value) return;
  try {
    const r = await openPicker({ directory: true, multiple: false, defaultPath: pref('last_upload_dir') || undefined, title: t('Upload folder…') });
    const dir = Array.isArray(r) ? r[0] : r;
    if (!dir) return;
    void setPref('last_upload_dir', dirName(dir));
    await uploadPaths([dir]);
  } catch (e) {
    toastError(e);
  }
}

/** Files and folders (recursive, keeping relative paths) into the open folder. */
async function uploadPaths(paths: string[]) {
  const into = prefix.value;
  const files = await ipc.walk(paths);
  if (!files.length) {
    toast(t('Nothing to upload'));
    return;
  }
  if (files.length > UPLOAD_CONFIRM_FILES) {
    const ok = await confirm({
      title: t('Upload {n} files?', { n: formatCount(files.length) }),
      message: t('They will be uploaded into “/{p}”.', { p: into }),
      confirmLabel: t('Upload'),
    });
    if (!ok) return;
  }
  enqueueUploads(props.bucket, into, files);
}

function uploadMenu(e: MouseEvent) {
  openMenu(e, [
    { label: t('Upload files…'), icon: Files, shortcut: `${mod}+U`, action: () => void pickFiles() },
    { label: t('Upload folder…'), icon: FolderUp, action: () => void pickFolder() },
  ]);
}

async function newFolder() {
  const name = await prompt({
    title: t('New folder'),
    label: t('Folder name'),
    confirmLabel: t('Create'),
    validate: (v) => (v.includes('/') ? t('Use a single name without “/”') : null),
  });
  if (name === null) return;
  const clean = name.trim().replace(/^\/+|\/+$/g, '');
  if (!clean) return;
  await runAction(async () => {
    await api.createFolder(props.bucket, `${prefix.value}${clean}/`);
    await refresh();
  }, t('Folder “{name}” created', { name: clean }));
}

// Refresh after uploads into the open folder (or below it) finish.
let uploadTimer: number | undefined;
watch(uploadedInto, (u) => {
  if (!u || u.bucket !== props.bucket || !u.prefix.startsWith(prefix.value)) return;
  clearTimeout(uploadTimer);
  uploadTimer = window.setTimeout(reload, 600);
});

// ------------------------------------------------------------ downloads

async function download(o: S3Object, versionId: string | null = null, size = o.size) {
  if (!canDownload.value) return;
  try {
    const last = pref('last_download_dir');
    const name = fileName(o.key);
    const path = await savePicker({ defaultPath: last ? joinPath(last, name) : name, title: t('Download') });
    if (!path) return;
    void setPref('last_download_dir', dirName(path));
    enqueueDownload(props.bucket, o.key, size, path, versionId);
  } catch (e) {
    toastError(e);
  }
}

async function downloadSelected() {
  const objs = objects.value.filter((o) => selected.value.has(o.key));
  if (!objs.length || !canDownload.value) return;
  try {
    const r = await openPicker({ directory: true, multiple: false, defaultPath: pref('last_download_dir') || undefined, title: t('Download here') });
    const dir = Array.isArray(r) ? r[0] : r;
    if (!dir) return;
    void setPref('last_download_dir', dir);
    const used = new Set<string>();
    for (const o of objs) {
      const target = await uniquePath(dir, fileName(o.key), used, (p) => ipc.pathExists(p));
      enqueueDownload(props.bucket, o.key, o.size, target);
    }
    clearSelection();
  } catch (e) {
    toastError(e);
  }
}

// ------------------------------------------------------------ object actions

function share(o: S3Object) {
  void openDialog(ShareDialog, { bucket: props.bucket, objectKey: o.key });
}

const destLabel = (destBucket: string, dest: string) => `${destBucket === props.bucket ? '' : `${destBucket}/`}${dest}`;

async function copyOne(srcKey: string, destBucket: string, dest: string, move: boolean): Promise<string> {
  try {
    await api.copy(props.bucket, srcKey, dest, move, destBucket);
  } catch (e) {
    reload();
    throw e;
  }
  if (searchMode.value) reload();
  else await refresh();
  if (move) {
    toggleSelected(srcKey, false);
    // A renamed object stays in the panel when it is still listed here.
    if (focusedKey.value === srcKey) focusedKey.value = destBucket === props.bucket ? dest : null;
  }
  return move ? t('Moved to {dest}', { dest: destLabel(destBucket, dest) }) : t('Copied to {dest}', { dest: destLabel(destBucket, dest) });
}

function rename(o: S3Object) {
  if (!canCopy.value) return;
  void openDialog(MoveCopyDialog, {
    bucket: props.bucket, sourceKey: o.key, isFolder: false, renameOnly: true, buckets: bucketNames.value,
    run: (b: string, d: string) => copyOne(o.key, b, d, true),
  });
}

function moveCopy(o: S3Object) {
  void openDialog(MoveCopyDialog, {
    bucket: props.bucket, sourceKey: o.key, isFolder: false, buckets: bucketNames.value,
    run: (b: string, d: string, m: boolean) => copyOne(o.key, b, d, m),
  });
}

async function folderRun(src: string, destBucket: string, dest: string, move: boolean): Promise<string> {
  let r: { copied: number; failed: number };
  try {
    r = await api.copyPrefix(props.bucket, src, dest, move, destBucket);
  } finally {
    reload();
  }
  if (r.failed > 0) throw new Error(t('{ok} done, {failed} failed', { ok: r.copied, failed: r.failed }));
  return move ? tn(r.copied, '{n} object moved', '{n} objects moved') : tn(r.copied, '{n} object copied', '{n} objects copied');
}

function renameFolder(f: string) {
  void openDialog(MoveCopyDialog, {
    bucket: props.bucket, sourceKey: f, isFolder: true, renameOnly: true, buckets: bucketNames.value,
    run: (b: string, d: string) => folderRun(f, b, d, true),
  });
}

function moveCopyFolder(f: string) {
  void openDialog(MoveCopyDialog, {
    bucket: props.bucket, sourceKey: f, isFolder: true, buckets: bucketNames.value,
    run: (b: string, d: string, m: boolean) => folderRun(f, b, d, m),
  });
}

function moveCopySelected() {
  const keys = [...selected.value];
  if (!keys.length || !canCopy.value) return;
  void openDialog(MoveCopyDialog, {
    bucket: props.bucket, sourceKey: prefix.value, isFolder: true, count: keys.length, buckets: bucketNames.value,
    run: async (destBucket: string, dest: string, move: boolean) => {
      let failed = 0;
      let lastError: string | null = null;
      try {
        for (const k of keys) {
          try {
            await api.copy(props.bucket, k, `${dest}${fileName(k)}`, move, destBucket);
          } catch (e) {
            failed++;
            lastError = (e as Error).message;
          }
        }
      } finally {
        reload();
      }
      if (failed > 0) {
        throw new Error(t('{failed} of {total} failed', { failed, total: keys.length }) + (lastError ? `: ${lastError}` : ''));
      }
      clearSelection();
      return move ? tn(keys.length, '{n} object moved', '{n} objects moved') : tn(keys.length, '{n} object copied', '{n} objects copied');
    },
  });
}

async function editMetadata(o: S3Object, known?: ObjectInfo | null) {
  if (!canMeta.value) return;
  const loaded = await runAction(async () => {
    const [info, b] = await Promise.all([known ? Promise.resolve(known) : api.objectInfo(props.bucket, o.key), api.bucket(props.bucket)]);
    return { info, versioned: b.versioning === 'Enabled' };
  });
  if (!loaded) return;
  const saved = await openDialog<boolean>(MetadataDialog, {
    objectKey: o.key,
    contentType: loaded.info.content_type ?? '',
    metadata: loaded.info.metadata ?? {},
    versioned: loaded.versioned,
    save: async (ct: string, meta: Record<string, string>) => {
      await api.setMeta(props.bucket, o.key, ct, meta);
    },
  });
  if (saved) {
    toast(t('Metadata saved'));
    panelNonce.value++;
    reload();
  }
}

async function folderSize(p: string) {
  const r = await runAction(() => api.prefixStats(props.bucket, p));
  if (!r) return;
  const name = p === '' ? props.bucket : fileName(p);
  toast(t('{name}: {n} objects, {size}', { name, n: formatCount(r.objects), size: formatBytes(r.bytes) }));
}

async function versions(o: S3Object) {
  const changed = await openDialog<boolean>(VersionsDialog, {
    bucket: props.bucket,
    objectKey: o.key,
    onDownload: canDownload.value ? (v: ObjectVersion, id: string) => void download(o, id, v.size) : undefined,
  });
  if (changed) {
    panelNonce.value++;
    reload();
  }
}

// ------------------------------------------------------------ deletes

async function deleteObject(o: S3Object) {
  const name = fileName(o.key);
  const ok = await confirm({
    title: t('Delete object'),
    message: t('Permanently delete “{name}” including all of its versions?', { name }),
    detail: o.key,
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  const done = await runAction(async () => {
    await api.deleteObject(props.bucket, o.key);
    toggleSelected(o.key, false);
    reload();
    return true;
  }, t('“{name}” deleted', { name }));
  if (done && focusedKey.value === o.key) focusedKey.value = null;
}

async function deleteSelected() {
  const keys = [...selected.value];
  if (!keys.length) {
    if (focusedObj.value) await deleteObject(focusedObj.value);
    return;
  }
  const ok = await confirm({
    title: tn(keys.length, 'Delete {n} object', 'Delete {n} objects'),
    message: t('Permanently delete the selected objects including all of their versions?'),
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  const failed: string[] = [];
  let lastError: string | null = null;
  for (const k of keys) {
    try {
      await api.deleteObject(props.bucket, k);
    } catch (e) {
      failed.push(k);
      lastError = (e as Error).message;
    }
  }
  selected.value = new Set(failed);
  if (focusedKey.value && keys.includes(focusedKey.value) && !failed.includes(focusedKey.value)) focusedKey.value = null;
  reload();
  if (!failed.length) toast(tn(keys.length, '{n} object deleted', '{n} objects deleted'));
  else toast(t('{failed} of {total} could not be deleted', { failed: failed.length, total: keys.length }) + (lastError ? `: ${lastError}` : ''), true);
}

async function deleteFolder(f: string) {
  const name = folderName(prefix.value, f) || fileName(f);
  const ok = await confirm({
    title: t('Delete folder'),
    message: t('Delete “{name}” and everything inside it? All object versions under this folder are removed.', { name }),
    detail: f,
    typeToConfirm: name,
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  try {
    const r = await api.deletePrefix(props.bucket, f);
    if (r.failed > 0) toast(t('{ok} deleted, {failed} failed (see server log)', { ok: r.deleted, failed: r.failed }), true);
    else toast(tn(r.deleted, 'Folder “{name}” deleted ({n} object)', 'Folder “{name}” deleted ({n} objects)', { name }));
  } catch (e) {
    const err = e as ApiError;
    const d = (err.data as { deleted?: number; failed?: number } | undefined) ?? {};
    if (typeof d.deleted === 'number' && typeof d.failed === 'number') {
      toast(`${err.message} (${t('{ok} deleted, {failed} failed', { ok: d.deleted, failed: d.failed })})`, true);
    } else if (err.status !== -1) toastError(err);
  } finally {
    reload();
  }
}

// ------------------------------------------------------------ menus

const actions = computed<ObjectActions>(() => ({
  download: canDownload.value ? (o) => void download(o) : undefined,
  share,
  rename: canCopy.value ? rename : undefined,
  moveCopy: canCopy.value ? moveCopy : undefined,
  editMetadata: canMeta.value ? (o, info) => void editMetadata(o, info) : undefined,
  versions: canVersions.value ? (o) => void versions(o) : undefined,
  delete: (o) => void deleteObject(o),
}));

function objectMenu(e: MouseEvent, o: S3Object) {
  const a = actions.value;
  const items: MenuItem[] = [{ label: t('Details'), icon: PanelRight, action: () => showDetails(o) }];
  if (a.download) items.push({ label: t('Download'), icon: Download, shortcut: 'Enter', action: () => a.download!(o) });
  items.push({ label: t('Share link…'), icon: Link, action: () => a.share(o) });
  if (a.rename) items.push({ label: t('Rename…'), icon: Pencil, shortcut: 'F2', action: () => a.rename!(o) });
  if (a.moveCopy) items.push({ label: t('Move / copy…'), icon: FolderInput, action: () => a.moveCopy!(o) });
  if (a.editMetadata) items.push({ label: t('Edit metadata…'), icon: Tags, action: () => a.editMetadata!(o, null) });
  if (a.versions) items.push({ label: t('Versions…'), icon: History, action: () => a.versions!(o) });
  items.push({ label: t('Copy key'), icon: Copy, action: () => void copyText(o.key, t('Key')) });
  items.push(SEP, { label: t('Delete…'), icon: Trash2, danger: true, shortcut: t('Del'), action: () => a.delete(o) });
  openMenu(e, items);
}

function folderMenu(e: MouseEvent, f: string) {
  const items: MenuItem[] = [{ label: t('Open'), icon: FolderOpen, action: () => openFolder(f) }];
  if (canCopy.value) {
    items.push({ label: t('Rename…'), icon: Pencil, action: () => renameFolder(f) });
    items.push({ label: t('Move / copy…'), icon: FolderInput, action: () => moveCopyFolder(f) });
  }
  if (canStats.value) items.push({ label: t('Calculate size'), icon: ChartPie, action: () => void folderSize(f) });
  items.push({ label: t('Copy prefix'), icon: Copy, action: () => void copyText(f, t('Prefix')) });
  items.push(SEP, { label: t('Delete folder…'), icon: Trash2, danger: true, action: () => void deleteFolder(f) });
  openMenu(e, items);
}

// ------------------------------------------------------------ keyboard (list focused)

function onListKey(e: KeyboardEvent) {
  const target = e.target as HTMLElement;
  const onControl = target !== listEl.value && (target.tagName === 'INPUT' || target.tagName === 'BUTTON');
  const m = isMod(e);
  const k = e.key;
  const focused = focusedObj.value;
  let handled = true;

  if (m && k.toLowerCase() === 'a') selectAllVisible(true);
  else if (m && k.toLowerCase() === 'f') {
    searchEl.value?.focus();
    searchEl.value?.select();
  } else if (m && k.toLowerCase() === 'u' && canUpload.value) void pickFiles();
  else if (m) handled = false;
  else if (k === 'Delete') void deleteSelected();
  else if (k === 'Escape') {
    if (selected.value.size) clearSelection();
    else if (searchMode.value) clearFilter();
    else if (focusedKey.value) focusedKey.value = null;
    else handled = false;
  } else if (k === 'F5') reload();
  else if (k === 'Backspace' || (e.altKey && k === 'ArrowUp')) up();
  else if (k === 'ArrowDown') moveFocus(1);
  else if (k === 'ArrowUp') moveFocus(-1);
  else if (k === ' ' && !onControl) {
    if (focused) toggleSelected(focused.key);
  } else if (k === 'F2' && canCopy.value) {
    if (focused) rename(focused);
  } else if (k === 'Enter' && !onControl && canDownload.value) {
    if (focused) void download(focused);
  } else handled = false;

  if (handled) {
    e.preventDefault();
    e.stopPropagation();
  }
}

// ------------------------------------------------------------ drag & drop

const dialogUp = () => overlays.value.length > 0 || pendingDialog.value !== null;
let unlistenDrop: (() => void) | null = null;
let alive = true;

function listenDrops() {
  getCurrentWebview()
    .onDragDropEvent((ev) => {
      const p = ev.payload;
      if (!active.value || !canUpload.value) return;
      if (p.type === 'enter') dragging.value = p.paths.length > 0 && !dialogUp();
      else if (p.type === 'leave') dragging.value = false;
      else if (p.type === 'drop') {
        const was = dragging.value;
        dragging.value = false;
        if (was && p.paths.length && !dialogUp()) void uploadPaths(p.paths).catch(toastError);
      }
    })
    .then((un) => {
      if (alive) unlistenDrop = un;
      else un();
    })
    .catch(() => {
      /* not in Tauri (tests) */
    });
}

// ------------------------------------------------------------ lifecycle

let ro: ResizeObserver | null = null;

onMounted(() => {
  window.addEventListener('resize', onResize);
  listenDrops();
  void refresh();
  void nextTick(() => {
    fit();
    requestAnimationFrame(fit);
    focusList();
    if (root.value?.parentElement) {
      ro = new ResizeObserver(() => fit());
      ro.observe(root.value.parentElement);
    }
  });
});

onBeforeUnmount(() => {
  alive = false;
  unlistenDrop?.();
  ro?.disconnect();
  clearTimeout(uploadTimer);
  window.removeEventListener('resize', onResize);
  requestSeq++;
  searchSeq++;
});

onActivated(() => {
  active.value = true;
  fit();
  void refresh();
});
onDeactivated(() => {
  active.value = false;
  dragging.value = false;
});

// Another screen asked for a folder (palette, overview, …).
watch(
  () => props.initialPrefix,
  (p) => {
    if (p !== undefined && p !== prefix.value) openFolder(p);
  },
);

// Keep the open folder visible at the end of long breadcrumbs.
watch(prefix, () => void nextTick(() => crumbsEl.value && (crumbsEl.value.scrollLeft = crumbsEl.value.scrollWidth)));

// A wide window shows the side panel instead of the dialog.
watch(sidePanel, (wide) => {
  if (wide) dialogOpen.value = false;
});

const emptyTitle = computed(() => {
  if (searchMode.value) return t('No objects match “{q}”', { q: searchQuery.value });
  if (filter.value.trim()) return t('Nothing matches “{q}”', { q: filter.value.trim() });
  return t('This folder is empty');
});
const emptyMessage = computed(() => {
  if (searchMode.value) return t('Searched every key under /{p}.', { p: prefix.value });
  if (filter.value.trim()) return canSearch.value ? t('Press Enter to search all subfolders.') : undefined;
  return canUpload.value ? t('Drop files or folders here, or use Upload.') : undefined;
});
const rowName = (o: S3Object) => (searchMode.value ? o.key.slice(prefix.value.length) : fileName(o.key));
</script>

<template>
  <div ref="root" class="files" :style="fitHeight ? { height: `${fitHeight}px` } : undefined">
    <!-- Toolbar -->
    <div class="toolbar">
      <nav ref="crumbsEl" class="crumbs" :aria-label="t('Folder')">
        <button class="crumb" :class="{ active: segs.length === 0 }" :disabled="segs.length === 0" @click="openFolder('')">
          <Package :size="14" class="crumb-icon" />{{ bucket }}
        </button>
        <template v-for="(s, i) in segs" :key="i">
          <ChevronRight :size="14" class="subtle" />
          <button class="crumb" :class="{ active: i === segs.length - 1 }" :disabled="i === segs.length - 1" @click="openFolder(prefixOf(segs, i + 1))">{{ s }}</button>
        </template>
      </nav>

      <div class="tools">
        <template v-if="selected.size">
          <span class="t-label-lg">{{ tn(selected.size, '{n} selected', '{n} selected') }}</span>
          <button class="btn ghost" @click="clearSelection">{{ t('Clear') }}</button>
          <button v-if="canDownload" class="btn" @click="downloadSelected"><Download :size="15" />{{ t('Download') }}</button>
          <button v-if="canCopy" class="btn" @click="moveCopySelected"><FolderInput :size="15" />{{ t('Move / copy') }}</button>
          <button class="btn danger solid" @click="deleteSelected"><Trash2 :size="15" />{{ t('Delete') }}</button>
        </template>
        <template v-else>
          <div class="search">
            <Search :size="15" class="search-icon" />
            <input
              ref="searchEl"
              v-model="filter"
              class="input"
              spellcheck="false"
              :placeholder="canSearch ? t('Filter · Enter searches all subfolders') : t('Filter this folder')"
              @input="onFilterInput"
              @keydown="onFilterKey"
            />
            <button v-if="filter" class="btn ghost icon sm clear" :title="t('Clear')" @click="clearFilter"><X :size="14" /></button>
          </div>
          <button class="btn ghost icon" :title="t('Refresh (F5)')" :disabled="loading" @click="reload">
            <RefreshCw :size="16" :class="{ spin: loading }" />
          </button>
          <button v-if="canStats" class="btn ghost icon" :title="t('Size of this folder')" @click="folderSize(prefix)"><ChartPie :size="16" /></button>
          <button v-if="canUpload" class="btn" @click="newFolder"><FolderPlus :size="15" />{{ t('New folder') }}</button>
          <div v-if="canUpload" class="split">
            <button class="btn primary" :title="`${t('Upload files…')} (${mod}+U)`" @click="pickFiles"><Upload :size="15" />{{ t('Upload') }}</button>
            <button class="btn primary more" :title="t('More upload options')" @click="uploadMenu"><ChevronDown :size="15" /></button>
          </div>
        </template>
      </div>
    </div>

    <Callout v-if="legacyServer">{{ t('Upload and download need Cloodsy S3 with the object API (newer than this server). Browsing and deleting still work.') }}</Callout>

    <div class="main">
      <!-- Listing -->
      <div ref="listEl" class="list" :class="{ narrow }" tabindex="0" @keydown="onListKey">
        <div class="r head">
          <span class="c-check">
            <input
              type="checkbox"
              class="cb"
              :checked="allSelected"
              :indeterminate="someSelected"
              :disabled="objects.length === 0"
              :aria-label="t('Select all')"
              @change="selectAllVisible(($event.target as HTMLInputElement).checked)"
            />
          </span>
          <span />
          <button class="sort" :class="{ on: sort === 'name' && !searchMode }" :disabled="searchMode" @click="setSort('name')">
            {{ searchMode ? t('Key') : t('Name') }}
            <template v-if="sort === 'name' && !searchMode"><ArrowUp v-if="asc" :size="12" /><ArrowDown v-else :size="12" /></template>
          </button>
          <button class="sort end" :class="{ on: sort === 'size' && !searchMode }" :disabled="searchMode" @click="setSort('size')">
            {{ t('Size') }}
            <template v-if="sort === 'size' && !searchMode"><ArrowUp v-if="asc" :size="12" /><ArrowDown v-else :size="12" /></template>
          </button>
          <button v-if="!narrow" class="sort" :class="{ on: sort === 'modified' && !searchMode }" :disabled="searchMode" @click="setSort('modified')">
            {{ t('Modified') }}
            <template v-if="sort === 'modified' && !searchMode"><ArrowUp v-if="asc" :size="12" /><ArrowDown v-else :size="12" /></template>
          </button>
          <span />
        </div>
        <div class="progress" :class="{ on: (loading && loadedOnce) || (searching && objects.length > 0) }"><div /></div>

        <div class="body">
          <States v-if="!loadedOnce && !error" kind="loading" />
          <States v-else-if="error && !searchMode" kind="error" :message="error.message" :connection="error.isConnectionError" @retry="refresh" />
          <States v-else-if="searchMode && searching && objects.length === 0" kind="loading" />
          <template v-else>
            <div v-if="searchMode" class="banner">
              <Search :size="14" />
              <span class="grow t-label-lg">
                {{ t('{n} results for “{q}” in /{p}', { n: `${objects.length}${searchTruncated && searchMarker ? '+' : ''}`, q: searchQuery, p: prefix }) }}
              </span>
              <button class="btn ghost sm" @click="clearFilter">{{ t('Back to folder') }}</button>
            </div>

            <States v-if="folders.length === 0 && objects.length === 0" kind="empty" :title="emptyTitle" :message="emptyMessage">
              <template #icon><SearchX v-if="searchMode || filter.trim()" :size="22" /><FolderOpen v-else :size="22" /></template>
              <template v-if="!searchMode && !filter.trim() && canUpload" #actions>
                <button class="btn primary" @click="pickFiles"><Upload :size="15" />{{ t('Upload files') }}</button>
              </template>
            </States>

            <template v-else>
              <div v-if="!searchMode && prefix && !filter.trim()" class="r row-up" @click="up">
                <span /><CornerLeftUp :size="18" class="subtle" /><span class="name">..</span>
              </div>

              <div v-for="f in folders" :key="f" class="r folder" @click="openFolder(f)" @contextmenu="folderMenu($event, f)">
                <span />
                <Folder :size="18" class="folder-icon" />
                <span class="name ellipsis" :title="f">{{ folderName(prefix, f) }}</span>
                <span />
                <span v-if="!narrow" />
                <button class="btn ghost icon sm menu-btn" :title="t('Actions')" @click.stop="folderMenu($event, f)"><Ellipsis :size="16" /></button>
              </div>

              <div
                v-for="o in objects"
                :key="o.key"
                class="r obj"
                :class="{ selected: selected.has(o.key), focused: o.key === focusedObj?.key }"
                @click="onRowClick($event, o)"
                @dblclick="canDownload && download(o)"
                @contextmenu="objectMenu($event, o)"
              >
                <span class="c-check" @click.stop>
                  <input type="checkbox" class="cb" :checked="selected.has(o.key)" :aria-label="fileName(o.key)" @change="toggleSelected(o.key, ($event.target as HTMLInputElement).checked)" />
                </span>
                <component :is="fileIcon(o.key)" :size="18" class="muted" />
                <span class="name ellipsis" :title="o.key">{{ rowName(o) }}</span>
                <span class="size">{{ formatBytes(o.size) }}</span>
                <span v-if="!narrow" class="date" :title="formatRelative(o.last_modified)">{{ formatDateTime(o.last_modified) }}</span>
                <button class="btn ghost icon sm menu-btn" :title="t('Actions')" @click.stop="objectMenu($event, o)"><Ellipsis :size="16" /></button>
              </div>

              <div v-if="hasMore" class="more">
                <button class="btn" :disabled="moreBusy" @click="searchMode ? runSearch(searchQuery, true) : loadMore()">
                  <span v-if="moreBusy" class="spinner" /><ChevronsDown v-else :size="15" />
                  {{ moreBusy ? t('Loading…') : t('Load more') }}
                </button>
              </div>
            </template>
          </template>
        </div>
      </div>

      <!-- Side panel -->
      <div v-if="sidePanel && focusedObj" class="side" @keydown.esc.stop="closePanel">
        <ObjectPanel :key="`${focusedObj.key}:${panelNonce}`" :bucket="bucket" :object="focusedObj" :actions="actions" @close="closePanel" />
      </div>
    </div>

    <!-- Drop overlay -->
    <div v-if="dragging" class="drop">
      <CloudUpload :size="36" />
      <div class="t-title">{{ t('Drop to upload') }}</div>
      <div class="t-body">{{ t('into /{p}', { p: prefix }) }}</div>
    </div>

    <PanelDialog
      v-if="!sidePanel && dialogOpen && focusedObj"
      :key="`${focusedObj.key}:${panelNonce}`"
      :bucket="bucket"
      :object="focusedObj"
      :actions="actions"
      @close="closePanel"
    />
  </div>
</template>

<style scoped>
.files { position: relative; display: flex; flex-direction: column; gap: 12px; flex: 1 1 auto; min-height: 420px; min-width: 0; padding: 12px var(--page) 0; }

/* toolbar */
.toolbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; }
.crumbs { display: flex; align-items: center; gap: 2px; max-width: 560px; min-width: 0; overflow-x: auto; scrollbar-width: none; }
.crumbs::-webkit-scrollbar { display: none; }
.crumb { display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 6px; border: 0; border-radius: var(--radius-sm); background: none; color: var(--muted); font: 500 13px var(--font-sans); cursor: pointer; white-space: nowrap; }
.crumb:hover:not(:disabled) { background: var(--hover); color: var(--foreground); }
.crumb.active { color: var(--foreground); font-weight: 600; cursor: default; }
.crumb:disabled { opacity: 1; }
.crumb-icon { color: var(--muted); }
.crumb.active .crumb-icon { color: var(--primary); }
.tools { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.search { position: relative; width: 260px; }
.search .input { padding-left: 34px; padding-right: 32px; }
.search-icon { position: absolute; left: 11px; top: 50%; transform: translateY(-50%); color: var(--subtle); pointer-events: none; }
.search .clear { position: absolute; right: 4px; top: 50%; transform: translateY(-50%); }
.split { display: inline-flex; gap: 1px; }
.split .btn:first-child { border-top-right-radius: 0; border-bottom-right-radius: 0; }
.split .more { width: 32px; padding: 0; border-top-left-radius: 0; border-bottom-left-radius: 0; }
.spin { animation: spin 0.9s linear infinite; }

/* listing */
.main { flex: 1; min-height: 0; display: flex; gap: 14px; }
.list { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; outline: none; }
.list:focus-visible { border-color: var(--primary); box-shadow: 0 0 0 3px var(--primary-soft); }
.r { display: grid; grid-template-columns: 40px 30px minmax(0, 6fr) minmax(70px, 2fr) 24px minmax(120px, 3fr) 44px; align-items: center; min-height: 48px; padding: 0 8px; border-bottom: 1px solid var(--border); font-size: 14px; }
.r > :nth-child(5) { grid-column: 6; }
.list.narrow .r { grid-template-columns: 40px 30px minmax(0, 6fr) minmax(70px, 2fr) 44px; }
.list.narrow .r > :nth-child(5) { grid-column: auto; }
.r.head { min-height: 0; padding-top: 6px; padding-bottom: 6px; border-bottom: 1px solid var(--border); }
.body { flex: 1; min-height: 0; overflow-y: auto; padding-bottom: 16px; }
.body .r { cursor: default; content-visibility: auto; contain-intrinsic-size: auto 49px; }
.body .r:hover { background: var(--hover); }
.r.folder, .r.row-up { cursor: pointer; }
.r.selected, .r.focused, .r.selected:hover, .r.focused:hover { background: var(--selected); }
.r.focused { box-shadow: inset 2px 0 0 var(--primary); }
.c-check { display: grid; place-items: center; height: 100%; }
.cb { width: 15px; height: 15px; margin: 0; accent-color: var(--primary); cursor: pointer; }
.name { min-width: 0; }
.folder .name { font-weight: 600; }
.folder-icon { color: var(--folder); }
.size { text-align: right; font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; white-space: nowrap; }
.date { font-size: 13px; color: var(--muted); white-space: nowrap; font-variant-numeric: tabular-nums; }
.menu-btn { justify-self: center; color: var(--muted); }
.sort { display: inline-flex; align-items: center; gap: 3px; justify-self: start; padding: 4px 2px; border: 0; background: none; font: 600 11px var(--font-sans); letter-spacing: 0.6px; text-transform: uppercase; color: var(--subtle); cursor: pointer; border-radius: var(--radius-sm); }
.sort.end { justify-self: end; }
.sort:hover:not(:disabled), .sort.on { color: var(--foreground); }
.sort:disabled { cursor: default; }
.progress { height: 2px; overflow: hidden; flex-shrink: 0; }
.progress div { display: none; width: 35%; height: 100%; background: var(--primary); animation: slide 1.1s ease-in-out infinite; }
.progress.on div { display: block; }
.banner { display: flex; align-items: center; gap: 8px; padding: 6px 10px 6px 16px; background: var(--primary-soft); color: var(--primary); border-bottom: 1px solid var(--border); }
.banner .t-label-lg { color: var(--foreground); }
.more { display: grid; place-items: center; padding: 14px; }
.spinner { width: 13px; height: 13px; border-radius: 50%; border: 2px solid currentColor; border-right-color: transparent; animation: spin 0.8s linear infinite; }

.side { width: 380px; flex-shrink: 0; min-height: 0; }

/* drag & drop */
.drop { position: absolute; inset: 0; z-index: 20; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; background: var(--primary-soft); border: 2px solid var(--primary); border-radius: var(--radius-xl); color: var(--primary); pointer-events: none; backdrop-filter: blur(1px); }
.drop .t-title { color: var(--foreground); margin-top: 4px; }

@keyframes spin { to { transform: rotate(360deg); } }
@keyframes slide { from { transform: translateX(-100%); } to { transform: translateX(300%); } }
</style>
