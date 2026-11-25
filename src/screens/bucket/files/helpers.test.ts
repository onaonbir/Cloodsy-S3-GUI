import { describe, expect, it } from 'vitest';
import type { S3Object } from '@/lib/api';
import {
  awsEncode, dirName, extOf, fileName, folderName, joinPath, listenPort, mergePage, metadataFromRows, moveCopyError,
  moveCopyTarget, nextSort, objectUrl, prettyJson, previewKind, pruneSelection, s3Endpoint, segments, splitExt, uniquePath,
  upPrefix, validEndpoint, visibleFolders, visibleObjects, type MoveCopyInput,
} from './helpers';

const obj = (key: string, size = 0, last_modified = '2026-01-01T00:00:00Z'): S3Object => ({ key, size, etag: '', last_modified });

describe('names', () => {
  it('splits keys and prefixes', () => {
    expect(fileName('a/b/c.txt')).toBe('c.txt');
    expect(fileName('a/b/')).toBe('b');
    expect(fileName('top')).toBe('top');
    expect(extOf('a/Photo.JPG')).toBe('jpg');
    expect(extOf('a/.bashrc')).toBe('');
    expect(extOf('a/noext')).toBe('');
    expect(folderName('a/', 'a/b/')).toBe('b');
    expect(segments('a/b/')).toEqual(['a', 'b']);
    expect(segments('')).toEqual([]);
    expect(upPrefix('a/b/')).toBe('a/');
    expect(upPrefix('a/')).toBe('');
    expect(upPrefix('')).toBe('');
  });
});

describe('listing', () => {
  const objects = [obj('p/', 0), obj('p/b.txt', 30, '2026-01-03T00:00:00Z'), obj('p/A.txt', 10, '2026-01-02T00:00:00Z'), obj('p/c.bin', 20, '2026-01-01T00:00:00Z')];

  it('hides the folder marker and sorts by name case-insensitively', () => {
    expect(visibleObjects(objects, 'p/', '', 'name', true).map((o) => o.key)).toEqual(['p/A.txt', 'p/b.txt', 'p/c.bin']);
    expect(visibleObjects(objects, 'p/', '', 'name', false).map((o) => o.key)).toEqual(['p/c.bin', 'p/b.txt', 'p/A.txt']);
  });

  it('sorts by size and modified', () => {
    expect(visibleObjects(objects, 'p/', '', 'size', true).map((o) => o.size)).toEqual([10, 20, 30]);
    expect(visibleObjects(objects, 'p/', '', 'modified', false).map((o) => o.key)).toEqual(['p/b.txt', 'p/A.txt', 'p/c.bin']);
  });

  it('filters by name', () => {
    expect(visibleObjects(objects, 'p/', ' TXT ', 'name', true).map((o) => o.key)).toEqual(['p/A.txt', 'p/b.txt']);
  });

  it('keeps folders by name; reversed only for a descending name sort', () => {
    const f = ['p/zeta/', 'p/Alpha/', 'p/beta/'];
    expect(visibleFolders(f, 'p/', '', 'name', true)).toEqual(['p/Alpha/', 'p/beta/', 'p/zeta/']);
    expect(visibleFolders(f, 'p/', '', 'name', false)).toEqual(['p/zeta/', 'p/beta/', 'p/Alpha/']);
    expect(visibleFolders(f, 'p/', '', 'size', false)).toEqual(['p/Alpha/', 'p/beta/', 'p/zeta/']);
    expect(visibleFolders(f, 'p/', 'ET', 'name', true)).toEqual(['p/beta/', 'p/zeta/']);
  });

  it('flips or starts a sort', () => {
    expect(nextSort('name', true, 'name')).toEqual({ sort: 'name', asc: false });
    expect(nextSort('name', true, 'size')).toEqual({ sort: 'size', asc: false });
    expect(nextSort('size', false, 'name')).toEqual({ sort: 'name', asc: true });
  });

  it('merges pages without duplicates', () => {
    const m = mergePage(['a/'], [obj('x')], { prefixes: ['a/', 'b/'], objects: [obj('x'), obj('y')] });
    expect(m.folders).toEqual(['a/', 'b/']);
    expect(m.objects.map((o) => o.key)).toEqual(['x', 'y']);
    expect(mergePage([], [], { prefixes: null, objects: null })).toEqual({ folders: [], objects: [] });
  });

  it('prunes the selection to listed keys', () => {
    expect([...pruneSelection(['x', 'gone'], [obj('x'), obj('y')])]).toEqual(['x']);
  });
});

describe('local paths', () => {
  it('splits and joins Windows and POSIX paths', () => {
    expect(dirName('C:\\Users\\me\\a.txt')).toBe('C:\\Users\\me');
    expect(dirName('C:\\a.txt')).toBe('C:\\');
    expect(dirName('/home/me/a.txt')).toBe('/home/me');
    expect(dirName('/a.txt')).toBe('/');
    expect(dirName('/home/me/dir/')).toBe('/home/me');
    expect(joinPath('C:\\Users', 'a.txt')).toBe('C:\\Users\\a.txt');
    expect(joinPath('C:\\', 'a.txt')).toBe('C:\\a.txt');
    expect(joinPath('/home', 'a.txt')).toBe('/home/a.txt');
    expect(splitExt('a.tar.gz')).toEqual(['a.tar', '.gz']);
    expect(splitExt('.bashrc')).toEqual(['.bashrc', '']);
    expect(splitExt('README')).toEqual(['README', '']);
  });

  it('numbers colliding names " (n)"', async () => {
    const onDisk = new Set(['/d/a.txt', '/d/a (1).txt']);
    const exists = async (p: string) => onDisk.has(p);
    const used = new Set<string>();
    expect(await uniquePath('/d', 'a.txt', used, exists)).toBe('/d/a (2).txt');
    expect(await uniquePath('/d', 'a.txt', used, exists)).toBe('/d/a (3).txt');
    expect(await uniquePath('/d', 'b', used, exists)).toBe('/d/b');
    expect(await uniquePath('/d', 'b', used, exists)).toBe('/d/b (1)');
    // Case-insensitive within a batch (Windows/macOS file systems).
    expect(await uniquePath('/d', 'B', used, exists)).toBe('/d/B (2)');
  });
});

