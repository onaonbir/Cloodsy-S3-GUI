// Preferences: theme, language, notifications, last folders. Kept by the Rust
// side in settings.json.

import { ref, watch } from 'vue';
import { ipc } from '@/lib/ipc';
import { setLocale } from '@/lib/i18n';

export type ThemeMode = 'light' | 'dark' | 'system';

export const prefs = ref<Record<string, string>>({});
export const themeMode = ref<ThemeMode>('system');
const systemDark = window.matchMedia('(prefers-color-scheme: dark)');
export const isDark = ref(false);

function applyTheme() {
  isDark.value = themeMode.value === 'dark' || (themeMode.value === 'system' && systemDark.matches);
  document.documentElement.dataset.theme = isDark.value ? 'dark' : 'light';
}
systemDark.addEventListener('change', applyTheme);
watch(themeMode, applyTheme);

export function pref(key: string): string | undefined {
  return prefs.value[key];
}

export async function setPref(key: string, value: string | null) {
  if (value === null) delete prefs.value[key];
  else prefs.value[key] = value;
  await ipc.setPref(key, value);
}

export async function setTheme(mode: ThemeMode) {
  themeMode.value = mode;
  await setPref('theme_mode', mode);
}

/** Title bar click: flip light/dark from what is shown now. */
export function toggleTheme() {
  return setTheme(isDark.value ? 'light' : 'dark');
}

/** 'en' | 'tr' | null (follow the system). */
export async function setLanguage(lang: 'en' | 'tr' | null) {
  setLocale(lang);
  await setPref('locale', lang);
}

export function initPrefs(p: Record<string, string>) {
  prefs.value = { ...p };
  const m = p.theme_mode;
  themeMode.value = m === 'light' || m === 'dark' ? m : 'system';
  applyTheme();
  setLocale(p.locale);
}
