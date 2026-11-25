// Opens the add/edit server dialog; resolves with the saved server or null.

import { shallowRef } from 'vue';
import type { Server } from '@/lib/ipc';

export const serverDialog = shallowRef<{ server: Server | null; resolve: (s: Server | null) => void } | null>(null);

export function openServerDialog(server: Server | null): Promise<Server | null> {
  return new Promise((resolve) => (serverDialog.value = { server, resolve }));
}

export function closeServerDialog(saved: Server | null) {
  const d = serverDialog.value;
  serverDialog.value = null;
  d?.resolve(saved);
}
