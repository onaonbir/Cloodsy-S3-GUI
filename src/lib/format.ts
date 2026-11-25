// Display formatting shared by every screen (2.0 lib/core/format.dart).

import { t, tn } from './i18n';

export function formatBytes(bytes: number, decimals = 1): string {
  if (bytes == null || bytes < 0 || Number.isNaN(bytes)) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit === 0) return `${bytes} B`;
  return `${value.toFixed(value >= 100 ? 0 : decimals)} ${units[unit]}`;
}

/** 1234567 → "1,234,567". */
export function formatCount(n: number): string {
  const s = Math.abs(Math.trunc(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return n < 0 ? `-${s}` : s;
}

export function parseServerDate(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

const two = (v: number) => String(v).padStart(2, '0');

/** "2026-11-14". */
export function formatDate(iso: string | null | undefined): string {
  const d = parseServerDate(iso);
  if (!d) return iso || '—';
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}`;
}

/** "2026-11-14 09:05". */
export function formatDateTime(iso: string | null | undefined): string {
  const d = parseServerDate(iso);
  if (!d) return iso || '—';
  return `${formatDate(iso)} ${two(d.getHours())}:${two(d.getMinutes())}`;
}

/** "HH:MM:SS". */
export function formatTime(iso: string | null | undefined): string {
  const d = parseServerDate(iso);
  if (!d) return iso || '—';
  return `${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
}

/** "just now", "5 min ago", "3 h ago", "yesterday", "2 days ago", else the date. */
export function formatRelative(iso: string | null | undefined, now: Date = new Date()): string {
  const d = parseServerDate(iso);
  if (!d) return iso || '—';
  const secs = (now.getTime() - d.getTime()) / 1000;
  if (secs < 60) return t('just now');
  const mins = Math.floor(secs / 60);
  if (mins < 60) return t('{n} min ago', { n: mins });
  const hours = Math.floor(mins / 60);
  if (hours < 24) return t('{n} h ago', { n: hours });
  const days = Math.floor(hours / 24);
  if (days < 30) return days === 1 ? t('yesterday') : tn(days, '{n} day ago', '{n} days ago');
  return formatDate(iso);
}

/** Time until a future moment: "in 5 min", "in 3 h". */
export function formatIn(unixSeconds: number, now: number = Date.now() / 1000): string {
  const secs = unixSeconds - now;
  if (secs < 60) return t('in under a minute');
  const mins = Math.floor(secs / 60);
  if (mins < 60) return t('in {n} min', { n: mins });
  return t('in {n} h', { n: Math.floor(mins / 60) });
}

/** 93784 → "1d 2h 3m". */
export function formatUptime(seconds: number): string {
  if (!seconds || seconds <= 0) return '—';
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

/** Compares dotted versions numerically ("1.10.0" > "1.9.2"); pre-release suffixes are ignored. */
export function compareVersions(a: string, b: string): number {
  const parts = (v: string) => v.replace(/^v/, '').split('-')[0].split('.').map((e) => parseInt(e, 10) || 0);
  const ap = parts(a);
  const bp = parts(b);
  for (let i = 0; i < Math.max(ap.length, bp.length); i++) {
    const av = ap[i] ?? 0;
    const bv = bp[i] ?? 0;
    if (av !== bv) return av < bv ? -1 : 1;
  }
  return 0;
}

/** Parses "10", "1.5 GB", "512mb" into bytes; null when invalid. */
export function parseSize(input: string, defaultUnit = 'GB'): number | null {
  const m = /^\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)\s*$/.exec(input);
  if (!m) return null;
  const unit = (m[2] || defaultUnit).toUpperCase();
  const mult: Record<string, number> = { B: 1, K: 1024, KB: 1024, M: 1024 ** 2, MB: 1024 ** 2, G: 1024 ** 3, GB: 1024 ** 3, T: 1024 ** 4, TB: 1024 ** 4 };
  const f = mult[unit];
  return f ? Math.round(parseFloat(m[1]) * f) : null;
}

/** Lower-cased extension without the dot, or ''. */
export function fileExtension(name: string): string {
  const i = name.lastIndexOf('.');
  if (i <= 0 || i === name.length - 1) return '';
  return name.slice(i + 1).toLowerCase();
}

const TYPES: Record<string, string> = {
  txt: 'text/plain', md: 'text/markdown', csv: 'text/csv', log: 'text/plain', html: 'text/html', htm: 'text/html',
  css: 'text/css', js: 'text/javascript', mjs: 'text/javascript', json: 'application/json', xml: 'application/xml',
  yaml: 'application/yaml', yml: 'application/yaml', pdf: 'application/pdf', zip: 'application/zip',
  gz: 'application/gzip', tar: 'application/x-tar', '7z': 'application/x-7z-compressed', rar: 'application/vnd.rar',
  wasm: 'application/wasm', jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif',
  webp: 'image/webp', avif: 'image/avif', svg: 'image/svg+xml', ico: 'image/x-icon', mp4: 'video/mp4',
  webm: 'video/webm', mov: 'video/quicktime', mkv: 'video/x-matroska', mp3: 'audio/mpeg', wav: 'audio/wav',
  flac: 'audio/flac', ogg: 'audio/ogg', woff: 'font/woff', woff2: 'font/woff2', ttf: 'font/ttf',
};

/** Best-effort content type from a file name, for uploads. */
export function guessContentType(name: string): string {
  return TYPES[fileExtension(name)] ?? 'application/octet-stream';
}

/** The last path segment of a key or prefix ("a/b/" → "b"). */
export function baseName(key: string): string {
  const k = key.endsWith('/') ? key.slice(0, -1) : key;
  return k.slice(k.lastIndexOf('/') + 1);
}

/** "a/b/c.txt" → "a/b/". */
export function parentPrefix(key: string): string {
  const k = key.endsWith('/') ? key.slice(0, -1) : key;
  const i = k.lastIndexOf('/');
  return i < 0 ? '' : k.slice(0, i + 1);
}
