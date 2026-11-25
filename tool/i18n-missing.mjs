// Lists t('…') / tn(n, '…', '…') strings under src/ that have no Turkish entry
// in src/i18n/tr*.json. `node tool/i18n-missing.mjs [dir]` (exit 1 if any).
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..');
const scan = path.resolve(root, process.argv[2] ?? 'src');
const i18nDir = path.join(root, 'src', 'i18n');
const tr = {};
for (const f of fs.readdirSync(i18nDir)) if (/^tr.*\.json$/.test(f)) Object.assign(tr, JSON.parse(fs.readFileSync(path.join(i18nDir, f), 'utf8')));

const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.(ts|vue)$/.test(e.name) && !e.name.endsWith('.test.ts')) files.push(p);
  }
})(scan);

// String literals passed to t( or as the 2nd/3rd argument of tn(.
const lit = String.raw`'((?:[^'\\]|\\.)*)'`;
const reT = new RegExp(String.raw`\bt\(\s*` + lit, 'g');
const reTn = new RegExp(String.raw`\btn\(\s*[^,]+,\s*` + lit + String.raw`\s*,\s*` + lit, 'g');
const unescape = (s) => s.replace(/\\'/g, "'").replace(/\\\\/g, '\\');
const missing = new Map();
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  for (const m of src.matchAll(reT)) { const k = unescape(m[1]); if (!(k in tr)) missing.set(k, path.relative(root, f)); }
  for (const m of src.matchAll(reTn)) for (const k of [unescape(m[1]), unescape(m[2])]) if (!(k in tr)) missing.set(k, path.relative(root, f));
}
for (const [k, f] of missing) console.log(`${f}\t${k}`);
console.error(`${missing.size} missing`);
process.exit(missing.size ? 1 : 0);
