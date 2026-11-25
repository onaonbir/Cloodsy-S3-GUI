<script setup lang="ts">
// The app's own title bar on Windows and macOS (Linux keeps the system one):
// brand, current server, theme toggle (click flips, right-click picks) and on
// Windows the caption buttons.
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { ChevronRight, Minus, Moon, Square, Copy, Sun, X } from 'lucide-vue-next';
import BrandMark from '@/components/BrandMark.vue';
import { isDark, setTheme, themeMode, toggleTheme } from '@/stores/prefs';
import { server } from '@/stores/session';
import { openMenu } from '@/lib/menu';
import { platform } from '@/lib/platform';
import { t } from '@/lib/i18n';

const win = getCurrentWindow();
const maximized = ref(false);
let unlisten: (() => void) | undefined;

onMounted(async () => {
  maximized.value = await win.isMaximized();
  unlisten = await win.onResized(async () => (maximized.value = await win.isMaximized()));
});
onBeforeUnmount(() => unlisten?.());

function themeMenu(e: MouseEvent) {
  openMenu(e, [
    { label: t('Light'), checked: themeMode.value === 'light', action: () => setTheme('light') },
    { label: t('Dark'), checked: themeMode.value === 'dark', action: () => setTheme('dark') },
    { label: t('System'), checked: themeMode.value === 'system', action: () => setTheme('system') },
  ]);
}
</script>

<template>
  <div class="titlebar" :class="platform" data-tauri-drag-region @dblclick.self="win.toggleMaximize()">
    <div class="brand" data-tauri-drag-region>
      <BrandMark :size="20" />
      <span class="name" data-tauri-drag-region>Cloodsy S3</span>
      <template v-if="server">
        <ChevronRight :size="14" class="subtle" />
        <span class="server ellipsis" data-tauri-drag-region>{{ server.name }}</span>
      </template>
    </div>
    <div class="spacer" data-tauri-drag-region />
    <button class="tb-btn" :title="t('Toggle light/dark (right-click for more)')" @click="toggleTheme()" @contextmenu="themeMenu">
      <Sun v-if="isDark" :size="15" /><Moon v-else :size="15" />
    </button>
    <template v-if="platform === 'windows'">
      <button class="cap" :title="t('Minimize')" @click="win.minimize()"><Minus :size="16" /></button>
      <button class="cap" :title="maximized ? t('Restore') : t('Maximize')" @click="win.toggleMaximize()">
        <Copy v-if="maximized" :size="13" class="flip" /><Square v-else :size="13" />
      </button>
      <button class="cap close" :title="t('Close')" @click="win.close()"><X :size="17" /></button>
    </template>
  </div>
</template>

<style scoped>
.titlebar { height: var(--titlebar-height); flex-shrink: 0; display: flex; align-items: center; background: var(--titlebar); border-bottom: 1px solid var(--border); padding-left: 14px; }
.titlebar.macos { padding-left: 80px; padding-right: 8px; }
.brand { display: flex; align-items: center; gap: 8px; min-width: 0; }
.name { font-weight: 700; font-size: 13px; letter-spacing: -0.1px; }
.server { font-size: 13px; color: var(--muted); max-width: 320px; }
.tb-btn { width: 34px; height: 28px; margin-right: 6px; border: 0; border-radius: var(--radius-sm); background: none; color: var(--muted); display: grid; place-items: center; cursor: pointer; }
.tb-btn:hover { background: var(--hover); color: var(--foreground); }
.cap { width: 46px; height: var(--titlebar-height); border: 0; background: none; color: var(--foreground); display: grid; place-items: center; cursor: pointer; }
.cap:hover { background: var(--hover); }
.cap.close:hover { background: #e81123; color: #fff; }
.flip { transform: scaleX(-1); }
</style>
