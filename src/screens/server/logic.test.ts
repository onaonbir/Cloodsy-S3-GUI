import { describe, expect, it } from 'vitest';
import { agentLabel, appendTail, clientKind, errorRate, isGuiAgent, logLineText, methodSummary, nextSinceId, toLogLine } from './logic';

describe('appendTail', () => {
  it('appends and keeps the newest lines only', () => {
    expect(appendTail([1, 2], [3], 5)).toEqual([1, 2, 3]);
    expect(appendTail([1, 2, 3, 4], [5, 6, 7], 5)).toEqual([3, 4, 5, 6, 7]);
    expect(appendTail([], [1, 2, 3, 4, 5, 6, 7], 3)).toEqual([5, 6, 7]);
  });

  it('returns the same array when nothing is new', () => {
    const a = [1, 2];
    expect(appendTail(a, [])).toBe(a);
  });

  it('caps at 3000 by default', () => {
    const r = appendTail(Array.from({ length: 2990 }, (_, i) => i), Array.from({ length: 20 }, (_, i) => 2990 + i));
    expect(r).toHaveLength(3000);
    expect(r[0]).toBe(10);
    expect(r[2999]).toBe(3009);
  });
});

describe('nextSinceId', () => {
  it('prefers the server last_id', () => expect(nextSinceId(4, 17, [{ id: 9 }])).toBe(17));
  it('falls back to the newest line', () => expect(nextSinceId(4, undefined, [{ id: 8 }, { id: 9 }])).toBe(9));
  it('keeps the previous id when nothing came', () => expect(nextSinceId(4, 0, [])).toBe(4));
});

describe('log lines', () => {
  it('normalises entries and copies them as text', () => {
    const l = toLogLine({ id: 1, time: '2026-11-25T10:00:00Z', level: 'warn', message: 'slow request', attrs: { ms: 1200, path: '/a', tags: ['x'] } });
    expect(l.level).toBe('WARN');
    expect(l.attrs).toEqual([['ms', '1200'], ['path', '/a'], ['tags', '["x"]']]);
    expect(logLineText(l)).toBe('2026-11-25T10:00:00Z WARN slow request ms=1200 path=/a tags=["x"]');
  });
});

describe('user agents', () => {
  it('recognises this app and 2.0', () => {
    expect(isGuiAgent('CloodsyS3GUI/3.0.0 (windows; x86_64)')).toBe(true);
    expect(isGuiAgent('Dart/3.5 (dart:io)')).toBe(true);
    expect(agentLabel('CloodsyS3GUI/3.0.0 (macos; aarch64)')).toBe('Cloodsy S3 GUI');
    expect(agentLabel('Dart/3.5 (dart:io)')).toBe('Cloodsy S3 GUI');
    expect(clientKind('CloodsyS3GUI/3.0.0 (linux; x86_64)')).toBe('gui');
  });

  it('labels other clients', () => {
    expect(clientKind('curl/8.4.0')).toBe('cli');
    expect(clientKind('python-requests/2.31')).toBe('cli');
    expect(clientKind('Mozilla/5.0 (Windows NT 10.0)')).toBe('browser');
    expect(clientKind('aws-sdk-go/1.0')).toBe('other');
    expect(agentLabel('')).toBeNull();
    expect(agentLabel('curl/8.4.0')).toBe('curl/8.4.0');
    const long = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0';
    expect(agentLabel(long)).toBe(`${long.slice(0, 60)}…`);
  });
});

describe('metrics', () => {
  it('summarises methods busiest first', () => {
    expect(methodSummary({ PUT: 3, GET: 12, HEAD: 3 })).toBe('GET 12 · HEAD 3 · PUT 3');
    expect(methodSummary({})).toBe('');
  });

  it('computes the error rate', () => {
    expect(errorRate(0, 0, 0)).toBe(0);
    expect(errorRate(200, 3, 1)).toBeCloseTo(0.02);
  });
});
