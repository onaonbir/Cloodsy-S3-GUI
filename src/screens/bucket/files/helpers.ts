// Pure logic of the Files tab (2.0 objects_controller.dart, files_tab.dart,
// object_panel.dart, object_dialogs.dart): listing, sorting, names, local
// paths, previews, share endpoints and move/copy validation.

import type { S3Object } from '@/lib/api';

export type SortKey = 'name' | 'size' | 'modified';

/** Objects per listing page (the server's maximum). */
export const PAGE_SIZE = 500;
/** More files than this in one upload asks first. */
export const UPLOAD_CONFIRM_FILES = 200;

// ------------------------------------------------------------ names

/** "a/b/c.txt" → "c.txt" (a folder "a/b/" → "b"). */
export function fileName(key: string): string {
  const k = key.endsWith('/') ? key.slice(0, -1) : key;
  return k.slice(k.lastIndexOf('/') + 1);
}

/** Lower-cased extension of a key's file name, without the dot ('' when none). */
export function extOf(key: string): string {
  const n = fileName(key);
  const i = n.lastIndexOf('.');
  return i <= 0 || i === n.length - 1 ? '' : n.slice(i + 1).toLowerCase();
}

/** A sub-folder's name relative to the open folder ("a/b/" in "a/" → "b"). */
export function folderName(prefix: string, folder: string): string {
  const rest = folder.startsWith(prefix) ? folder.slice(prefix.length) : folder;
  return rest.endsWith('/') ? rest.slice(0, -1) : rest;
}

/** Breadcrumb segments of a prefix. */
export function segments(prefix: string): string[] {
  return prefix.split('/').filter((s) => s !== '');
}

/** The prefix of the first `n` segments ("" for 0). */
export function prefixOf(segs: string[], n: number): string {
  return n <= 0 ? '' : `${segs.slice(0, n).join('/')}/`;
}

/** The parent folder of a prefix ("a/b/" → "a/", "a/" → ""). */
export function upPrefix(prefix: string): string {
  const s = segments(prefix);
  return prefixOf(s, s.length - 1);
}

// ------------------------------------------------------------ listing

const matches = (name: string, filter: string) => filter === '' || name.toLowerCase().includes(filter.toLowerCase());
const byName = (a: string, b: string) => {
  const x = a.toLowerCase();
  const y = b.toLowerCase();
  return x < y ? -1 : x > y ? 1 : 0;
};

/** Sub-folders that match the filter, by name (reversed only for a descending name sort). */
export function visibleFolders(folders: string[], prefix: string, filter: string, sort: SortKey, asc: boolean): string[] {
  const list = folders.filter((f) => f !== prefix && matches(folderName(prefix, f), filter.trim()));
  list.sort(byName);
  return sort === 'name' && !asc ? list.reverse() : list;
}

/** Objects that match the filter, sorted; the folder's own marker ("photos/" inside photos/) is hidden. */
export function visibleObjects(objects: S3Object[], prefix: string, filter: string, sort: SortKey, asc: boolean): S3Object[] {
  const f = filter.trim();
  const list = objects.filter((o) => o.key !== prefix && matches(fileName(o.key), f));
  const cmp = (a: S3Object, b: S3Object): number => {
    switch (sort) {
      case 'size': return a.size - b.size;
      case 'modified': return (Date.parse(a.last_modified) || 0) - (Date.parse(b.last_modified) || 0);
      default: return byName(fileName(a.key), fileName(b.key));
    }
  };
  list.sort((a, b) => (asc ? cmp(a, b) : cmp(b, a)));
  return list;
}

/** Clicking a column: the same one flips the order, a new one starts ascending for NAME, descending otherwise. */
export function nextSort(cur: SortKey, asc: boolean, clicked: SortKey): { sort: SortKey; asc: boolean } {
  if (cur === clicked) return { sort: cur, asc: !asc };
  return { sort: clicked, asc: clicked === 'name' };
}

/** Appends a "Load more" page: new folders only, objects not seen yet. */
export function mergePage(folders: string[], objects: S3Object[], page: { prefixes?: string[] | null; objects?: S3Object[] | null }) {
  const seenF = new Set(folders);
  const seenO = new Set(objects.map((o) => o.key));
  return {
    folders: [...folders, ...(page.prefixes ?? []).filter((p) => !seenF.has(p))],
    objects: [...objects, ...(page.objects ?? []).filter((o) => !seenO.has(o.key))],
  };
}

/** Keeps only the selected keys still listed. */
export function pruneSelection(selected: Iterable<string>, objects: S3Object[]): Set<string> {
  const keys = new Set(objects.map((o) => o.key));
  return new Set([...selected].filter((k) => keys.has(k)));
}

// ------------------------------------------------------------ local paths

const sepOf = (path: string) => (path.includes('\\') ? '\\' : '/');

