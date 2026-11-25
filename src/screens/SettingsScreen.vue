<script setup lang="ts">
// Settings: appearance, transfers, the open connection, keyboard shortcuts
// and About (version, update check and install, licences).
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { openUrl } from '@tauri-apps/plugin-opener';
import { ArrowDownUp, Download, Info, Keyboard, LogOut, Monitor, Moon, Palette, Pencil, Plug, Sparkles, Sun, Trash2 } from 'lucide-vue-next';
import BrandMark from '@/components/BrandMark.vue';
import Callout from '@/components/ui/Callout.vue';
import Pill from '@/components/ui/Pill.vue';
import Toggle from '@/components/ui/Toggle.vue';
import Page from './server/parts/Page.vue';
import PageHead from './server/parts/PageHead.vue';
import Panel from './server/parts/Panel.vue';
import InfoRow from './server/parts/InfoRow.vue';
import Segmented from './server/parts/Segmented.vue';
import Spinner from './server/parts/Spinner.vue';
import LicencesDialog from './settings/LicencesDialog.vue';
import { pref, setLanguage, setPref, setTheme, themeMode, type ThemeMode } from '@/stores/prefs';
import { disconnect, server, sessionInfo, status } from '@/stores/session';
import { appVersion, checkError, checkGuiUpdate, checkedAt, checking, guiUpdate, installable, installError, installGuiUpdate, installing, installProgress } from '@/stores/updates';
import { removeCurrentServer } from '@/shell/serverActions';
import { toastError } from '@/stores/toasts';
import { openServerDialog } from '@/shell/serverDialog';
import { openDialog } from '@/lib/overlay';
import { formatDateTime, formatIn } from '@/lib/format';
import { mod, platform } from '@/lib/platform';
import { t } from '@/lib/i18n';

// ---- appearance ------------------------------------------------------------
const themes = computed(() => [
  { value: 'light' as ThemeMode, label: t('Light'), icon: Sun },
  { value: 'dark' as ThemeMode, label: t('Dark'), icon: Moon },
  { value: 'system' as ThemeMode, label: t('System'), icon: Monitor },
]);

type Lang = 'en' | 'tr' | 'system';
const languages = computed(() => [
  { value: 'en' as Lang, label: 'English' },
  { value: 'tr' as Lang, label: 'Türkçe' },
  { value: 'system' as Lang, label: t('System') },
]);
const language = computed<Lang>(() => {
  const l = pref('locale');
  return l === 'en' || l === 'tr' ? l : 'system';
});
const onLanguage = (v: Lang) => setLanguage(v === 'system' ? null : v).catch(toastError);
const onTheme = (v: ThemeMode) => setTheme(v).catch(toastError);

// ---- transfers -------------------------------------------------------------
const notifications = computed(() => pref('notifications') !== 'off');
const setNotifications = (on: boolean) => setPref('notifications', on ? 'on' : 'off').catch(toastError);
const downloadDir = computed(() => pref('last_download_dir') || null);

// ---- connection ------------------------------------------------------------
const now = ref(Date.now() / 1000);
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => (clock = setInterval(() => (now.value = Date.now() / 1000), 15_000)));
onBeforeUnmount(() => clearInterval(clock));

const renewal = computed(() => {
  const exp = sessionInfo.value?.expires_at;
  if (!exp) return null;
  return {
    text: t('Renews {time}', { time: formatIn(exp - 30, now.value) }),
    until: t('Current token valid until {t}', { t: formatDateTime(new Date(exp * 1000).toISOString()) }),
  };
});

