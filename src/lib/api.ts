// The Admin REST API (Cloodsy S3 `admin/`), typed. Requests go through the
// Rust side (session, renewal, 401 handling); paths are encoded here, one
// segment at a time.

import { ipc } from './ipc';

export const seg = (s: string) => encodeURIComponent(s);
/** An object key in a path: each segment encoded, "/" kept. */
export const keyPath = (k: string) => k.split('/').map(encodeURIComponent).join('/');

export type Feature =
  | 'object-download' | 'object-upload' | 'object-versions' | 'object-info' | 'object-range' | 'object-copy'
  | 'object-search' | 'prefix-stats' | 'object-metadata' | 'multipart' | 'lifecycle-v2' | 'webhooks-v2'
  | 'maintenance' | 'sessions' | 'logs' | 'config' | 'metrics';

export interface ServerStatus {
  status: string;
  version: string;
  buckets: number;
  admin_exists?: boolean;
  webdav?: { enabled: boolean; listen?: string };
  features?: string[];
  uptime_seconds?: number;
  tls?: { s3?: boolean; admin?: boolean; webdav?: boolean; acme?: boolean; acme_domains?: string[] };
  storage?: { path?: string; total_bytes?: number; free_bytes?: number };
  s3?: { listen?: string; tls?: boolean; region?: string; virtual_host_domains?: string[] };
  host?: { os?: string; hostname?: string; wsl_distro?: string };
}

export interface Bucket {
  id: number;
  name: string;
  quota_bytes: number;
  versioning: string; // '' | 'Enabled' | 'Suspended'
  storage_dir?: string;
  storage_path?: string;
  public_read: boolean;
  webdav_enabled: boolean;
  objects: number;
  usage_bytes: number;
  credentials: number;
  created_at: string;
}

export interface Credential { id: number; name: string; access_key: string; secret_key: string; permission: string; created_at: string }

export interface LifecycleRule {
  id: number;
  name: string;
  prefix: string;
  status: string; // 'Enabled' | 'Disabled'
  expiration_days: number;
  noncurrent_days: number;
  abort_multipart_days: number;
  expire_delete_markers: boolean;
  created_at: string;
}

/** `event_types` is one comma-separated string on the wire ("*" or "a,b"). */
export interface Webhook { id: number; name: string; url: string; event_types: string; active: boolean; has_secret: boolean; created_at: string }
export interface Delivery { id: number; event_type: string; object_key: string; status_code: number; error: string; duration_ms: number; attempt: number; created_at: string }

export interface S3Object { key: string; size: number; etag: string; content_type?: string; last_modified: string }
export interface ObjectList { objects: S3Object[]; prefixes: string[]; prefix: string; truncated: boolean; next_marker?: string }

export interface ObjectInfo {
  key: string;
  size: number;
  etag: string;
  content_type: string;
  last_modified: string;
  version_id?: string;
  metadata?: Record<string, string>;
  disk_path?: string;
  bucket_dir?: string;
  variant?: { exists: boolean; disk_path?: string; size?: number };
  versions?: number | unknown[];
}

export interface ObjectVersion { version_id: string; size: number; etag: string; content_type?: string; last_modified: string; is_latest: boolean; is_delete_marker: boolean }
export interface Upload { upload_id: string; key: string; initiated: string; parts: number; bytes: number }
export interface Admin { id: number; username: string; created_at: string }
export interface AdminSession { id: string; username: string; created_at: string; last_seen_at: string; expires_at: string; ip: string; user_agent: string; current: boolean }
export interface LogEntry { id: number; time: string; level: string; message: string; attrs?: Record<string, unknown> }
export interface Metrics {
  since: string;
  s3: { requests: number; errors_4xx: number; errors_5xx: number; bytes_in: number; bytes_out: number; by_method: Record<string, number> };
  series: { time: string; requests: number; errors: number; bytes_in: number; bytes_out: number }[];
}
export interface ScanResult {
  orphan_dirs: { path: string; bytes: number }[];
  missing_files: { bucket: string; key: string; version_id?: string }[];
  untracked_files: { bucket: string; path: string; bytes: number }[];
  scanned_objects: number;
  truncated: boolean;
}

