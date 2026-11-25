import { beforeAll, describe, expect, it } from 'vitest';
import { locale } from '@/lib/i18n';
import type { Bucket, LifecycleRule, ServerStatus } from '@/lib/api';
import {
  buildRule, coveredByWildcard, deliveryOk, eventsValue, isAbsolutePath, isBusyMessage, listenPort, nextSort, normalizeRule, parseDays,
  parseEvents, quotaInitial, reprocessConflictMessage, ruleActions, ruleForm, toggleEvent, validateBucketName, validateStorageDir,
  validWebhookUrl, visibleBuckets, webdavMountUrl, wildcardOf,
} from './logic';

beforeAll(() => {
  locale.value = 'en';
});

const bucket = (name: string, o: Partial<Bucket> = {}): Bucket => ({
  id: 1, name, quota_bytes: 0, versioning: '', public_read: false, webdav_enabled: false, objects: 0, usage_bytes: 0, credentials: 0,
  created_at: '2026-01-01T00:00:00Z', ...o,
});

describe('bucket names', () => {
  it('accepts the server rule', () => {
    for (const n of ['abc', 'my-bucket', 'a1b', '123', 'a'.repeat(63)]) expect(validateBucketName(n)).toBeNull();
  });
  it('rejects bad lengths', () => {
    expect(validateBucketName('ab')).toBe('Use 3–63 characters');
    expect(validateBucketName('a'.repeat(64))).toBe('Use 3–63 characters');
  });
  it('rejects bad characters and edges', () => {
    for (const n of ['My-bucket', 'my_bucket', 'my.bucket', '-abc', 'abc-', 'a b']) expect(validateBucketName(n)).toMatch(/^Lowercase/);
  });
});

describe('storage paths', () => {
  it('knows absolute paths', () => {
    for (const p of ['/mnt/ssd', 'C:\\data', 'd:/data', '\\\\host\\share']) expect(isAbsolutePath(p)).toBe(true);
    for (const p of ['data', './data', 'C:data', '~/x']) expect(isAbsolutePath(p)).toBe(false);
  });
  it('requires a path when the custom directory is on', () => {
    expect(validateStorageDir('')).not.toBeNull();
    expect(validateStorageDir('rel/dir')).not.toBeNull();
    expect(validateStorageDir('/srv/b')).toBeNull();
  });
});

describe('bucket table', () => {
  const all = [
    bucket('beta', { objects: 5, usage_bytes: 100, created_at: '2026-03-01T00:00:00Z' }),
    bucket('alpha', { objects: 50, usage_bytes: 10, created_at: '2026-01-01T00:00:00Z' }),
    bucket('gamma', { objects: 1, usage_bytes: 1000, created_at: '2026-02-01T00:00:00Z' }),
  ];
  const names = (l: Bucket[]) => l.map((b) => b.name);

  it('sorts by each column', () => {
    expect(names(visibleBuckets(all, '', { key: 'name', asc: true }))).toEqual(['alpha', 'beta', 'gamma']);
    expect(names(visibleBuckets(all, '', { key: 'name', asc: false }))).toEqual(['gamma', 'beta', 'alpha']);
    expect(names(visibleBuckets(all, '', { key: 'objects', asc: false }))).toEqual(['alpha', 'beta', 'gamma']);
    expect(names(visibleBuckets(all, '', { key: 'size', asc: true }))).toEqual(['alpha', 'beta', 'gamma']);
    expect(names(visibleBuckets(all, '', { key: 'created', asc: true }))).toEqual(['alpha', 'gamma', 'beta']);
  });
  it('filters by name, case-insensitively, without touching the input', () => {
    expect(names(visibleBuckets(all, ' AL ', { key: 'name', asc: true }))).toEqual(['alpha']);
    expect(visibleBuckets(all, 'zzz', { key: 'name', asc: true })).toEqual([]);
    expect(names(all)).toEqual(['beta', 'alpha', 'gamma']);
  });
  it('flips on the same column; NAME starts ascending, others descending', () => {
    expect(nextSort({ key: 'name', asc: true }, 'name')).toEqual({ key: 'name', asc: false });
    expect(nextSort({ key: 'name', asc: true }, 'size')).toEqual({ key: 'size', asc: false });
    expect(nextSort({ key: 'size', asc: false }, 'name')).toEqual({ key: 'name', asc: true });
  });
});