// ---- shortcuts -------------------------------------------------------------
const alt = platform === 'macos' ? '⌥' : 'Alt';
/** Each entry: alternatives, each a key combination. */
const shortcuts = computed<{ keys: string[][]; what: string }[]>(() => [
  { keys: [[mod, 'K']], what: t('Command palette: jump to any page, bucket or action') },
  { keys: [[mod, 'F']], what: t('Search files') },
  { keys: [[mod, 'U']], what: t('Upload files') },
  { keys: [[mod, 'A']], what: t('Select all files in the folder') },
  { keys: [['↑'], ['↓'], [t('Space')]], what: t('Move between files / select') },
  { keys: [['Enter']], what: t('Download the highlighted file') },
  { keys: [['F2']], what: t('Rename') },
  { keys: [['Delete']], what: t('Delete selected files') },
  { keys: [['Backspace'], [alt, '↑']], what: t('Up one folder') },
  { keys: [['F5']], what: t('Refresh') },
  { keys: [['Esc']], what: t('Clear the selection, then the search') },
]);

// ---- about -----------------------------------------------------------------
const upToDate = computed(() => !!checkedAt.value && !guiUpdate.value && !checkError.value && !checking.value);

/** Release builds download, verify and install the signed update; a dev build opens the release page. */
async function install() {
  const u = guiUpdate.value;
  if (!u) return;
  if (installable.value) {
    await installGuiUpdate();
    return;
  }
  try {
    await openUrl(u.url);
  } catch (e) {
    toastError(e);
  }
}

const licences = () => openDialog(LicencesDialog);
const editServer = () => {
  if (server.value) void openServerDialog(server.value);
};
</script>

<template>
  <Page :max="820">
    <PageHead :title="t('Settings')" />

    <Callout v-if="guiUpdate" tone="info" :title="t('Cloodsy S3 GUI {v} is available (you have {c}).', { v: guiUpdate.version, c: appVersion })">
      <pre v-if="guiUpdate.notes.trim()" class="notes selectable">{{ guiUpdate.notes.trim() }}</pre>
      <div v-if="installing" class="install-state">
        {{ installProgress === null ? t('Downloading the update…') : installProgress >= 1 ? t('Installing…') : t('Downloading the update… {p}%', { p: Math.round(installProgress * 100) }) }}
      </div>
      <div v-else-if="installError" class="install-state danger-text selectable">{{ installError }}</div>
      <template #actions>
        <button class="btn primary" :disabled="installing" @click="install">
          <Spinner v-if="installing" :size="14" /><Download v-else :size="15" />{{ installable ? t('Download and install') : t('Open the release page') }}
        </button>
      </template>
    </Callout>

    <Panel :title="t('Appearance')" :icon="Palette">
      <div class="srow">
        <div class="grow t-body-lg">{{ t('Theme') }}</div>
        <Segmented :model-value="themeMode" :options="themes" @update:model-value="onTheme" />
      </div>
      <div class="srow">
        <div class="grow t-body-lg">{{ t('Language') }}</div>
        <Segmented :model-value="language" :options="languages" @update:model-value="onLanguage" />
      </div>
    </Panel>

    <Panel :title="t('Transfers')" :icon="ArrowDownUp">
      <label class="srow pointer">
        <div class="grow">
          <div class="t-body-lg">{{ t('Notify when transfers finish') }}</div>
          <div class="t-body-sm">{{ t('System notification after a batch of uploads or downloads') }}</div>
        </div>
        <Toggle :model-value="notifications" @update:model-value="setNotifications" />
      </label>
      <div class="srow">
        <div class="grow">
          <div class="t-body-lg">{{ t('Download folder') }}</div>
          <div class="t-body-sm">{{ t('The last folder you saved to is suggested next time') }}</div>
        </div>
        <div class="dir mono selectable ellipsis" :title="downloadDir ?? ''">{{ downloadDir ?? t('Asks every time') }}</div>
      </div>
    </Panel>

    <Panel v-if="server" :title="t('Connection')" :icon="Plug">
      <template #actions>
        <button class="btn ghost sm" @click="editServer"><Pencil :size="14" />{{ t('Edit') }}</button>
      </template>
      <InfoRow :label="t('Server')" :value="server.name" />
      <InfoRow :label="t('Admin API')" :value="server.url" mono />
      <InfoRow v-if="server.s3_url" :label="t('S3 endpoint')" :value="server.s3_url" mono />
      <InfoRow :label="t('Signed in as')" :value="sessionInfo?.username ?? '—'" />
      <InfoRow v-if="renewal" :label="t('Session')">
        <span class="text">{{ renewal.text }}</span>
        <div class="t-body-sm">{{ renewal.until }}</div>
      </InfoRow>
      <InfoRow v-if="status" :label="t('Server version')" :value="status.version ? `v${status.version}` : '—'" />
      <div class="right">
        <button class="btn danger" @click="removeCurrentServer()"><Trash2 :size="15" />{{ t('Remove') }}</button>
        <button class="btn" @click="disconnect()"><LogOut :size="15" />{{ t('Disconnect') }}</button>
      </div>
    </Panel>

    <Panel :title="t('Keyboard shortcuts')" :icon="Keyboard">
      <div v-for="s in shortcuts" :key="s.what" class="key-row">
        <div class="keys">
          <template v-for="(combo, i) in s.keys" :key="i">
            <span v-if="i > 0" class="subtle or">/</span>
            <span class="combo"><kbd v-for="k in combo" :key="k">{{ k }}</kbd></span>
          </template>
        </div>
        <div class="t-body what">{{ s.what }}</div>
      </div>
    </Panel>

    <Panel :title="t('About')" :icon="Info">
      <div class="about">
        <BrandMark :size="40" />
        <div class="grow">
          <div class="row name">
            <span class="t-title-sm">{{ t('Cloodsy S3 GUI') }}</span>
            <Pill v-if="guiUpdate" tone="primary"><Sparkles :size="11" />{{ t('Update available') }}</Pill>
          </div>
          <div class="t-body-sm">
            {{ t('Version') }} {{ appVersion || '—' }} · OnaOnbir<template v-if="upToDate"> · <span class="success-text">{{ t('up to date') }}</span></template>
          </div>
          <div v-if="checkError" class="t-body-sm danger-text selectable">{{ t('Update check failed: {e}', { e: checkError }) }}</div>
        </div>
        <div class="about-actions">
          <button class="btn ghost" :disabled="checking" @click="checkGuiUpdate">
            <Spinner v-if="checking" />{{ t('Check for updates') }}
          </button>
          <button class="btn ghost" @click="licences">{{ t('Licenses') }}</button>
        </div>
      </div>
    </Panel>
  </Page>
