// The open session: which server, its status (features) and its buckets.
// One session at a time; `generation` changes with every new one so screens
// start fresh.

import { computed, ref, shallowRef } from 'vue';
import { listen } from '@tauri-apps/api/event';
import { ipc, type SessionInfo } from '@/lib/ipc';
import { adminApi, type AdminApi, type Bucket, type Feature, type ServerStatus } from '@/lib/api';
import { serverById } from './servers';
import { resetNav } from './nav';
import { compareVersions } from '@/lib/format';

export const serverId = ref<string | null>(null);
export const sessionInfo = ref<SessionInfo | null>(null);
export const status = shallowRef<ServerStatus | null>(null);
export const statusError = ref<string | null>(null);
export const connecting = ref<string | null>(null);
/** Why the last session ended (shown on the welcome screen). */
export const sessionError = ref<string | null>(null);
export const generation = ref(0);
export const buckets = ref<Bucket[]>([]);
export const bucketsLoaded = ref(false);
export const bucketsError = ref<string | null>(null);
/** A newer Cloodsy S3 release than the server runs. */
export const serverUpdate = ref<string | null>(null);

export const server = computed(() => serverById(serverId.value));
export const connected = computed(() => serverId.value !== null && sessionInfo.value !== null);
export const features = computed(() => new Set(status.value?.features ?? []));
export const has = (f: Feature) => features.value.has(f);
/** A server older than Admin API v2 (no features list at all). */
export const legacyServer = computed(() => status.value !== null && (status.value.features ?? []).length === 0);

let api: AdminApi | null = null;
/** The Admin API of the open session. */
export function useApi(): AdminApi {
  if (!api) throw new Error('not connected');
  return api;
}

export async function connect(id: string) {
  connecting.value = id;
  sessionError.value = null;
  try {
    const r = await ipc.connect(id);
    if (serverId.value && serverId.value !== id) await ipc.disconnect(serverId.value).catch(() => {});
    api = adminApi(id);
    serverId.value = id;
    sessionInfo.value = r.session;
    status.value = r.status as unknown as ServerStatus;
    statusError.value = null;
    buckets.value = [];
    bucketsLoaded.value = false;
    serverUpdate.value = null;
    resetNav();
    generation.value++;
    void loadBuckets();
    void checkServerUpdate();
  } finally {
    connecting.value = null;
  }
}

export async function disconnect(reason: string | null = null) {
  const id = serverId.value;
  serverId.value = null;
  sessionInfo.value = null;
  status.value = null;
  api = null;
  sessionError.value = reason;
  buckets.value = [];
  resetNav();
  generation.value++;
  if (id) await ipc.disconnect(id).catch(() => {});
}

export async function refreshStatus() {
  if (!api) return;
  try {
    status.value = await api.status();
    statusError.value = null;
    if (serverId.value) sessionInfo.value = await ipc.sessionInfo(serverId.value);
  } catch (e) {
    statusError.value = (e as Error).message;
  }
}

export async function loadBuckets() {
  if (!api) return;
  try {
    buckets.value = (await api.buckets()).sort((a, b) => a.name.localeCompare(b.name));
    bucketsError.value = null;
  } catch (e) {
    bucketsError.value = (e as Error).message;
  } finally {
    bucketsLoaded.value = true;
  }
}

/** After the signed-in admin changed their own password. */
export async function ownPasswordChanged(password: string) {
  if (serverId.value) sessionInfo.value = await ipc.passwordChanged(serverId.value, password);
}

/** GitHub's latest Cloodsy S3 release vs the server's version (skipped for dev builds). */
async function checkServerUpdate() {
  const v = status.value?.version ?? '';
  if (!v || v === 'dev' || v.includes('dev')) return;
  try {
    const r = await ipc.githubLatest('onaonbir/Cloodsy-S3', 6);
    setServerUpdate(r?.tag ?? null);
  } catch {
    /* offline: no notice */
  }
}

export function setServerUpdate(latest: string | null) {
  const v = status.value?.version ?? '';
  serverUpdate.value = latest && v && compareVersions(v, latest) < 0 ? latest : null;
}

// The Rust side dropped the session (renewal failed).
void listen<{ server_id: string; message: string }>('session-expired', (e) => {
  if (e.payload.server_id === serverId.value) void disconnect(e.payload.message);
});
