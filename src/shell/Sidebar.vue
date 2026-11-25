<script setup lang="ts">
import { computed } from 'vue';
import {
  Activity, BarChart3, ChevronsUpDown, Database, LayoutDashboard, LogOut, MonitorSmartphone, Plus, Search, Server as ServerIcon,
  Settings2, Users, Wrench, X, FileCog, Pencil, Unplug, Check, ArrowDownUp, Trash2,
} from 'lucide-vue-next';
import { removeCurrentServer } from './serverActions';
import { buckets, connecting, disconnect, has, server, serverId, sessionInfo, status, statusError, connect } from '@/stores/session';
import { hostOf, servers } from '@/stores/servers';
import { current, go, goBucket, openBucket, closeBucket, type Dest } from '@/stores/nav';
import { active, failed, overall, panelOpen, transfers } from '@/stores/transfers';
import { guiUpdate } from '@/stores/updates';
import { openMenu, SEP, type MenuItem } from '@/lib/menu';
import { openServerDialog } from './serverDialog';
import { openPalette } from './palette';
import { t, tn } from '@/lib/i18n';
import { formatIn } from '@/lib/format';
import { mod } from '@/lib/platform';
import { toastError } from '@/stores/toasts';

const emit = defineEmits<{ navigate: [] }>();

function nav(d: Dest) {
  go(d);
  emit('navigate');
}

const isActive = (d: Dest) => JSON.stringify(current.value) === JSON.stringify(d);
const onServerPage = (page: string) => current.value.kind === 'server' && current.value.page === page;

const serverItems = computed(() =>
  [
    { page: 'sessions', label: t('Sessions'), icon: MonitorSmartphone, feature: 'sessions' },
    { page: 'logs', label: t('Activity log'), icon: Activity, feature: 'logs' },
    { page: 'metrics', label: t('Metrics'), icon: BarChart3, feature: 'metrics' },
    { page: 'maintenance', label: t('Maintenance'), icon: Wrench, feature: 'maintenance' },
    { page: 'config', label: t('Configuration'), icon: FileCog, feature: 'config' },
  ].filter((i) => has(i.feature as never)),
);

const statusText = computed(() => {
  if (connecting.value) return t('Connecting…');
  if (statusError.value) return statusError.value;
  if (status.value) return t('Online · v{v}', { v: status.value.version });
  return '';
});

function switcher(e: MouseEvent) {
  const items: MenuItem[] = servers.value.map((s) => ({
    label: s.name,
    checked: s.id === serverId.value,
    action: () => {
      if (s.id !== serverId.value) connect(s.id).catch(toastError);
    },
  }));
  items.push(SEP,
    { label: t('Add server…'), icon: Plus, action: async () => { const s = await openServerDialog(null); if (s) connect(s.id).catch(toastError); } },
    { label: t('Edit this server…'), icon: Pencil, action: () => openServerDialog(server.value) },
    { label: t('Disconnect'), icon: Unplug, action: () => disconnect() },
    SEP,
    { label: t('Remove this server…'), icon: Trash2, danger: true, action: () => void removeCurrentServer() });
  openMenu(e, items);
}

const transferSummary = computed(() => {
  if (active.value.length) return tn(active.value.length, '{n} transfer running', '{n} transfers running');
  if (failed.value.length) return tn(failed.value.length, '{n} failed', '{n} failed');
  return t('Transfers complete');
});
</script>

