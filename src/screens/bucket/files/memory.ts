// The folder last open per bucket, so switching tabs and coming back keeps
// it. Keyed by session generation: a new session starts at the root.

import { generation, serverId } from '@/stores/session';

const last = new Map<string, string>();
const k = (bucket: string) => `${serverId.value}:${generation.value}:${bucket}`;

export const rememberedPrefix = (bucket: string) => last.get(k(bucket));
export const rememberPrefix = (bucket: string, prefix: string) => void last.set(k(bucket), prefix);