/** The folder of a local path ("C:\a\b.txt" → "C:\a", "/a/b" → "/a"). */
export function dirName(path: string): string {
  const p = path.replace(/[\\/]+$/, '');
  const i = Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\'));
  if (i < 0) return p;
  if (i === 0) return p.slice(0, 1);
  const d = p.slice(0, i);
  return /^[A-Za-z]:$/.test(d) ? `${d}\\` : d;
}

/** Joins a local folder and a file name with the folder's own separator. */
export function joinPath(dir: string, name: string): string {
  if (!dir) return name;
  const sep = sepOf(dir);
  return dir.endsWith('/') || dir.endsWith('\\') ? `${dir}${name}` : `${dir}${sep}${name}`;
}

/** "photo.jpg" → ["photo", ".jpg"]; ".bashrc" → [".bashrc", ""]. */
export function splitExt(name: string): [string, string] {
  const i = name.lastIndexOf('.');
  if (i <= 0) return [name, ''];
  return [name.slice(0, i), name.slice(i)];
}

/**
 * A free path for `name` in `dir`: "a.txt", then "a (1).txt", "a (2).txt", …
 * skipping paths already taken in this batch (`used`, updated) or on disk.
 */
export async function uniquePath(dir: string, name: string, used: Set<string>, exists: (p: string) => Promise<boolean>): Promise<string> {
  const [base, ext] = splitExt(name);
  let target = joinPath(dir, name);
  let n = 1;
  const taken = async (p: string) => used.has(p.toLowerCase()) || (await exists(p));
  while (await taken(target)) {
    target = joinPath(dir, `${base} (${n})${ext}`);
    n++;
  }
  used.add(target.toLowerCase());
  return target;
}

// ------------------------------------------------------------ previews

export type PreviewKind = 'image' | 'text' | 'pdf' | 'media' | 'none';

const IMAGE_EXTS = new Set(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'ico']);
const TEXT_EXTS = new Set([
  'txt', 'md', 'log', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml', 'toml', 'ini', 'conf', 'env', 'js', 'mjs', 'ts', 'dart',
  'go', 'py', 'rb', 'rs', 'java', 'kt', 'c', 'h', 'cpp', 'cs', 'php', 'sh', 'ps1', 'sql', 'html', 'htm', 'css', 'svg', 'srt', 'vtt',
]);
const MEDIA_EXTS = new Set(['mp4', 'mov', 'mkv', 'webm', 'avi', 'mp3', 'wav', 'flac', 'ogg', 'm4a']);
const AUDIO_EXTS = new Set(['mp3', 'wav', 'flac', 'ogg', 'm4a']);

export const MAX_IMAGE_BYTES = 25 * 1024 * 1024;
export const MAX_TEXT_BYTES = 256 * 1024;
export const MAX_PDF_BYTES = 60 * 1024 * 1024;
/** Without Range support a text preview reads the whole object, so only up to this size. */
export const MAX_TEXT_NO_RANGE = 4 * 1024 * 1024;

export function previewKind(key: string, contentType = ''): PreviewKind {
  const ext = extOf(key);
  const ct = contentType.toLowerCase();
  if (IMAGE_EXTS.has(ext) || (ct.startsWith('image/') && ext !== 'svg' && !ct.startsWith('image/svg'))) return 'image';
  if (ext === 'pdf' || ct === 'application/pdf') return 'pdf';
  if (TEXT_EXTS.has(ext) || ct.startsWith('text/') || ct.includes('json') || ct.includes('xml')) return 'text';
  if (ct.startsWith('video/') || ct.startsWith('audio/') || MEDIA_EXTS.has(ext)) return 'media';
  return 'none';
}

export const isAudio = (key: string, contentType = '') => contentType.startsWith('audio/') || AUDIO_EXTS.has(extOf(key));
export const isJson = (key: string, contentType = '') => extOf(key) === 'json' || contentType.includes('json');

/** JSON pretty-printed with two spaces; the text unchanged when it is not JSON. */
export function prettyJson(text: string): string {
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch {
    return text;
  }
}