describe('quota dialog', () => {
  it('picks a unit for the current quota', () => {
    expect(quotaInitial(0)).toEqual({ value: '', unit: 'GB' });
    expect(quotaInitial(2 * 1024 ** 4)).toEqual({ value: '2', unit: 'TB' });
    expect(quotaInitial(1536 * 1024 ** 3)).toEqual({ value: '1536', unit: 'GB' });
    expect(quotaInitial(1.5 * 1024 ** 3)).toEqual({ value: '1.50', unit: 'GB' });
    expect(quotaInitial(500 * 1024 ** 2)).toEqual({ value: '500', unit: 'MB' });
  });
});

describe('WebDAV mount URL', () => {
  const st = (o: Partial<ServerStatus>): ServerStatus => ({ status: 'ok', version: '1', buckets: 0, ...o });
  it('uses the admin host, the WebDAV port and its TLS', () => {
    expect(webdavMountUrl('https://s3.example.com:9001', st({ webdav: { enabled: true, listen: ':8081' } }))).toBe('http://s3.example.com:8081/');
    expect(webdavMountUrl('http://10.0.0.5:9001', st({ webdav: { enabled: true, listen: '0.0.0.0:8443' }, tls: { webdav: true } }))).toBe('https://10.0.0.5:8443/');
    expect(webdavMountUrl('http://[::1]:9001', st({ webdav: { enabled: true, listen: '[::]:8081' } }))).toBe('http://[::1]:8081/');
  });
  it('is null when the server has WebDAV off or no port', () => {
    expect(webdavMountUrl('http://h:9001', st({ webdav: { enabled: false, listen: ':8081' } }))).toBeNull();
    expect(webdavMountUrl('http://h:9001', st({ webdav: { enabled: true, listen: '' } }))).toBeNull();
    expect(webdavMountUrl('http://h:9001', st({}))).toBeNull();
    expect(webdavMountUrl(null, st({ webdav: { enabled: true, listen: ':1' } }))).toBeNull();
  });
  it('reads ports from listen addresses', () => {
    expect(listenPort(':8081')).toBe('8081');
    expect(listenPort('8081')).toBe('8081');
    expect(listenPort('[::]:8081')).toBe('8081');
  });
});

describe('webhook events', () => {
  it('parses the comma-separated server value', () => {
    expect(parseEvents('*')).toEqual({ all: true, events: [] });
    expect(parseEvents('')).toEqual({ all: true, events: [] });
    expect(parseEvents(undefined)).toEqual({ all: true, events: [] });
    expect(parseEvents('s3:ObjectCreated:Put, s3:ObjectRemoved:*')).toEqual({ all: false, events: ['s3:ObjectCreated:Put', 's3:ObjectRemoved:*'] });
    expect(parseEvents(['s3:ObjectCreated:Copy'])).toEqual({ all: false, events: ['s3:ObjectCreated:Copy'] });
  });
  it('ticking a wildcard clears its specific siblings only', () => {
    const before = ['s3:ObjectCreated:Put', 's3:ObjectCreated:Copy', 's3:ObjectRemoved:Delete'];
    expect(toggleEvent(before, 's3:ObjectCreated:*', true)).toEqual(['s3:ObjectRemoved:Delete', 's3:ObjectCreated:*']);
    expect(toggleEvent(['s3:ObjectCreated:*'], 's3:ObjectCreated:*', false)).toEqual([]);
    expect(toggleEvent([], 's3:ObjectRemoved:Delete', true)).toEqual(['s3:ObjectRemoved:Delete']);
    expect(toggleEvent(['s3:ObjectRemoved:Delete'], 's3:ObjectRemoved:Delete', false)).toEqual([]);
  });
  it('knows what a wildcard covers', () => {
    expect(wildcardOf('s3:ObjectRemoved:DeleteMarkerCreated')).toBe('s3:ObjectRemoved:*');
    expect(coveredByWildcard(['s3:ObjectCreated:*'], 's3:ObjectCreated:Put')).toBe(true);
    expect(coveredByWildcard(['s3:ObjectCreated:*'], 's3:ObjectRemoved:Delete')).toBe(false);
    expect(coveredByWildcard(['s3:ObjectCreated:*'], 's3:ObjectCreated:*')).toBe(false);
  });
  it('builds the value sent to the server', () => {
    expect(eventsValue(true, ['s3:ObjectCreated:Put'])).toBe('*');
    expect(eventsValue(false, [])).toBe('');
    expect(eventsValue(false, ['s3:ObjectCreated:Put', 's3:ObjectCreated:*', 's3:ObjectRemoved:Delete'])).toBe('s3:ObjectCreated:*,s3:ObjectRemoved:Delete');
  });
  it('validates endpoint URLs', () => {
    expect(validWebhookUrl('https://example.com/hook')).toBe(true);
    expect(validWebhookUrl('http://10.0.0.1:8080')).toBe(true);
    for (const u of ['example.com', 'ftp://example.com', 'http://', '']) expect(validWebhookUrl(u)).toBe(false);
  });
  it('counts a delivery as ok only for 2xx without an error', () => {
    expect(deliveryOk({ error: '', status_code: 204 })).toBe(true);
    expect(deliveryOk({ error: '', status_code: 500 })).toBe(false);
    expect(deliveryOk({ error: 'timeout', status_code: 200 })).toBe(false);
  });
});

