<script setup lang="ts">
// Root: the title bar, then the welcome screen when signed out or the shell
// for the open session (rebuilt for every new session).
import { onMounted, ref, watch } from 'vue';
import TitleBar from '@/shell/TitleBar.vue';
import Welcome from '@/shell/Welcome.vue';
import AppShell from '@/shell/AppShell.vue';
import ServerDialog from '@/shell/ServerDialog.vue';
import Palette from '@/shell/Palette.vue';
import DialogHost from '@/components/DialogHost.vue';
import MenuHost from '@/components/MenuHost.vue';
import ToastHost from '@/components/ToastHost.vue';
import OverlayHost from '@/components/OverlayHost.vue';
import { serverDialog } from '@/shell/serverDialog';
import { paletteOpen } from '@/shell/palette';
import { connected, generation } from '@/stores/session';
import { initPrefs } from '@/stores/prefs';
import { initServers } from '@/stores/servers';
import { appVersion, checkGuiUpdate, installable } from '@/stores/updates';
import { resetTransfers } from '@/stores/transfers';
import { closeAllDialogs } from '@/lib/overlay';
import { customTitleBar } from '@/lib/platform';
import { ipc } from '@/lib/ipc';

const ready = ref(false);

onMounted(async () => {
  const [settings, info] = await Promise.all([ipc.settings(), ipc.appInfo()]);
  initPrefs(settings.prefs);
  initServers(settings.servers);
  appVersion.value = info.version;
  installable.value = info.updates_installable;
  ready.value = true;
  void checkGuiUpdate();
});

// A new or ended session starts from a clean slate.
watch(generation, () => {
  closeAllDialogs();
  paletteOpen.value = false;
  if (!connected.value) resetTransfers();
});
</script>

<template>
  <div class="app">
    <TitleBar v-if="customTitleBar" />
    <template v-if="ready">
      <AppShell v-if="connected" :key="generation" />
      <Welcome v-else />
    </template>
  </div>
  <ServerDialog v-if="serverDialog" />
  <Palette v-if="paletteOpen && connected" />
  <OverlayHost />
  <DialogHost />
  <MenuHost />
  <ToastHost />
</template>

<style scoped>
.app { height: 100%; display: flex; flex-direction: column; }
</style>