/** Image types the share dialog offers resize parameters for. */
const SHARE_IMAGE_EXTS = new Set(['jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'bmp']);
export const isShareImage = (key: string) => SHARE_IMAGE_EXTS.has(extOf(key));

// ------------------------------------------------------------ share

/** The port of a listen address (":9000", "0.0.0.0:9000", "[::]:9000" → "9000"). */
export function listenPort(listen: string | undefined): string {
  if (!listen) return '';
  const i = listen.lastIndexOf(':');
  return i >= 0 ? listen.slice(i + 1) : listen;
}

/**
 * The S3 endpoint for links: the server's public S3 URL when set, else the
 * Admin API host with the S3 port and scheme from the status (null when the
 * status has no S3 section).
 */
export function s3Endpoint(override: string | null | undefined, adminUrl: string | undefined, s3: { listen?: string; tls?: boolean } | undefined): string | null {
  if (override && override.trim()) return override.trim();
  if (!s3 || !adminUrl) return null;
  let host: string;
  try {
    host = new URL(adminUrl).hostname;
  } catch {
    return null;
  }
  if (!host) return null;
  if (host.includes(':') && !host.startsWith('[')) host = `[${host}]`;
  const port = listenPort(s3.listen);
  return `${s3.tls ? 'https' : 'http'}://${host}${port ? `:${port}` : ''}`;
}

/** Whether an endpoint can be used: http(s) with a host. */
export function validEndpoint(ep: string): boolean {
  try {
    const u = new URL(ep.trim());
    return (u.protocol === 'http:' || u.protocol === 'https:') && u.hostname !== '';
  } catch {
    return false;
  }
}

const UNRESERVED = /[A-Za-z0-9\-_.~]/;

/** RFC 3986 encoding as SigV4 wants it ("/" kept only for paths). */
export function awsEncode(s: string, keepSlash = false): string {
  let out = '';
  for (const b of new TextEncoder().encode(s)) {
    const ch = String.fromCharCode(b);
    if ((b < 128 && UNRESERVED.test(ch)) || (keepSlash && ch === '/')) out += ch;
    else out += `%${b.toString(16).toUpperCase().padStart(2, '0')}`;
  }
  return out;
}

/** Path-style object URL: `{endpoint}/{bucket}/{key}` plus an optional query. */
export function objectUrl(endpoint: string, bucket: string, key: string, query: [string, string][] = []): string {
  const e = endpoint.trim().replace(/\/+$/, '');
  const base = `${e}/${awsEncode(bucket)}/${awsEncode(key, true)}`;
  if (!query.length) return base;
  return `${base}?${query.map(([k, v]) => `${awsEncode(k)}=${awsEncode(v)}`).join('&')}`;
}

// ------------------------------------------------------------ move / copy

export type MoveCopyError = 'leading-slash' | 'same' | 'into-itself' | 'slash-in-name' | 'other-folder' | null;

export interface MoveCopyInput {
  bucket: string;
  /** Object key, folder prefix ("a/b/"), or for a selection the open folder. */
  sourceKey: string;
  isFolder: boolean;
  renameOnly: boolean;
  /** Set when moving a selection of objects. */
  count?: number;
  destBucket: string;
  /** What the user typed. */
  dest: string;
}

/** The parent prefix of the source ("a/b/c.txt" → "a/b/", "a/b/" → "a/"). */
export function sourceParent(sourceKey: string, isFolder: boolean): string {
  const k = isFolder && sourceKey.endsWith('/') ? sourceKey.slice(0, -1) : sourceKey;
  const i = k.lastIndexOf('/');
  return i < 0 ? '' : k.slice(0, i + 1);
}

/** The destination key or folder prefix from the input. */
export function moveCopyTarget(i: MoveCopyInput): string {
  let v = i.dest.trim();
  if (i.renameOnly) v = sourceParent(i.sourceKey, i.isFolder) + v;
  if ((i.isFolder || i.count !== undefined) && v !== '' && !v.endsWith('/')) v = `${v}/`;
  return v;
}

/** What is wrong with the destination, or null. */
export function moveCopyError(i: MoveCopyInput): MoveCopyError {
  const target = moveCopyTarget(i);
  const multi = i.count !== undefined;
  const sameBucket = i.destBucket === i.bucket;
  if ((!multi && i.dest.trim() === '') || target.startsWith('/')) return 'leading-slash';
  if (multi) return target === i.sourceKey && sameBucket ? 'other-folder' : null;
  if (i.renameOnly && i.dest.includes('/')) return 'slash-in-name';
  if (target === i.sourceKey && sameBucket) return 'same';
  if (i.isFolder && sameBucket && target.startsWith(i.sourceKey)) return 'into-itself';
  return null;
}

// ------------------------------------------------------------ metadata

/** Metadata keys after lower-casing: letters, digits and "-". */
export const validMetaKey = (k: string) => /^[a-z0-9-]+$/.test(k);

/** Builds the metadata map from editor rows; empty keys are skipped. Returns the first bad key instead when there is one. */
export function metadataFromRows(rows: { key: string; value: string }[]): { meta: Record<string, string> } | { bad: string } {
  const meta: Record<string, string> = {};
  for (const r of rows) {
    const k = r.key.trim().toLowerCase();
    if (!k) continue;
    if (!validMetaKey(k)) return { bad: k };
    meta[k] = r.value;
  }
  return { meta };
}

/** S3's unversioned id. */
export const isNullVersion = (id: string | undefined | null) => !id || id === 'null';
