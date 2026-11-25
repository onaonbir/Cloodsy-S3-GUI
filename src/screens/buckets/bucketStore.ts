// One open bucket: its details, access keys, lifecycle rules and webhooks
// (2.0 BucketController). BucketScreen creates it and provides it to the
// tabs, so switching tabs keeps the loaded data. Changes to the bucket are
// mirrored into the session's bucket list (dashboard, sidebar, table).

import { inject, reactive, type InjectionKey } from 'vue';
import type { Bucket, Credential, LifecycleRule, Upload, Webhook } from '@/lib/api';
import type { ApiError } from '@/lib/ipc';
import { buckets, useApi } from '@/stores/session';
import { normalizeRule, type WebhookSave } from './logic';

export interface BucketState {
  name: string;
  bucket: Bucket | null;
  credentials: Credential[];
  rules: LifecycleRule[];
  webhooks: Webhook[];
  loading: boolean;
  error: string | null;
  connectionError: boolean;
  uploads: Upload[];
  uploadsLoaded: boolean;
}

export function createBucketStore(name: string) {
  const api = useApi();
  const state = reactive<BucketState>({
    name,
    bucket: null,
    credentials: [],
    rules: [],
    webhooks: [],
    loading: false,
    error: null,
    connectionError: false,
    uploads: [],
    uploadsLoaded: false,
  });
  // Stale answers (an older reload finishing last) are dropped.
  let seq = 0;

  function setBucket(b: Bucket) {
    state.bucket = b;
    const i = buckets.value.findIndex((x) => x.name === b.name);
    if (i >= 0) buckets.value[i] = b;
  }

  async function load() {
    const my = ++seq;
    state.loading = true;
    try {
      const [b, creds, rules, hooks] = await Promise.all([api.bucket(name), api.credentials(name), api.lifecycle(name), api.webhooks(name)]);
      if (my !== seq) return;
      setBucket(b);
      state.credentials = creds;
      state.rules = rules.map(normalizeRule);
      state.webhooks = hooks;
      state.error = null;
      state.connectionError = false;
    } catch (e) {
      if (my !== seq) return;
      state.error = (e as Error).message;
      state.connectionError = (e as ApiError).status === 0;
    } finally {
      if (my === seq) state.loading = false;
    }
  }

  async function reloadBucket() {
    setBucket(await api.bucket(name));
  }

  async function reloadCredentials() {
    state.credentials = await api.credentials(name);
    await reloadBucket(); // the credential count
  }

  async function reloadRules() {
    state.rules = (await api.lifecycle(name)).map(normalizeRule);
  }

  async function reloadWebhooks() {
    state.webhooks = await api.webhooks(name);
  }

  async function loadUploads() {
    state.uploads = await api.uploads(name);
    state.uploadsLoaded = true;
  }

  return {
    state,
    api,
    load,
    reloadBucket,

    // settings
    async setVersioning(on: boolean) { await api.setVersioning(name, on ? 'Enabled' : 'Suspended'); await reloadBucket(); },
    async setPublicRead(on: boolean) { await api.setPublicRead(name, on); await reloadBucket(); },
    async setWebDAV(on: boolean) { await api.setWebDAV(name, on); await reloadBucket(); },
    async setQuota(bytes: number) { await api.setQuota(name, bytes); await reloadBucket(); },
    async setStorage(dir: string) { await api.setStorage(name, dir); await reloadBucket(); },
    reprocess: () => api.reprocess(name),

    // access keys
    async createCredential(label: string, permission: 'read-write' | 'read-only') {
      const cred = await api.createCredential(name, label, permission);
      await reloadCredentials().catch(() => {});
      return cred;
    },
    async deleteCredential(accessKey: string) { await api.deleteCredential(accessKey); await reloadCredentials(); },

    // lifecycle
    async saveRule(rule: LifecycleRule, body: Partial<LifecycleRule>) {
      if (rule.id > 0) await api.updateLifecycle(name, rule.id, body);
      else await api.addLifecycle(name, body);
      await reloadRules();
    },
    async deleteRuleById(id: number) { await api.deleteLifecycleRule(name, id); await reloadRules(); },
    /** v1: the server deletes by prefix; no prefix removes every rule. */
    async deleteRules(prefix?: string) { await api.deleteLifecycle(name, prefix ? prefix : undefined); await reloadRules(); },

    // webhooks (event_types is a comma-separated string on the wire; see logic.eventsValue)
    async addWebhook(w: WebhookSave) {
      await api.addWebhook(name, { name: w.name, url: w.url, event_types: w.events, secret: w.secret ?? '' });
      await reloadWebhooks();
    },
    async updateWebhook(id: number, w: WebhookSave) {
      await api.updateWebhook(id, {
        name: w.name, url: w.url, event_types: w.events, active: w.active,
        ...(w.secret !== undefined ? { secret: w.secret } : {}),
      });
      await reloadWebhooks();
    },
    async deleteWebhook(id: number) { await api.deleteWebhook(id); await reloadWebhooks(); },
    deliveries: (id: number) => api.deliveries(id),
    testWebhook: (id: number) => api.testWebhook(id),

    // incomplete multipart uploads
    loadUploads,
    async abortUpload(id: string) { await api.abortUpload(name, id); await loadUploads(); },
    async abortUploads(olderThanDays?: number) {
      const r = await api.abortUploads(name, olderThanDays);
      await loadUploads().catch(() => {});
      return (r as { aborted?: number } | null)?.aborted ?? 0;
    },
  };
}

export type BucketStore = ReturnType<typeof createBucketStore>;
export const BUCKET_STORE: InjectionKey<BucketStore> = Symbol('bucket-store');

export function useBucket(): BucketStore {
  const s = inject(BUCKET_STORE);
  if (!s) throw new Error('useBucket() outside BucketScreen');
  return s;
}
