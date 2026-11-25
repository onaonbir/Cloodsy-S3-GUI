// Pure rules behind the bucket screens (2.0 bucket_dialogs.dart,
// buckets_screen.dart, access_dialogs.dart, lifecycle_dialog.dart,
// server_controller.dart): validation, sorting, quota units, the WebDAV
// mount URL, webhook event sets and lifecycle rules. Unit-tested.

import type { Bucket, Delivery, LifecycleRule, ServerStatus } from '@/lib/api';
import { t } from '@/lib/i18n';

// ---------------------------------------------------------------- buckets

/** The server's rule (admin/buckets.go validBucketName). Dots are not accepted. */
export const BUCKET_NAME_RE = /^[a-z0-9][a-z0-9-]*[a-z0-9]$/;

export function validateBucketName(name: string): string | null {
  if (name.length < 3 || name.length > 63) return t('Use 3–63 characters');
  if (!BUCKET_NAME_RE.test(name)) return t('Lowercase letters, digits and hyphens only; start and end with a letter or digit');
  return null;
}

/** "/srv/data", "C:\data", "C:/data" or a UNC path "\\host\share". */
export function isAbsolutePath(p: string): boolean {
  return p.startsWith('/') || /^[A-Za-z]:[\\/]/.test(p) || p.startsWith('\\\\');
}

/** The custom storage directory: empty is fine only when the option is off. */
export function validateStorageDir(dir: string): string | null {
  if (!dir) return t('Enter an absolute path on the server');
  if (!isAbsolutePath(dir)) return t('Use an absolute path, e.g. /mnt/ssd/buckets or D:\\data');
  return null;
}

export type BucketSortKey = 'name' | 'objects' | 'size' | 'created';
export interface BucketSort { key: BucketSortKey; asc: boolean }

/** Clicking a column: the same one flips the direction, another starts ascending for NAME and descending otherwise. */
export function nextSort(cur: BucketSort, key: BucketSortKey): BucketSort {
  if (cur.key === key) return { key, asc: !cur.asc };
  return { key, asc: key === 'name' };
}

const cmp = <T extends string | number>(a: T, b: T) => (a < b ? -1 : a > b ? 1 : 0);

/** Buckets whose name contains the filter, in the chosen order. */
export function visibleBuckets(all: readonly Bucket[], query: string, sort: BucketSort): Bucket[] {
  const q = query.trim().toLowerCase();
  const list = all.filter((b) => b.name.includes(q));
  const by = (a: Bucket, b: Bucket): number => {
    switch (sort.key) {
      case 'name': return cmp(a.name, b.name);
      case 'objects': return cmp(a.objects ?? 0, b.objects ?? 0);
      case 'size': return cmp(a.usage_bytes ?? 0, b.usage_bytes ?? 0);
      case 'created': return cmp(a.created_at ?? '', b.created_at ?? '');
    }
  };
  return list.sort((a, b) => (sort.asc ? by(a, b) : by(b, a)));
}

export const hasQuota = (b: Bucket) => (b.quota_bytes ?? 0) > 0;
/** Used share of the quota (0 without one; can exceed 1). */
export const quotaFraction = (b: Bucket) => (hasQuota(b) ? (b.usage_bytes ?? 0) / b.quota_bytes : 0);
export const quotaPercent = (b: Bucket) => (quotaFraction(b) * 100).toFixed(0);
export const versioningEnabled = (b: Bucket) => b.versioning === 'Enabled';

// ---------------------------------------------------------------- quota

export type QuotaUnit = 'MB' | 'GB' | 'TB';
export const QUOTA_UNITS: QuotaUnit[] = ['MB', 'GB', 'TB'];
const MB = 1024 ** 2;
const GB = 1024 ** 3;
const TB = 1024 ** 4;

const trim2 = (v: number) => (v === Math.round(v) ? v.toFixed(0) : v.toFixed(2));

/** The quota dialog's starting value: whole TB, else GB from 1 GB, else MB; empty without a quota. */
export function quotaInitial(bytes: number): { value: string; unit: QuotaUnit } {
  if (!bytes || bytes <= 0) return { value: '', unit: 'GB' };
  if (bytes >= TB && bytes % TB === 0) return { value: String(bytes / TB), unit: 'TB' };
  if (bytes >= GB) return { value: trim2(bytes / GB), unit: 'GB' };
  return { value: trim2(bytes / MB), unit: 'MB' };
}

