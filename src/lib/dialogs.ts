// confirm() and prompt() as promises; DialogHost renders them.

import { shallowRef } from 'vue';

export interface ConfirmOptions {
  title: string;
  message?: string;
  /** Extra detail under the message (monospace, e.g. a key). */
  detail?: string;
  confirmLabel?: string;
  danger?: boolean;
  /** The user must type this text to enable the button. */
  typeToConfirm?: string;
}

export interface PromptOptions {
  title: string;
  label?: string;
  initial?: string;
  placeholder?: string;
  confirmLabel?: string;
  hint?: string;
  /** Answers an error message, or null when the value is fine. */
  validate?: (v: string) => string | null;
}

type Pending =
  | { kind: 'confirm'; opts: ConfirmOptions; resolve: (v: boolean) => void }
  | { kind: 'prompt'; opts: PromptOptions; resolve: (v: string | null) => void };

export const pending = shallowRef<Pending | null>(null);

export function confirm(opts: ConfirmOptions): Promise<boolean> {
  return new Promise((resolve) => (pending.value = { kind: 'confirm', opts, resolve }));
}

export function prompt(opts: PromptOptions): Promise<string | null> {
  return new Promise((resolve) => (pending.value = { kind: 'prompt', opts, resolve }));
}

export function settle(value: boolean | string | null) {
  const p = pending.value;
  pending.value = null;
  if (!p) return;
  if (p.kind === 'confirm') p.resolve(value === true);
  else p.resolve(typeof value === 'string' ? value : null);
}
