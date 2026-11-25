// The Rust side's commands (src-tauri/src/lib.rs), typed.

import { invoke } from '@tauri-apps/api/core';

/** An error as the Rust side reports it: status 0 = transport, -1 = cancelled. */
export class ApiError extends Error {
  constructor(public status: number, message: string, public data?: unknown) {
    super(message);
  }
  get isUnauthorized() { return this.status === 401; }
  get isNotFound() { return this.status === 404; }
  get isConflict() { return this.status === 409; }
  get isConnectionError() { return this.status === 0; }
  get isCancelled() { return this.status === -1; }
}

function toError(e: unknown): ApiError {
  if (e instanceof ApiError) return e;
  if (e && typeof e === 'object' && 'message' in e) {
    const o = e as { status?: number; message: string; data?: unknown };
    return new ApiError(o.status ?? 0, o.message, o.data);
  }
  return new ApiError(0, String(e));
}

export async function call<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  try {
    return await invoke<T>(cmd, args);
  } catch (e) {
    throw toError(e);
  }
}

export interface AppInfo { name: string; version: string; os: string; arch: string; updates_installable: boolean }
export interface Server { id: string; name: string; url: string; username: string; s3_url?: string | null }
export interface Settings { servers: Server[]; prefs: Record<string, string>; imported_v2: boolean }
export interface SessionInfo { server_id: string; username: string; expires_at: number }
export interface LocalFile { path: string; rel: string; size: number }

export const ipc = {
  appInfo: () => call<AppInfo>('app_info'),
  settings: () => call<Settings>('settings_get'),
  setPref: (key: string, value: string | null) => call<void>('pref_set', { key, value }),
  saveServer: (server: Server, password: string | null) => call<Server>('server_save', { server, password }),
  removeServer: (id: string) => call<void>('server_remove', { id }),
  hasPassword: (id: string) => call<boolean>('server_has_password', { id }),
  probe: (url: string) => call<number>('server_probe', { url }),
  overview: (id: string) => call<{ ms: number; status: Record<string, unknown>; buckets: unknown[] }>('server_overview', { id }),
  connect: (id: string) => call<{ session: SessionInfo; status: Record<string, unknown> }>('session_connect', { id }),
  disconnect: (id: string) => call<void>('session_disconnect', { id }),
  sessionInfo: (id: string) => call<SessionInfo | null>('session_info', { id }),
  passwordChanged: (id: string, password: string) => call<SessionInfo>('session_password_changed', { id, password }),
  /** `long`: 5 min instead of 15 s; `timeoutSecs` sets it exactly. */
  api: <T = unknown>(server: string, method: string, path: string, opts: { query?: [string, string][]; body?: unknown; long?: boolean; timeoutSecs?: number } = {}) =>
    call<T>('api', { server, method, path, query: opts.query ?? null, body: opts.body ?? null, long: opts.long ?? false, timeoutSecs: opts.timeoutSecs ?? null }),
  uploadStart: (args: { id: string; server: string; bucket: string; key: string; path: string; contentType: string; multipart: boolean }) =>
    call<void>('upload_start', { args }),
  downloadStart: (args: { id: string; server: string; bucket: string; key: string; versionId: string | null; dest: string; size: number }) =>
    call<void>('download_start', { args }),
  cancelTransfer: (id: string) => call<void>('transfer_cancel', { id }),
  cancelAllTransfers: () => call<void>('transfer_cancel_all'),
  readObject: (server: string, bucket: string, key: string, max: number | null) =>
    call<ArrayBuffer>('object_read', { server, bucket, key, max }),
  presign: (args: { endpoint: string; bucket: string; key: string; accessKey: string; secretKey: string; region: string; expiresSecs: number; extraQuery: [string, string][] }) =>
    call<string>('presign_url', { args }),
  walk: (paths: string[]) => call<LocalFile[]>('files_walk', { paths }),
  previewPath: (name: string) => call<string>('preview_path', { name }),
  localPath: (serverUrl: string, hostOs: string, hostname: string, wslDistro: string, path: string) =>
    call<string | null>('local_path', { serverUrl, hostOs, hostname, wslDistro, path }),
  pathExists: (path: string) => call<boolean>('path_exists', { path }),
  githubLatest: (repo: string, timeoutSecs: number) =>
    call<{ tag: string; url: string; notes: string } | null>('github_latest', { repo, timeoutSecs }),
  openPath: (path: string) => call<void>('open_path', { path }),
  revealPath: (path: string) => call<void>('reveal_path', { path }),
};