// ---------------------------------------------------------------- WebDAV

/** Port of a listen address: ":8081", "0.0.0.0:8081", "[::]:8081" or "8081". */
export function listenPort(listen: string): string {
  const l = listen.trim();
  return l.includes(':') ? l.slice(l.lastIndexOf(':') + 1) : l;
}

/** `{scheme}://{adminHost}:{webdavPort}/`, or null when the server has WebDAV off or the address is unknown. */
export function webdavMountUrl(adminUrl: string | null | undefined, status: ServerStatus | null | undefined): string | null {
  if (!status?.webdav?.enabled || !adminUrl) return null;
  let host = '';
  try {
    host = new URL(adminUrl).hostname;
  } catch {
    return null;
  }
  const port = listenPort(status.webdav.listen ?? '');
  if (!host || !port) return null;
  const scheme = status.tls?.webdav ? 'https' : 'http';
  return `${scheme}://${host}:${port}/`;
}

// ---------------------------------------------------------------- webhooks

/** What the webhook dialog saves; `secret` undefined keeps the stored one. */
export interface WebhookSave { name: string; url: string; events: string; active: boolean; secret?: string }

/** The server stores event types as one comma-separated string ("*" = all). */
export function parseEvents(raw: unknown): { all: boolean; events: string[] } {
  const list = Array.isArray(raw)
    ? raw.map(String)
    : String(raw ?? '*').split(',');
  const events = list.map((e) => e.trim()).filter(Boolean);
  if (!events.length || events.includes('*')) return { all: true, events: [] };
  return { all: false, events: [...new Set(events)] };
}

export const isWildcard = (e: string) => e.endsWith(':*');
/** "s3:ObjectCreated:Put" → "s3:ObjectCreated:*". */
export const wildcardOf = (e: string) => `${e.slice(0, e.lastIndexOf(':') + 1)}*`;
/** A specific event covered by a selected wildcard. */
export const coveredByWildcard = (events: readonly string[], e: string) => !isWildcard(e) && events.includes(wildcardOf(e));

/** Ticks or unticks one event; ticking a wildcard clears its specific siblings. */
export function toggleEvent(events: readonly string[], value: string, on: boolean): string[] {
  let next = events.filter((e) => e !== value);
  if (on) {
    if (isWildcard(value)) {
      const base = value.slice(0, -1);
      next = next.filter((e) => !e.startsWith(base));
    }
    next.push(value);
  }
  return next;
}

/** The value sent to the server: "*" or the comma-separated set, without specifics a wildcard already covers. */
export function eventsValue(all: boolean, events: readonly string[]): string {
  if (all) return '*';
  return events.filter((e) => !coveredByWildcard(events, e)).join(',');
}

/** http(s) URL with a host. */
export function validWebhookUrl(url: string): boolean {
  try {
    const u = new URL(url);
    return (u.protocol === 'http:' || u.protocol === 'https:') && u.hostname !== '';
  } catch {
    return false;
  }
}

export const deliveryOk = (d: Pick<Delivery, 'error' | 'status_code'>) => !d.error && d.status_code >= 200 && d.status_code < 300;

// ---------------------------------------------------------------- lifecycle

/** A rule with every field the dialogs and rows rely on (v1 servers omit some). */
export function normalizeRule(r: Partial<LifecycleRule> & { id: number }): LifecycleRule {
  return {
    id: r.id,
    name: r.name ?? '',
    prefix: r.prefix ?? '',
    status: r.status === 'Disabled' ? 'Disabled' : 'Enabled',
    expiration_days: r.expiration_days ?? 0,
    noncurrent_days: r.noncurrent_days ?? 0,
    abort_multipart_days: r.abort_multipart_days ?? 0,
    expire_delete_markers: r.expire_delete_markers ?? false,
    created_at: r.created_at ?? '',
  };
}

export const ruleEnabled = (r: LifecycleRule) => r.status !== 'Disabled';
export const ruleName = (r: LifecycleRule) => r.name || t('Rule #{id}', { id: r.id });

