// Pure helpers of the server pages (kept free of Vue and i18n for tests).

import type { LogEntry } from '@/lib/api';

// ---- activity log ----------------------------------------------------------

/** Lines kept in the activity log view. */
export const LOG_MAX = 3000;

/** The tail after a poll: old + new lines, the oldest dropped beyond `max`. */
export function appendTail<T>(entries: readonly T[], fresh: readonly T[], max = LOG_MAX): T[] {
  if (!fresh.length) return entries as T[];
  const all = entries.concat(fresh);
  return all.length > max ? all.slice(all.length - max) : all;
}

/** The next `since_id`: the server's `last_id`, else the newest line's id. */
export function nextSinceId(prev: number, lastId: number | null | undefined, fresh: readonly { id: number }[]): number {
  if (typeof lastId === 'number' && lastId > 0) return lastId;
  return fresh.length ? fresh[fresh.length - 1].id : prev;
}

/** A log line as the server sent it, level upper-cased and attributes as text. */
export interface LogLine { id: number; time: string; level: string; message: string; attrs: [string, string][] }

export function attrText(v: unknown): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  try {
    return JSON.stringify(v);
  } catch {
    return String(v);
  }
}

export function toLogLine(e: LogEntry): LogLine {
  return {
    id: e.id,
    time: e.time ?? '',
    level: (e.level || 'INFO').toUpperCase(),
    message: e.message ?? '',
    attrs: Object.entries(e.attrs ?? {}).map(([k, v]) => [k, attrText(v)]),
  };
}

/** "time LEVEL message k=v k=v" (Copy visible lines). */
export function logLineText(l: LogLine): string {
  return [l.time, l.level, l.message, ...l.attrs.map(([k, v]) => `${k}=${v}`)].filter((p) => p !== '').join(' ');
}

// ---- sessions --------------------------------------------------------------

export type ClientKind = 'gui' | 'cli' | 'browser' | 'other';

/** This app's User-Agent ("CloodsyS3GUI/3.0.0 (windows; x86_64)"), or 2.0's Dart client. */
export function isGuiAgent(ua: string): boolean {
  const u = ua.trim().toLowerCase();
  return u.startsWith('cloodsys3gui/') || u.startsWith('dart');
}

export function clientKind(ua: string): ClientKind {
  const u = ua.toLowerCase();
  if (isGuiAgent(ua) || u.includes('cloodsy')) return 'gui';
  if (u.includes('curl') || u.includes('python') || u.includes('go-http') || u.includes('wget') || u.includes('httpie')) return 'cli';
  if (u.includes('mozilla')) return 'browser';
  return 'other';
}

/** "Cloodsy S3 GUI" for this app, else the User-Agent cut to 60 characters; null when empty. */
export function agentLabel(ua: string, max = 60): string | null {
  const s = ua.trim();
  if (!s) return null;
  if (isGuiAgent(s)) return 'Cloodsy S3 GUI';
  const chars = [...s];
  return chars.length > max ? `${chars.slice(0, max).join('')}…` : s;
}

// ---- metrics ---------------------------------------------------------------

/** "GET 12 · PUT 3", busiest first. */
export function methodSummary(byMethod: Record<string, number> | null | undefined, fmt: (n: number) => string = String): string {
  return Object.entries(byMethod ?? {})
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([m, n]) => `${m} ${fmt(n)}`)
    .join(' · ');
}

/** Errors as a share of requests, 0–1. */
export function errorRate(requests: number, e4xx: number, e5xx: number): number {
  return requests > 0 ? (e4xx + e5xx) / requests : 0;
}