export const WEBHOOK_EVENTS = [
  's3:ObjectCreated:*', 's3:ObjectCreated:Put', 's3:ObjectCreated:Copy', 's3:ObjectCreated:CompleteMultipartUpload',
  's3:ObjectRemoved:*', 's3:ObjectRemoved:Delete', 's3:ObjectRemoved:DeleteMarkerCreated',
];

type Q = [string, string][];
const q = (o: Record<string, string | number | boolean | null | undefined>): Q =>
  Object.entries(o).filter(([, v]) => v !== undefined && v !== null && v !== '').map(([k, v]) => [k, String(v)]);

/** The Admin API of one server (by saved server id). */
export function adminApi(sid: string) {
  const get = <T>(path: string, query?: Q, long = false) => ipc.api<T>(sid, 'GET', path, { query, long });
  const send = <T>(method: string, path: string, body?: unknown, query?: Q, long = false) => ipc.api<T>(sid, method, path, { body, query, long });
  const b = (name: string) => `/buckets/${seg(name)}`;

  return {
    status: () => get<ServerStatus>('/status'),

    // buckets
    buckets: () => get<{ buckets: Bucket[] }>('/buckets').then((r) => r.buckets ?? []),
    bucket: (name: string) => get<Bucket>(b(name)),
    createBucket: (name: string, storageDir?: string) => send<Bucket>('POST', '/buckets', { name, ...(storageDir ? { storage_dir: storageDir } : {}) }),
    deleteBucket: (name: string, force = false) => send('DELETE', b(name), undefined, force ? q({ force: 'true' }) : undefined, force),
    setQuota: (name: string, quotaBytes: number) => send('PUT', `${b(name)}/quota`, { quota_bytes: quotaBytes }),
    setStorage: (name: string, storageDir: string) => send('PUT', `${b(name)}/storage`, { storage_dir: storageDir }, undefined, true),
    setVersioning: (name: string, status: 'Enabled' | 'Suspended') => send('PUT', `${b(name)}/versioning`, { versioning: status }),
    setPublicRead: (name: string, on: boolean) => send('PUT', `${b(name)}/public-read`, { public_read: on }),
    setWebDAV: (name: string, on: boolean) => send('PUT', `${b(name)}/webdav`, { webdav_enabled: on }),
    reprocess: (name: string) => send('POST', `${b(name)}/reprocess`),

    // credentials
    credentials: (name: string) => get<{ credentials: Credential[] }>(`${b(name)}/credentials`).then((r) => r.credentials ?? []),
    createCredential: (name: string, label: string, permission: 'read-write' | 'read-only') =>
      send<Credential>('POST', `${b(name)}/credentials`, { name: label, permission }),
    deleteCredential: (accessKey: string) => send('DELETE', `/credentials/${seg(accessKey)}`),

    // lifecycle
    lifecycle: (name: string) => get<{ rules: LifecycleRule[] }>(`${b(name)}/lifecycle`).then((r) => r.rules ?? []),
    addLifecycle: (name: string, rule: Partial<LifecycleRule>) => send('POST', `${b(name)}/lifecycle`, rule),
    updateLifecycle: (name: string, id: number, rule: Partial<LifecycleRule>) => send('PUT', `${b(name)}/lifecycle/${id}`, rule),
    deleteLifecycleRule: (name: string, id: number) => send('DELETE', `${b(name)}/lifecycle/${id}`),
    deleteLifecycle: (name: string, prefix?: string) => send('DELETE', `${b(name)}/lifecycle`, undefined, prefix !== undefined ? q({ prefix }) : undefined),

    // webhooks
    webhooks: (name: string) => get<{ webhooks: Webhook[] }>(`${b(name)}/webhooks`).then((r) => r.webhooks ?? []),
    addWebhook: (name: string, w: { name: string; url: string; event_types: string; secret?: string }) => send('POST', `${b(name)}/webhooks`, w),
    updateWebhook: (id: number, w: { name: string; url: string; event_types: string; active: boolean; secret?: string }) => send('PUT', `/webhooks/${id}`, w),
    deleteWebhook: (id: number) => send('DELETE', `/webhooks/${id}`),
    deliveries: (id: number) => get<{ deliveries: Delivery[] }>(`/webhooks/${id}/deliveries`, q({ limit: 50 })).then((r) => r.deliveries ?? []),
    testWebhook: (id: number) => ipc.api<{ status_code: number; error?: string; duration_ms: number }>(sid, 'POST', `/webhooks/${id}/test`, { timeoutSecs: 40 }),

    // objects
    objects: (name: string, prefix: string, marker?: string, maxKeys = 500) =>
      get<ObjectList>(`${b(name)}/objects`, q({ prefix, delimiter: '/', 'max-keys': maxKeys, marker })),
    search: (name: string, query: string, prefix: string, marker?: string, maxKeys = 500) =>
      get<ObjectList>(`${b(name)}/search`, q({ q: query, prefix, 'max-keys': maxKeys, marker })),
    deleteObject: (name: string, key: string, versionId?: string) =>
      send('DELETE', `${b(name)}/objects/${keyPath(key)}`, undefined, versionId !== undefined ? q({ versionId }) : undefined),
    deletePrefix: (name: string, prefix: string) => send<{ deleted: number; failed: number }>('POST', `${b(name)}/objects/delete-prefix`, { prefix }, undefined, true),
    createFolder: (name: string, prefix: string) => send('PUT', `${b(name)}/object`, undefined, q({ key: prefix })),
    objectInfo: (name: string, key: string) => get<ObjectInfo>(`${b(name)}/object/info`, q({ key })),
    setMeta: (name: string, key: string, contentType: string, metadata: Record<string, string>) =>
      send<ObjectInfo>('PUT', `${b(name)}/object/meta`, { content_type: contentType, metadata }, q({ key })),
    copy: (name: string, sourceKey: string, destKey: string, move: boolean, destBucket?: string) =>
      send('POST', `${b(name)}/objects/copy`, { source_key: sourceKey, dest_key: destKey, move, ...(destBucket && destBucket !== name ? { dest_bucket: destBucket } : {}) }, undefined, true),
    copyPrefix: (name: string, sourcePrefix: string, destPrefix: string, move: boolean, destBucket?: string) =>
      send<{ copied: number; failed: number }>('POST', `${b(name)}/objects/copy-prefix`,
        { source_prefix: sourcePrefix, dest_prefix: destPrefix, move, ...(destBucket && destBucket !== name ? { dest_bucket: destBucket } : {}) }, undefined, true),
    prefixStats: (name: string, prefix: string) => get<{ objects: number; bytes: number }>(`${b(name)}/prefix-stats`, q({ prefix }), true),
    versions: (name: string, key: string) => get<{ versions: ObjectVersion[] }>(`${b(name)}/versions`, q({ key })).then((r) => r.versions ?? []),

    // multipart housekeeping
    uploads: (name: string) => get<{ uploads: Upload[] }>(`${b(name)}/uploads`).then((r) => r.uploads ?? []),
    abortUpload: (name: string, id: string) => send('DELETE', `${b(name)}/uploads/${seg(id)}`),
    abortUploads: (name: string, olderThanDays?: number) =>
      send<{ aborted: number }>('DELETE', `${b(name)}/uploads`, undefined, olderThanDays ? q({ older_than_days: olderThanDays }) : undefined, true),

    // admins
    admins: () => get<{ admins: Admin[] }>('/admins').then((r) => r.admins ?? []),
    addAdmin: (username: string, password?: string) =>
      send<{ username: string; password: string; auto_generated: boolean }>('POST', '/admins', { username, ...(password ? { password } : {}) }),
    setAdminPassword: (username: string, password?: string) =>
      send<{ password?: string; auto_generated?: boolean }>('PUT', `/admins/${seg(username)}/password`, password ? { password } : {}),
    deleteAdmin: (username: string) => send('DELETE', `/admins/${seg(username)}`),

    // server tools
    sessions: () => get<{ sessions: AdminSession[] }>('/sessions').then((r) => r.sessions ?? []),
    endSession: (id: string) => send('DELETE', `/sessions/${seg(id)}`),
    logs: (sinceId?: number, level?: string, query?: string) =>
      get<{ entries: LogEntry[]; last_id: number }>('/logs', q({ since_id: sinceId, level, q: query, limit: 500 })),
    metrics: () => get<Metrics>('/metrics'),
    scan: () => send<ScanResult>('POST', '/maintenance/scan', undefined, undefined, true),
    deleteOrphans: (paths: string[]) => send<{ deleted: number; failed: { path: string; error: string }[] }>('POST', '/maintenance/orphan-dirs/delete', { paths }, undefined, true),
    config: () => get<Record<string, unknown>>('/config'),
  };
}

export type AdminApi = ReturnType<typeof adminApi>;
