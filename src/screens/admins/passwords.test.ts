import { describe, expect, it } from 'vitest';
import { passwordProblem, toPasswordResult, utf8Length } from './passwords';

describe('passwordProblem', () => {
  it('needs at least 8 characters', () => {
    expect(passwordProblem('')).toBe('short');
    expect(passwordProblem('1234567')).toBe('short');
    expect(passwordProblem('12345678')).toBeNull();
  });

  it('counts characters, not UTF-16 units, for the minimum', () => {
    const emoji = String.fromCodePoint(0x1f600);
    expect(passwordProblem(emoji.repeat(4))).toBe('short'); // 8 UTF-16 units, 4 characters
    expect(passwordProblem('ş'.repeat(8))).toBeNull();
  });

  it('allows at most 72 UTF-8 bytes', () => {
    expect(passwordProblem('a'.repeat(72))).toBeNull();
    expect(passwordProblem('a'.repeat(73))).toBe('long');
    expect(utf8Length('ş'.repeat(36))).toBe(72);
    expect(passwordProblem('ş'.repeat(36))).toBeNull();
    expect(passwordProblem('ş'.repeat(37))).toBe('long'); // 37 characters, 74 bytes
  });
});

describe('toPasswordResult', () => {
  it('uses the generated password from the server', () => {
    expect(toPasswordResult({ username: 'ops', password: 'gen-123', auto_generated: true }, 'ops', '')).toEqual({ username: 'ops', password: 'gen-123', generated: true });
  });

  it('falls back to what was asked for', () => {
    expect(toPasswordResult({}, 'ops', 'my-secret-pw')).toEqual({ username: 'ops', password: 'my-secret-pw', generated: false });
    expect(toPasswordResult(null, 'ops', 'my-secret-pw').password).toBe('my-secret-pw');
  });
});
