<script setup lang="ts">
// Signed in: sidebar (persistent at ≥ 860 px, else a drawer behind an app
// bar), the current screen, the transfers panel and Ctrl/Cmd+K.
import { computed, onBeforeUnmount, onMounted, ref, type Component } from 'vue';
import { ArrowLeft, Menu, Moon, Search, Sun } from 'lucide-vue-next';
import Sidebar from './Sidebar.vue';
import TransfersPanel from './TransfersPanel.vue';
import { openPalette } from './palette';
import { back, canGoBack, current } from '@/stores/nav';
import { isDark, toggleTheme } from '@/stores/prefs';
import { isMod } from '@/lib/platform';
import { t } from '@/lib/i18n';
import DashboardScreen from '@/screens/DashboardScreen.vue';
import BucketsScreen from '@/screens/buckets/BucketsScreen.vue';
import BucketScreen from '@/screens/bucket/BucketScreen.vue';
import AdminsScreen from '@/screens/AdminsScreen.vue';
import SettingsScreen from '@/screens/SettingsScreen.vue';
import SessionsScreen from '@/screens/server/SessionsScreen.vue';
import LogsScreen from '@/screens/server/LogsScreen.vue';
import MetricsScreen from '@/screens/server/MetricsScreen.vue';
import MaintenanceScreen from '@/screens/server/MaintenanceScreen.vue';
import ConfigScreen from '@/screens/server/ConfigScreen.vue';
import AllServersScreen from '@/screens/server/AllServersScreen.vue';

const width = ref(window.innerWidth);
const wide = computed(() => width.value >= 860);
const drawer = ref(false);
const onResize = () => (width.value = window.innerWidth);

function onKey(e: KeyboardEvent) {
  if (isMod(e) && e.key.toLowerCase() === 'k') {
    e.preventDefault();
    openPalette();
  }
}
onMounted(() => {
  window.addEventListener('resize', onResize);
  window.addEventListener('keydown', onKey);
});
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize);
  window.removeEventListener('keydown', onKey);
});

const screen = computed<{ comp: Component; key: string; title: string }>(() => {
  const d = current.value;
  switch (d.kind) {
    case 'dashboard': return { comp: DashboardScreen, key: 'dashboard', title: t('Dashboard') };
    case 'buckets': return { comp: BucketsScreen, key: 'buckets', title: t('Buckets') };
    case 'bucket': return { comp: BucketScreen, key: `bucket:${d.name}`, title: d.name };
    case 'admins': return { comp: AdminsScreen, key: 'admins', title: t('Admin users') };
    case 'settings': return { comp: SettingsScreen, key: 'settings', title: t('Settings') };
    case 'server': {
      const map = {
        sessions: [SessionsScreen, t('Sessions')], logs: [LogsScreen, t('Activity log')], metrics: [MetricsScreen, t('Metrics')],
        maintenance: [MaintenanceScreen, t('Maintenance')], config: [ConfigScreen, t('Configuration')], servers: [AllServersScreen, t('All servers')],
      } as const;
      const [comp, title] = map[d.page];
      return { comp, key: `server:${d.page}`, title };
    }
  }
  return { comp: DashboardScreen, key: 'dashboard', title: '' };
});
</script>

<template>
  <div class="shell">
    <Sidebar v-if="wide" />
    <template v-else>
      <Transition name="fade"><div v-if="drawer" class="drawer-scrim" @click="drawer = false" /></Transition>
      <Transition name="slide"><Sidebar v-if="drawer" class="drawer" @navigate="drawer = false" /></Transition>
    </template>
    <div class="main">
      <div v-if="!wide" class="appbar">
        <button class="btn ghost icon" :title="t('Menu')" @click="drawer = true"><Menu :size="18" /></button>
        <button v-if="canGoBack && current.kind !== 'dashboard'" class="btn ghost icon" :title="t('Back')" @click="back()"><ArrowLeft :size="18" /></button>
        <span class="grow ellipsis t-title">{{ screen.title }}</span>
        <button class="btn ghost icon" :title="t('Search…')" @click="openPalette()"><Search :size="17" /></button>
        <button class="btn ghost icon" @click="toggleTheme()"><Sun v-if="isDark" :size="17" /><Moon v-else :size="17" /></button>
      </div>
      <div class="content">
        <Transition name="page" mode="out-in">
          <component :is="screen.comp" :key="screen.key" />
        </Transition>
      </div>
    </div>
    <TransfersPanel />
  </div>
</template>

<style scoped>
.shell { flex: 1; display: flex; min-height: 0; position: relative; }
.main { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.appbar { display: flex; align-items: center; gap: 4px; height: 50px; padding: 0 10px; border-bottom: 1px solid var(--border); background: var(--sidebar); }
.content { flex: 1; min-height: 0; overflow: auto; position: relative; }
.drawer { position: absolute; left: 0; top: 0; bottom: 0; z-index: 60; box-shadow: var(--shadow); }
.drawer-scrim { position: absolute; inset: 0; background: var(--scrim); z-index: 55; }
.page-enter-active, .page-leave-active { transition: opacity 100ms ease; }
.page-enter-from, .page-leave-to { opacity: 0; }
.fade-enter-active, .fade-leave-active { transition: opacity var(--normal); }
.fade-enter-from, .fade-leave-to { opacity: 0; }
.slide-enter-active, .slide-leave-active { transition: transform var(--normal); }
.slide-enter-from, .slide-leave-to { transform: translateX(-100%); }
</style>