describe('previews', () => {
  it('picks the kind from extension and type', () => {
    expect(previewKind('a.PNG')).toBe('image');
    expect(previewKind('a', 'image/avif')).toBe('image');
    expect(previewKind('a.svg', 'image/svg+xml')).toBe('text');
    expect(previewKind('a.pdf')).toBe('pdf');
    expect(previewKind('a', 'application/pdf')).toBe('pdf');
    expect(previewKind('a.yaml')).toBe('text');
    expect(previewKind('a', 'application/vnd.api+json')).toBe('text');
    expect(previewKind('a.mkv')).toBe('media');
    expect(previewKind('a', 'audio/x-whatever')).toBe('media');
    expect(previewKind('a.zip', 'application/zip')).toBe('none');
  });

  it('pretty-prints JSON only when it parses', () => {
    expect(prettyJson('{"a":1}')).toBe('{\n  "a": 1\n}');
    expect(prettyJson('{"a":')).toBe('{"a":');
  });
});

describe('share', () => {
  it('builds the endpoint', () => {
    expect(listenPort(':9000')).toBe('9000');
    expect(listenPort('[::]:9000')).toBe('9000');
    expect(listenPort(undefined)).toBe('');
    expect(s3Endpoint('https://s3.example.com', 'http://x:8080', undefined)).toBe('https://s3.example.com');
    expect(s3Endpoint('', 'http://host.lan:8080/', { listen: ':9000', tls: false })).toBe('http://host.lan:9000');
    expect(s3Endpoint(null, 'https://[::1]:8080', { listen: '[::]:9443', tls: true })).toBe('https://[::1]:9443');
    expect(s3Endpoint('', 'http://h', undefined)).toBeNull();
  });

  it('validates endpoints', () => {
    expect(validEndpoint('http://a:9000')).toBe(true);
    expect(validEndpoint('a:9000')).toBe(false);
    expect(validEndpoint('')).toBe(false);
  });

  it('encodes object URLs path-style', () => {
    expect(awsEncode('a b/ç', true)).toBe('a%20b/%C3%A7');
    expect(awsEncode('a/b')).toBe('a%2Fb');
    expect(objectUrl('http://h:9000/', 'bkt', 'dir/my file.jpg')).toBe('http://h:9000/bkt/dir/my%20file.jpg');
    expect(objectUrl('http://h', 'b', 'k.jpg', [['w', '200'], ['q', '80']])).toBe('http://h/b/k.jpg?w=200&q=80');
  });
});

describe('move / copy', () => {
  const base: MoveCopyInput = { bucket: 'b', sourceKey: 'a/f.txt', isFolder: false, renameOnly: false, destBucket: 'b', dest: 'a/f.txt' };

  it('rejects empty, leading slash and same destination', () => {
    expect(moveCopyError({ ...base, dest: '' })).toBe('leading-slash');
    expect(moveCopyError({ ...base, dest: '/x' })).toBe('leading-slash');
    expect(moveCopyError(base)).toBe('same');
    expect(moveCopyError({ ...base, destBucket: 'other' })).toBeNull();
    expect(moveCopyError({ ...base, dest: 'b/f.txt' })).toBeNull();
  });

  it('renames within the parent, without "/"', () => {
    const r = { ...base, renameOnly: true, dest: 'g.txt' };
    expect(moveCopyTarget(r)).toBe('a/g.txt');
    expect(moveCopyError(r)).toBeNull();
    expect(moveCopyError({ ...r, dest: 'x/g.txt' })).toBe('slash-in-name');
    expect(moveCopyError({ ...r, dest: 'f.txt' })).toBe('same');
  });

  it('keeps folders out of themselves', () => {
    const f = { ...base, sourceKey: 'a/f/', isFolder: true, dest: 'a/f/sub' };
    expect(moveCopyTarget(f)).toBe('a/f/sub/');
    expect(moveCopyError(f)).toBe('into-itself');
    expect(moveCopyError({ ...f, destBucket: 'c' })).toBeNull();
    expect(moveCopyTarget({ ...f, renameOnly: true, dest: 'g' })).toBe('a/g/');
  });

  it('needs another folder or bucket for a selection', () => {
    const m = { ...base, sourceKey: 'a/', isFolder: true, count: 3, dest: 'a' };
    expect(moveCopyError(m)).toBe('other-folder');
    expect(moveCopyError({ ...m, dest: '' })).toBeNull();
    expect(moveCopyTarget({ ...m, dest: '' })).toBe('');
    expect(moveCopyError({ ...m, destBucket: 'c' })).toBeNull();
  });
});

describe('metadata', () => {
  it('lower-cases keys, skips empty ones and reports bad ones', () => {
    expect(metadataFromRows([{ key: ' Owner ', value: 'me' }, { key: '', value: 'x' }])).toEqual({ meta: { owner: 'me' } });
    expect(metadataFromRows([{ key: 'bad key', value: '' }])).toEqual({ bad: 'bad key' });
  });
});
