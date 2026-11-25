// Uploads and downloads. The Rust side streams them (three at a time) and
// reports `transfer` events; this keeps the list the panel shows, the
// taskbar progress and the "batch finished" notification.

import { computed, ref } from 'vue';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWindow, ProgressBarStatus } from '@tauri-apps/api/window';
import { isPermissionGranted, requestPermission, sendNotification } from '@tauri-apps/plugin-notification';
import { ipc, type LocalFile } from '@/lib/ipc';
import { guessContentType } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import { pref } from './prefs';
import { has, serverId } from './session';

export type TransferState = 'waiting' | 'running' | 'done' | 'error' | 'cancelled';

export interface Transfer {
  id: string;
  kind: 'upload' | 'download';
  bucket: string;
  key: string;
  name: string;
  /** Local file (upload source or download destination). */
  path: string;
  size: number;
  done: number;
  state: TransferState;
  error?: string;
  resumeParts?: number;
  contentType?: string;
  versionId?: string | null;
}

export const transfers = ref<Transfer[]>([]);
export const panelOpen = ref(false);
/** Bumped when uploads finish into a bucket folder (the Files tab refreshes). */
export const uploadedInto = ref<{ bucket: string; prefix: string; at: number } | null>(null);

let seq = 0;
const newId = () => `t${Date.now().toString(36)}${(seq++).toString(36)}`;

export const active = computed(() => transfers.value.filter((x) => x.state === 'waiting' || x.state === 'running'));
export const failed = computed(() => transfers.value.filter((x) => x.state === 'error'));
export const overall = computed(() => {
  const list = active.value;
  const total = list.reduce((s, x) => s + x.size, 0);
  const done = list.reduce((s, x) => s + Math.min(x.done, x.size), 0);
  return total > 0 ? done / total : 0;
});

function start(x: Transfer) {
  const server = serverId.value;
  if (!server) return;
  x.state = 'waiting';
  x.error = undefined;
  if (x.kind === 'upload') {
    void ipc.uploadStart({ id: x.id, server, bucket: x.bucket, key: x.key, path: x.path, contentType: x.contentType ?? 'application/octet-stream', multipart: has('multipart') });
  } else {
    void ipc.downloadStart({ id: x.id, server, bucket: x.bucket, key: x.key, versionId: x.versionId ?? null, dest: x.path, size: x.size });
  }
}

/** Queues local files under `prefix` (each file's `rel` becomes the key suffix). */
export function enqueueUploads(bucket: string, prefix: string, files: LocalFile[]) {
  for (const f of files) {
    const key = prefix + f.rel;
    const x: Transfer = { id: newId(), kind: 'upload', bucket, key, name: f.rel.split('/').pop() ?? f.rel, path: f.path, size: f.size, done: 0, state: 'waiting', contentType: guessContentType(f.rel) };
    transfers.value.unshift(x);
    start(transfers.value[0]);
  }
  if (files.length) panelOpen.value = true;
}

export function enqueueDownload(bucket: string, key: string, size: number, dest: string, versionId: string | null = null): string {
  const x: Transfer = { id: newId(), kind: 'download', bucket, key, name: key.split('/').pop() ?? key, path: dest, size, done: 0, state: 'waiting', versionId };
  transfers.value.unshift(x);
  start(transfers.value[0]);
  panelOpen.value = true;
  return x.id;
}

export function cancel(id: string) {
  void ipc.cancelTransfer(id);
}

export function cancelAll() {
  void ipc.cancelAllTransfers();
}

export function retry(id: string) {
  const x = transfers.value.find((v) => v.id === id);
  if (x && (x.state === 'error' || x.state === 'cancelled')) start(x);
}

/** Removes finished, failed and cancelled entries. */
export function clearFinished() {
  transfers.value = transfers.value.filter((x) => x.state === 'waiting' || x.state === 'running');
}

/** Called when the session ends: everything stops and the list empties. */
export function resetTransfers() {
  cancelAll();
  transfers.value = [];
  panelOpen.value = false;
  void setTaskbar();
}

/** Resolves when the given download finishes (true) or fails/cancels (false). */
export function whenDone(id: string): Promise<boolean> {
  return new Promise((resolve) => {
    const check = () => {
      const x = transfers.value.find((v) => v.id === id);
      if (!x || x.state === 'error' || x.state === 'cancelled') return resolve(false);
      if (x.state === 'done') return resolve(true);
      setTimeout(check, 150);
    };
    check();
  });
}

let batchStarted = 0;
let batchDone = 0;
let batchFailed = 0;

async function setTaskbar() {
  const w = getCurrentWindow();
  try {
    if (active.value.length === 0) await w.setProgressBar({ status: ProgressBarStatus.None });
    else await w.setProgressBar({ status: ProgressBarStatus.Normal, progress: Math.round(overall.value * 100) });
  } catch {
    /* not supported here */
  }
}

async function notifyBatch() {
  if (pref('notifications') === 'off' || batchStarted === 0) return;
  try {
    let ok = await isPermissionGranted();
    if (!ok) ok = (await requestPermission()) === 'granted';
    if (!ok) return;
    const body = batchFailed > 0 ? tn(batchFailed, '{n} transfer failed', '{n} transfers failed') : tn(batchDone, '{n} transfer finished', '{n} transfers finished');
    sendNotification({ title: t('Transfers complete'), body });
  } catch {
    /* no notifications here */
  }
}

let lastBar = 0;
void listen<{ id: string; state: TransferState; done: number; total: number; error?: string; resume_parts?: number }>('transfer', (e) => {
  const p = e.payload;
  const x = transfers.value.find((v) => v.id === p.id);
  if (!x) return;
  const wasActive = x.state === 'waiting' || x.state === 'running';
  if (x.state === 'waiting' && p.state === 'running' && batchStarted === batchDone + batchFailed) {
    batchStarted = 0;
    batchDone = 0;
    batchFailed = 0;
  }
  if (x.state === 'waiting' && p.state === 'running') batchStarted++;
  x.state = p.state;
  x.done = p.done;
  if (p.total) x.size = p.total;
  x.error = p.error;
  x.resumeParts = p.resume_parts;
  if (wasActive && p.state === 'done') batchDone++;
  if (wasActive && (p.state === 'error' || p.state === 'cancelled')) batchFailed += p.state === 'error' ? 1 : 0;
  if (p.state === 'done' && x.kind === 'upload') {
    uploadedInto.value = { bucket: x.bucket, prefix: x.key.slice(0, x.key.lastIndexOf('/') + 1), at: Date.now() };
  }
  if (Date.now() - lastBar > 250 || p.state !== 'running') {
    lastBar = Date.now();
    void setTaskbar();
  }
  if (p.state !== 'running' && active.value.length === 0) void notifyBatch();
});
