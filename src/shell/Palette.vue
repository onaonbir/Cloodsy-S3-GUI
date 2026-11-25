<script setup lang="ts">
// Ctrl/Cmd+K: every typed word must appear in "title + group".
import { computed, nextTick, onMounted, ref, watch, type Component } from 'vue';
import {
  Activity, BarChart3, Database, FileCog, FolderOpen, LayoutDashboard, LogOut, MonitorSmartphone, Moon, Plus, Search, Server as ServerIcon,
  Settings2, Users, Wrench, ArrowRight,
} from 'lucide-vue-next';
import { closePalette } from './palette';
import { buckets, connect, disconnect, has, serverId } from '@/stores/session';
import { servers } from '@/stores/servers';
import { go, goBucket, openBucket, type BucketTab } from '@/stores/nav';
import { toggleTheme } from '@/stores/prefs';
import { toastError } from '@/stores/toasts';
import { createBucketFlow } from '@/screens/buckets/flows';
import { t } from '@/lib/i18n';

interface Cmd { title: string; group: string; icon: Component; run: () => void }

const query = ref('');
const index = ref(0);
const input = ref<HTMLInputElement | null>(null);
const list = ref<HTMLElement | null>(null);

const commands = computed<Cmd[]>(() => {
  const goTo = t('Go to');
  const c: Cmd[] = [
    { title: t('Dashboard'), group: goTo, icon: LayoutDashboard, run: () => go({ kind: 'dashboard' }) },
    { title: t('Buckets'), group: goTo, icon: Database, run: () => go({ kind: 'buckets' }) },
    { title: t('Admin users'), group: goTo, icon: Users, run: () => go({ kind: 'admins' }) },
  ];
  const pages: [string, string, Component, string][] = [
    ['sessions', t('Sessions'), MonitorSmartphone, 'sessions'],
    ['logs', t('Activity log'), Activity, 'logs'],
    ['metrics', t('Metrics'), BarChart3, 'metrics'],
    ['maintenance', t('Maintenance'), Wrench, 'maintenance'],
    ['config', t('Configuration'), FileCog, 'config'],
  ];
  for (const [page, title, icon, f] of pages) if (has(f as never)) c.push({ title, group: goTo, icon, run: () => go({ kind: 'server', page: page as never }) });
  if (servers.value.length > 1) c.push({ title: t('All servers'), group: goTo, icon: ServerIcon, run: () => go({ kind: 'server', page: 'servers' }) });
  c.push({ title: t('Settings'), group: goTo, icon: Settings2, run: () => go({ kind: 'settings' }) });

  if (openBucket.value) {
    const b = openBucket.value;
    const tabs: [BucketTab, string][] = [['overview', t('Overview')], ['files', t('Files')], ['access', t('Access keys')], ['settings', t('Settings')], ['lifecycle', t('Lifecycle')], ['webhooks', t('Webhooks')]];
    for (const [tab, label] of tabs) c.push({ title: `${b} › ${label}`, group: t('Bucket'), icon: ArrowRight, run: () => goBucket(b, tab) });
  }
  for (const b of buckets.value) c.push({ title: b.name, group: t('Open bucket'), icon: FolderOpen, run: () => goBucket(b.name) });

  const act = t('Actions');
  c.push({ title: t('New bucket'), group: act, icon: Plus, run: () => void createBucketFlow() });
  c.push({ title: t('Toggle light/dark'), group: act, icon: Moon, run: () => void toggleTheme() });
  for (const s of servers.value) if (s.id !== serverId.value) c.push({ title: t('Switch to {name}', { name: s.name }), group: act, icon: ServerIcon, run: () => connect(s.id).catch(toastError) });
  c.push({ title: t('Disconnect'), group: act, icon: LogOut, run: () => void disconnect() });
  return c;
});

const results = computed(() => {
  const words = query.value.toLowerCase().split(/\s+/).filter(Boolean);
  return commands.value.filter((c) => {
    const hay = `${c.title} ${c.group}`.toLowerCase();
    return words.every((w) => hay.includes(w));
  });
});

watch(query, () => (index.value = 0));
watch(index, async () => {
  await nextTick();
  list.value?.querySelector('.active')?.scrollIntoView({ block: 'nearest' });
});
onMounted(() => input.value?.focus());

function run(c: Cmd | undefined) {
  if (!c) return;
  closePalette();
  c.run();
}

function key(e: KeyboardEvent) {
  if (e.key === 'ArrowDown') { index.value = Math.min(results.value.length - 1, index.value + 1); e.preventDefault(); }
  else if (e.key === 'ArrowUp') { index.value = Math.max(0, index.value - 1); e.preventDefault(); }
  else if (e.key === 'Enter') { run(results.value[index.value]); e.preventDefault(); }
  else if (e.key === 'Escape') { closePalette(); e.preventDefault(); }
}
</script>

<template>
  <Teleport to="body">
    <div class="scrim" @mousedown.self="closePalette()">
      <div class="palette">
        <div class="head"><Search :size="16" class="subtle" /><input ref="input" v-model="query" :placeholder="t('Search pages, buckets and actions…')" spellcheck="false" @keydown="key" /></div>
        <div ref="list" class="list">
          <button v-for="(c, i) in results" :key="c.group + c.title" class="cmd" :class="{ active: i === index }" @mousemove="index = i" @click="run(c)">
            <component :is="c.icon" :size="16" class="ic" /><span class="grow ellipsis">{{ c.title }}</span><span class="group">{{ c.group }}</span>
          </button>
          <div v-if="!results.length" class="none">{{ t('No matches') }}</div>
        </div>
        <div class="foot"><span>↑↓ {{ t('to navigate') }}</span><span>↵ {{ t('to open') }}</span><span>Esc {{ t('to close') }}</span></div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.scrim { position: fixed; inset: 0; background: var(--scrim); z-index: 150; display: flex; justify-content: center; padding-top: 12vh; }
.palette { width: 580px; max-width: calc(100% - 32px); max-height: 62vh; display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-xl); box-shadow: var(--shadow); overflow: hidden; align-self: flex-start; }
.head { display: flex; align-items: center; gap: 10px; padding: 0 16px; border-bottom: 1px solid var(--border); }
.head input { flex: 1; height: 50px; border: 0; outline: none; background: none; color: var(--foreground); font: 500 15px var(--font-sans); user-select: text; }
.list { overflow-y: auto; padding: 6px; }
.cmd { display: flex; align-items: center; gap: 10px; width: 100%; height: 44px; padding: 0 12px; border: 0; border-radius: var(--radius-md); background: none; color: var(--foreground); font: 500 13.5px var(--font-sans); cursor: pointer; text-align: left; }
.cmd.active { background: var(--selected); }
.cmd.active .ic { color: var(--primary); }
.ic { color: var(--muted); }
.group { font-size: 11.5px; color: var(--subtle); }
.none { padding: 24px; text-align: center; color: var(--subtle); font-size: 13px; }
.foot { display: flex; gap: 16px; padding: 8px 16px; border-top: 1px solid var(--border); font-size: 11.5px; color: var(--subtle); }
</style>
