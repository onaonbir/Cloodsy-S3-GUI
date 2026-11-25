// Saved servers (settings.json; passwords in the keychain).

import { ref } from 'vue';
import { ipc, type Server } from '@/lib/ipc';

export const servers = ref<Server[]>([]);

export function initServers(list: Server[]) {
  servers.value = list;
}

export async function saveServer(server: Server, password: string | null): Promise<Server> {
  const saved = await ipc.saveServer(server, password);
  const i = servers.value.findIndex((s) => s.id === saved.id);
  if (i >= 0) servers.value[i] = saved;
  else servers.value.push(saved);
  return saved;
}

export async function removeServer(id: string) {
  await ipc.removeServer(id);
  servers.value = servers.value.filter((s) => s.id !== id);
}

export const serverById = (id: string | null | undefined) => servers.value.find((s) => s.id === id) ?? null;

/** "host:port" of a server URL. */
export function hostOf(url: string): string {
  try {
    return new URL(url).host;
  } catch {
    return url;
  }
}

export function hostnameOf(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

/** Validates an Admin API URL; null when fine, else the (English) problem. */
export function validateServerUrl(v: string): string | null {
  const s = v.trim();
  if (!s) return 'Required';
  let u: URL;
  try {
    u = new URL(s);
  } catch {
    return 'Include the scheme, e.g. https://host:9001';
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return 'Use http:// or https://';
  if (!u.hostname) return 'Enter a host';
  return null;
}