</template>

<style scoped>
.srow { display: flex; align-items: center; gap: 12px; padding: 6px 0; flex-wrap: wrap; }
.pointer { cursor: pointer; }
.dir { max-width: 50%; color: var(--muted); font-size: 12px; }
.text { font-size: 14px; }
.right { display: flex; justify-content: flex-end; gap: 8px; padding-top: 8px; }
.install-state { margin-top: 6px; font-size: 12.5px; }
.notes { margin: 8px 0 0; max-height: 160px; overflow: auto; white-space: pre-wrap; overflow-wrap: anywhere; font: 12.5px/1.5 var(--font-sans); color: var(--muted); }
.key-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; }
.keys { width: 170px; flex-shrink: 0; display: flex; align-items: center; flex-wrap: wrap; gap: 4px; }
.combo { display: inline-flex; gap: 3px; }
.or { font-size: 11px; }
kbd { min-width: 22px; height: 22px; padding: 0 6px; display: inline-grid; place-items: center; border-radius: 5px; border: 1px solid var(--border-strong); border-bottom-width: 2px; background: var(--card); color: var(--foreground); font: 600 11px var(--font-sans); }
.what { flex: 1; min-width: 0; color: var(--foreground); }
.about { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.about > .grow { min-width: 200px; }
.name { gap: 8px; }
.about-actions { display: flex; gap: 4px; flex-wrap: wrap; }
</style>
