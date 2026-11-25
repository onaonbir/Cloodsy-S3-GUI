// UI strings. The English text is the key; Turkish comes from i18n/tr*.json
// (tr.json carried over from 2.0, the others added per area in 3.0). Missing
// keys fall back to English. `{name}` placeholders are filled from the params.

import { ref } from 'vue';

const trFiles = import.meta.glob<Record<string, string>>('../i18n/tr*.json', { eager: true, import: 'default' });

export type Locale = 'en' | 'tr';
const tables: Record<Locale, Record<string, string>> = { en: {}, tr: Object.assign({}, ...Object.values(trFiles)) };

/** The active language (reactive: templates re-render when it changes). */
export const locale = ref<Locale>(systemLocale());

export function systemLocale(): Locale {
  return (navigator.language || 'en').toLowerCase().startsWith('tr') ? 'tr' : 'en';
}

/** Sets the language: 'en', 'tr' or null/'' to follow the system. */
export function setLocale(pref: string | null | undefined) {
  locale.value = pref === 'en' || pref === 'tr' ? pref : systemLocale();
  document.documentElement.lang = locale.value;
}

export function t(en: string, params?: Record<string, string | number>): string {
  const s = tables[locale.value][en] ?? en;
  if (!params) return s;
  return s.replace(/\{(\w+)\}/g, (m, k) => (k in params ? String(params[k]) : m));
}

/** `{n}` filled in; `one` when n is 1. */
export function tn(n: number, one: string, many: string, params?: Record<string, string | number>): string {
  return t(n === 1 ? one : many, { n, ...params });
}

export function hasTranslation(en: string, loc: Locale = 'tr'): boolean {
  return en in tables[loc];
}
