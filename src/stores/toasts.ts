// Toasts: 3 s, errors 6 s (2.0 behaviour).

import { ref } from 'vue';
import { t } from '@/lib/i18n';
import type { ApiError } from '@/lib/ipc';

export interface Toast { id: number; text: string; error: boolean }
export const toasts = ref<Toast[]>([]);
let next = 1;

export function toast(text: string, error = false) {
  const id = next++;
  toasts.value.push({ id, text, error });
  setTimeout(() => (toasts.value = toasts.value.filter((x) => x.id !== id)), error ? 6000 : 3000);
}

export const toastError = (e: unknown) => toast(e instanceof Error ? e.message : String(e), true);

/** Runs an action with a success toast, or an error toast when it fails. */
export async function runAction<T>(fn: () => Promise<T>, success?: string): Promise<T | undefined> {
  try {
    const r = await fn();
    if (success) toast(success);
    return r;
  } catch (e) {
    if ((e as ApiError).status !== -1) toastError(e);
    return undefined;
  }
}

export async function copyText(text: string, label?: string) {
  await navigator.clipboard.writeText(text);
  toast(label ? t('{label} copied', { label }) : t('Copied'));
}