/** Human-readable actions, e.g. ["Delete objects after 30 days", …]. */
export function ruleActions(r: LifecycleRule): string[] {
  const out: string[] = [];
  if (r.expiration_days > 0) out.push(t('Delete objects after {n} days', { n: r.expiration_days }));
  if (r.noncurrent_days > 0) out.push(t('Delete old versions after {n} days', { n: r.noncurrent_days }));
  if (r.abort_multipart_days > 0) out.push(t('Abort incomplete uploads after {n} days', { n: r.abort_multipart_days }));
  if (r.expire_delete_markers) out.push(t('Remove orphan delete markers'));
  return out;
}

/** The body sent for a v2 rule (create and update). */
export function ruleBody(r: LifecycleRule): Partial<LifecycleRule> {
  return {
    name: r.name,
    prefix: r.prefix,
    status: r.status,
    expiration_days: r.expiration_days,
    noncurrent_days: r.noncurrent_days,
    abort_multipart_days: r.abort_multipart_days,
    expire_delete_markers: r.expire_delete_markers,
  };
}

/** Days from a text field: 0 when the action is off, null when invalid. */
export function parseDays(on: boolean, text: string): number | null {
  if (!on) return 0;
  const s = text.trim();
  if (!/^\d+$/.test(s)) return null;
  const v = parseInt(s, 10);
  return v > 0 ? v : null;
}

export interface RuleForm {
  name: string;
  prefix: string;
  enabled: boolean;
  expire: boolean;
  expireDays: string;
  noncurrent: boolean;
  noncurrentDays: string;
  abort: boolean;
  abortDays: string;
  markers: boolean;
}

/** The dialog's starting state: a new rule expires after 30 days. */
export function ruleForm(r?: LifecycleRule | null): RuleForm {
  const d = (v: number | undefined, def: number) => String(v && v > 0 ? v : def);
  return {
    name: r?.name ?? '',
    prefix: r?.prefix ?? '',
    enabled: r ? ruleEnabled(r) : true,
    expire: r ? r.expiration_days > 0 : true,
    expireDays: d(r?.expiration_days, 30),
    noncurrent: (r?.noncurrent_days ?? 0) > 0,
    noncurrentDays: d(r?.noncurrent_days, 30),
    abort: (r?.abort_multipart_days ?? 0) > 0,
    abortDays: d(r?.abort_multipart_days, 7),
    markers: r?.expire_delete_markers ?? false,
  };
}

/** Validates the v2 dialog: positive days, at least one action, not Expire + markers together. */
export function buildRule(f: RuleForm, id = 0): { rule: LifecycleRule } | { error: string } {
  const e = parseDays(f.expire, f.expireDays);
  const n = parseDays(f.noncurrent, f.noncurrentDays);
  const a = parseDays(f.abort, f.abortDays);
  if (e === null || n === null || a === null) return { error: t('Days must be positive whole numbers') };
  if (e === 0 && n === 0 && a === 0 && !f.markers) return { error: t('Pick at least one action') };
  // An expiration rule creates delete markers, so it can't also be the rule that removes them (the server enforces it too).
  if (e > 0 && f.markers) return { error: t('“Expire objects” and “Remove orphan delete markers” need separate rules') };
  return {
    rule: {
      id,
      name: f.name.trim(),
      prefix: f.prefix.trim(),
      status: f.enabled ? 'Enabled' : 'Disabled',
      expiration_days: e,
      noncurrent_days: n,
      abort_multipart_days: a,
      expire_delete_markers: f.markers,
      created_at: '',
    },
  };
}

// ---------------------------------------------------------------- errors

/** Reprocess answers 409 when it already runs or the bucket is busy with another long operation. */
export function reprocessConflictMessage(serverMessage: string): string {
  if (serverMessage.includes('reprocess')) return t('Reprocessing is already running');
  const i = serverMessage.lastIndexOf(': ');
  return t('Bucket is busy: {what}', { what: i >= 0 ? serverMessage.slice(i + 2) : serverMessage });
}

/** A 409 on bucket delete means "not empty" unless the bucket is busy with a long operation. */
export const isBusyMessage = (m: string) => m.startsWith('bucket is busy');
