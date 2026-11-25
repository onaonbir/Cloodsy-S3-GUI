// Navigation: where the shell is, with a Back history (capped at 50; tab
// switches inside the same bucket add none).

import { computed, ref } from 'vue';

export type BucketTab = 'overview' | 'files' | 'access' | 'settings' | 'lifecycle' | 'webhooks';
export type ServerPage = 'sessions' | 'logs' | 'metrics' | 'maintenance' | 'config' | 'servers';

export type Dest =
  | { kind: 'dashboard' }
  | { kind: 'buckets' }
  | { kind: 'bucket'; name: string; tab: BucketTab; prefix?: string }
  | { kind: 'admins' }
  | { kind: 'server'; page: ServerPage }
  | { kind: 'settings' };

const HISTORY = 50;
export const current = ref<Dest>({ kind: 'dashboard' });
const history = ref<Dest[]>([]);
/** The bucket shown under Buckets in the sidebar (stays until closed). */
export const openBucket = ref<string | null>(null);
/** Remembered tab per bucket. */
const tabs = new Map<string, BucketTab>();

export const canGoBack = computed(() => history.value.length > 0);

function same(a: Dest, b: Dest) {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function go(d: Dest) {
  if (same(d, current.value)) return;
  const cur = current.value;
  const tabSwitch = cur.kind === 'bucket' && d.kind === 'bucket' && cur.name === d.name;
  if (!tabSwitch) {
    history.value.push(cur);
    if (history.value.length > HISTORY) history.value.shift();
  }
  if (d.kind === 'bucket') {
    openBucket.value = d.name;
    tabs.set(d.name, d.tab);
  }
  current.value = d;
}

export function goBucket(name: string, tab?: BucketTab, prefix?: string) {
  go({ kind: 'bucket', name, tab: tab ?? tabs.get(name) ?? 'overview', ...(prefix !== undefined ? { prefix } : {}) });
}

export function back() {
  const d = history.value.pop();
  if (d) {
    if (d.kind === 'bucket') openBucket.value = d.name;
    current.value = d;
  }
}

/** A deleted bucket disappears from the history and the sidebar. */
export function forgetBucket(name: string) {
  history.value = history.value.filter((d) => !(d.kind === 'bucket' && d.name === name));
  tabs.delete(name);
  if (openBucket.value === name) openBucket.value = null;
  if (current.value.kind === 'bucket' && current.value.name === name) current.value = { kind: 'buckets' };
}

export function closeBucket() {
  if (openBucket.value) {
    const name = openBucket.value;
    openBucket.value = null;
    if (current.value.kind === 'bucket' && current.value.name === name) go({ kind: 'buckets' });
  }
}

export function resetNav() {
  current.value = { kind: 'dashboard' };
  history.value = [];
  openBucket.value = null;
  tabs.clear();
}