describe('lifecycle rules', () => {
  const base = (o: Partial<LifecycleRule> = {}) => normalizeRule({ id: 3, ...o });

  it('fills fields a v1 server leaves out', () => {
    expect(base()).toMatchObject({ name: '', prefix: '', status: 'Enabled', expiration_days: 0, expire_delete_markers: false });
    expect(base({ status: 'Disabled' }).status).toBe('Disabled');
  });
  it('lists the actions', () => {
    expect(ruleActions(base({ expiration_days: 30, abort_multipart_days: 7 }))).toEqual(['Delete objects after 30 days', 'Abort incomplete uploads after 7 days']);
    expect(ruleActions(base({ noncurrent_days: 5, expire_delete_markers: true }))).toEqual(['Delete old versions after 5 days', 'Remove orphan delete markers']);
  });
  it('parses days', () => {
    expect(parseDays(false, 'x')).toBe(0);
    expect(parseDays(true, ' 30 ')).toBe(30);
    for (const s of ['0', '-1', '1.5', '', 'abc']) expect(parseDays(true, s)).toBeNull();
  });
  it('starts a new rule with Expire after 30 days, and keeps an existing one', () => {
    expect(ruleForm()).toMatchObject({ expire: true, expireDays: '30', noncurrent: false, noncurrentDays: '30', abort: false, abortDays: '7', enabled: true });
    const f = ruleForm(base({ name: 'n', prefix: 'logs/', status: 'Disabled', expiration_days: 0, noncurrent_days: 9 }));
    expect(f).toMatchObject({ name: 'n', prefix: 'logs/', enabled: false, expire: false, expireDays: '30', noncurrent: true, noncurrentDays: '9' });
  });
  it('validates the v2 dialog', () => {
    const f = ruleForm();
    expect(buildRule({ ...f, expireDays: '0' })).toEqual({ error: 'Days must be positive whole numbers' });
    expect(buildRule({ ...f, expire: false })).toEqual({ error: 'Pick at least one action' });
    expect(buildRule({ ...f, markers: true })).toEqual({ error: '“Expire objects” and “Remove orphan delete markers” need separate rules' });
    const ok = buildRule({ ...f, name: ' Logs ', prefix: ' logs/ ', expire: false, markers: true, abort: true }, 7);
    expect(ok).toEqual({
      rule: {
        id: 7, name: 'Logs', prefix: 'logs/', status: 'Enabled', expiration_days: 0, noncurrent_days: 0, abort_multipart_days: 7,
        expire_delete_markers: true, created_at: '',
      },
    });
  });
});

describe('conflicts', () => {
  it('tells "busy" from "not empty"', () => {
    expect(isBusyMessage('bucket is busy: moving storage')).toBe(true);
    expect(isBusyMessage('bucket not empty (3 objects)')).toBe(false);
  });
  it('explains reprocess conflicts', () => {
    expect(reprocessConflictMessage('reprocess already running')).toBe('Reprocessing is already running');
    expect(reprocessConflictMessage('bucket is busy: moving storage')).toBe('Bucket is busy: moving storage');
  });
});
