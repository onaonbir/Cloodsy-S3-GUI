// This app's own updates. GitHub's latest Cloodsy-S3-GUI release is checked
// once per launch (8 s) and from Settings. Release builds install it with
// Tauri's updater: latest.json on the GitHub release, every package signed
// with the S3 GUI update key (the public half is in tauri.conf.json). On
// Windows the updater runs our setup (/P /UPDATE /R), which restarts the app.

import { ref } from 'vue';
import { check } from '@tauri-apps/plugin-updater';
import { relaunch } from '@tauri-apps/plugin-process';
import { ipc } from '@/lib/ipc';
import { compareVersions } from '@/lib/format';

export const appVersion = ref('');
/** Release builds can install updates in place; dev builds only link to the release. */
export const installable = ref(false);
export const guiUpdate = ref<{ version: string; url: string; notes: string } | null>(null);
export const checking = ref(false);
export const checkedAt = ref<Date | null>(null);
export const checkError = ref<string | null>(null);
export const installing = ref(false);
/** 0..1 while downloading; null before the size is known. */
export const installProgress = ref<number | null>(null);
export const installError = ref<string | null>(null);

export async function checkGuiUpdate() {
  if (checking.value) return;
  checking.value = true;
  checkError.value = null;
  try {
    const r = await ipc.githubLatest('onaonbir/Cloodsy-S3-GUI', 8);
    guiUpdate.value = r && appVersion.value && compareVersions(appVersion.value, r.tag) < 0 ? { version: r.tag, url: r.url, notes: r.notes } : null;
    checkedAt.value = new Date();
  } catch (e) {
    checkError.value = (e as Error).message;
  } finally {
    checking.value = false;
  }
}

/** Downloads the signed update, installs it and restarts the app. */
export async function installGuiUpdate() {
  if (installing.value) return;
  installing.value = true;
  installError.value = null;
  installProgress.value = null;
  try {
    const update = await check();
    if (!update) throw new Error('No signed update is available for this platform yet.');
    let total = 0;
    let done = 0;
    await update.downloadAndInstall((e) => {
      if (e.event === 'Started') total = e.data.contentLength ?? 0;
      else if (e.event === 'Progress') {
        done += e.data.chunkLength;
        installProgress.value = total ? done / total : null;
      } else if (e.event === 'Finished') installProgress.value = 1;
    });
    // Windows: the setup has taken over and restarts the app. Elsewhere:
    await relaunch();
  } catch (e) {
    installError.value = e instanceof Error ? e.message : String(e);
  } finally {
    installing.value = false;
  }
}