<template>
  <aside class="sidebar">
    <button class="switcher" :title="server ? hostOf(server.url) : ''" @click="switcher">
      <div class="srv-icon"><ServerIcon :size="16" /></div>
      <div class="grow">
        <div class="srv-name ellipsis">{{ server?.name }}</div>
        <div class="srv-status ellipsis">
          <span class="dot" :class="connecting ? 'busy' : statusError ? 'bad' : 'ok'" />{{ statusText }}
        </div>
      </div>
      <ChevronsUpDown :size="15" class="subtle" />
    </button>

    <button class="search" @click="openPalette()">
      <Search :size="14" /><span class="grow">{{ t('Search…') }}</span><kbd>{{ mod }} K</kbd>
    </button>

    <nav class="nav">
      <button class="item" :class="{ active: isActive({ kind: 'dashboard' }) }" @click="nav({ kind: 'dashboard' })">
        <LayoutDashboard :size="16" />{{ t('Dashboard') }}
      </button>
      <button class="item" :class="{ active: isActive({ kind: 'buckets' }) }" @click="nav({ kind: 'buckets' })">
        <Database :size="16" /><span class="grow">{{ t('Buckets') }}</span><span class="count">{{ buckets.length }}</span>
      </button>
      <div v-if="openBucket" class="item sub" :class="{ active: current.kind === 'bucket' && current.name === openBucket }" role="button" @click="goBucket(openBucket); emit('navigate')">
        <span class="grow ellipsis">{{ openBucket }}</span>
        <button class="close" :title="t('Close')" @click.stop="closeBucket()"><X :size="13" /></button>
      </div>

      <div class="section">{{ t('Server') }}</div>
      <button class="item" :class="{ active: isActive({ kind: 'admins' }) }" @click="nav({ kind: 'admins' })">
        <Users :size="16" />{{ t('Admin users') }}
      </button>
      <button v-for="i in serverItems" :key="i.page" class="item" :class="{ active: onServerPage(i.page) }" @click="nav({ kind: 'server', page: i.page as never })">
        <component :is="i.icon" :size="16" />{{ i.label }}
      </button>

      <div class="section">{{ t('App') }}</div>
      <button v-if="servers.length > 1" class="item" :class="{ active: onServerPage('servers') }" @click="nav({ kind: 'server', page: 'servers' })">
        <ServerIcon :size="16" />{{ t('All servers') }}
      </button>
      <button class="item" :class="{ active: isActive({ kind: 'settings' }) }" @click="nav({ kind: 'settings' })">
        <Settings2 :size="16" /><span class="grow">{{ t('Settings') }}</span><span v-if="guiUpdate" class="update-dot" :title="t('Update available')">●</span>
      </button>
    </nav>

    <button v-if="transfers.length" class="transfers" @click="panelOpen = !panelOpen">
      <div class="row"><ArrowDownUp :size="14" /><span class="grow ellipsis" :class="{ 'danger-text': !active.length && failed.length }">{{ transferSummary }}</span><Check v-if="!active.length && !failed.length" :size="14" class="success-text" /></div>
      <div v-if="active.length" class="tbar"><div class="tfill" :style="{ width: `${overall * 100}%` }" /></div>
    </button>

    <div class="account">
      <div class="avatar">{{ (sessionInfo?.username ?? '?').charAt(0).toUpperCase() }}</div>
      <div class="grow">
        <div class="ellipsis user">{{ sessionInfo?.username }}</div>
        <div class="ellipsis subtle renew">{{ sessionInfo ? t('Renews {time}', { time: formatIn(sessionInfo.expires_at - 30) }) : t('Signed in') }}</div>
      </div>
      <button class="btn ghost icon sm" :title="t('Disconnect')" @click="disconnect()"><LogOut :size="15" /></button>
    </div>
  </aside>
</template>

<style scoped>
.sidebar { width: var(--sidebar-width); flex-shrink: 0; display: flex; flex-direction: column; gap: 10px; padding: 12px 10px; background: var(--sidebar); border-right: 1px solid var(--border); overflow-y: auto; }
.switcher { display: flex; align-items: center; gap: 10px; padding: 9px 10px; border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--card); cursor: pointer; text-align: left; color: var(--foreground); font-family: inherit; }
.switcher:hover { border-color: var(--border-strong); }
.srv-icon { width: 32px; height: 32px; border-radius: var(--radius-md); background: var(--primary-soft); color: var(--primary); display: grid; place-items: center; flex-shrink: 0; }
.srv-name { font-weight: 600; font-size: 13px; }
.srv-status { font-size: 11.5px; color: var(--muted); display: flex; align-items: center; gap: 5px; }
.dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.dot.ok { background: var(--success); }
.dot.bad { background: var(--danger); }
.dot.busy { background: var(--warning); }
.search { display: flex; align-items: center; gap: 8px; height: 32px; text-align: left; padding: 0 10px; border: 1px solid var(--border); border-radius: var(--radius-md); background: transparent; color: var(--subtle); font: 500 12.5px var(--font-sans); cursor: pointer; }
.search:hover { color: var(--muted); border-color: var(--border-strong); }
kbd { font: 500 10.5px var(--font-sans); padding: 1px 5px; border-radius: 4px; border: 1px solid var(--border); color: var(--subtle); }
.nav { display: flex; flex-direction: column; gap: 1px; flex: 1; }
.item { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border: 0; border-radius: var(--radius-md); background: none; color: var(--muted); font: 500 13px var(--font-sans); cursor: pointer; text-align: left; }
.item:hover { background: var(--hover); color: var(--foreground); }
.item.active { background: var(--selected); color: var(--primary); font-weight: 600; }
.item.sub { padding-left: 36px; height: 30px; font-size: 12.5px; }
.close { width: 20px; height: 20px; border: 0; border-radius: 4px; background: none; color: var(--subtle); display: grid; place-items: center; cursor: pointer; }
.close:hover { background: var(--hover); color: var(--foreground); }
.count { font-size: 11px; color: var(--subtle); }
.section { margin: 14px 10px 4px; font-size: 10.5px; font-weight: 700; letter-spacing: 0.8px; text-transform: uppercase; color: var(--subtle); }
.update-dot { color: var(--primary); font-size: 10px; }
.transfers { display: flex; flex-direction: column; gap: 6px; padding: 10px; border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--card); color: var(--muted); font: 500 12px var(--font-sans); cursor: pointer; text-align: left; }
.tbar { height: 4px; border-radius: 4px; background: var(--hover); overflow: hidden; }
.tfill { height: 100%; background: var(--primary); transition: width var(--normal); }
.account { display: flex; align-items: center; gap: 10px; padding: 8px 4px 0 6px; border-top: 1px solid var(--border); }
.avatar { width: 30px; height: 30px; border-radius: 50%; background: var(--primary); color: var(--on-primary); display: grid; place-items: center; font-weight: 700; font-size: 13px; flex-shrink: 0; }
.user { font-weight: 600; font-size: 13px; }
.renew { font-size: 11.5px; }
</style>
