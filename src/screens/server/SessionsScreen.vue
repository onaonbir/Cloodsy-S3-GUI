<script setup lang="ts">
// Admin API sign-ins on this server, most recently active first. Ending this
// app's own session disconnects.
import { onMounted, ref } from 'vue';
import { Globe, KeyRound, Monitor, RefreshCw, Terminal } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import Spinner from './parts/Spinner.vue';
import IconBadge from './parts/IconBadge.vue';
import { agentLabel, clientKind } from './logic';
import { disconnect, useApi } from '@/stores/session';
import { runAction } from '@/stores/toasts';
import { confirm } from '@/lib/dialogs';
import { formatDateTime, formatRelative, parseServerDate } from '@/lib/format';
import { t } from '@/lib/i18n';
import type { AdminSession } from '@/lib/api';
import type { ApiError } from '@/lib/ipc';

const sessions = ref<AdminSession[]>([]);
const loaded = ref(false);
const loading = ref(false);
const error = ref<ApiError | null>(null);

const seen = (s: AdminSession) => parseServerDate(s.last_seen_at)?.getTime() ?? 0;

async function load() {
  loading.value = true;
  try {
    sessions.value = (await useApi().sessions()).sort((a, b) => seen(b) - seen(a));
    error.value = null;
  } catch (e) {
    error.value = e as ApiError;
  } finally {
    loading.value = false;
    loaded.value = true;
  }
}
onMounted(load);

const icons = { gui: Monitor, cli: Terminal, browser: Globe, other: KeyRound };
const icon = (s: AdminSession) => icons[clientKind(s.user_agent ?? '')];
const agent = (s: AdminSession) => agentLabel(s.user_agent ?? '') ?? t('unknown client');

async function end(s: AdminSession) {
  const ok = await confirm({
    title: t('End session'),
    message: s.current ? t('End your own session? You will be disconnected.') : t('Sign “{u}” out on that device?', { u: s.username }),
    confirmLabel: t('End session'),
    danger: true,
  });
  if (!ok) return;
  if (s.current) {
    await disconnect();
    return;
  }
  const done = await runAction(() => useApi().endSession(s.id).then(() => true), t('Session ended'));
  if (done) await load();
}
</script>

<template>
  <Page :max="960">
    <PageHead :title="t('Sessions')" :subtitle="t('Admin API sign-ins on this server.')">
      <button class="btn ghost icon" :title="t('Refresh')" :disabled="loading" @click="load">
        <Spinner v-if="loading" /><RefreshCw v-else :size="16" />
      </button>
    </PageHead>

    <States v-if="!loaded" kind="loading" />
    <States v-else-if="error && !sessions.length" kind="error" :message="error.message" :connection="error.isConnectionError" @retry="load" />
    <States v-else-if="!sessions.length" kind="empty" :title="t('No active sessions')" />
    <div v-else class="card list">
      <div v-for="s in sessions" :key="s.id" class="sess">
        <IconBadge :icon="icon(s)" :tone="s.current ? 'primary' : 'neutral'" />
        <div class="grow">
          <div class="row top">
            <span class="t-title-sm">{{ s.username }}</span>
            <Pill v-if="s.current" tone="primary">{{ t('This app') }}</Pill>
          </div>
          <div class="t-body ellipsis selectable" :title="s.user_agent">{{ s.ip || t('unknown IP') }} · {{ agent(s) }}</div>
          <div class="t-body-sm">
            {{ t('Active {a} · signed in {s} · expires {e}', { a: formatRelative(s.last_seen_at), s: formatDateTime(s.created_at), e: formatDateTime(s.expires_at) }) }}
          </div>
        </div>
        <button class="btn" @click="end(s)">{{ t('End') }}</button>
      </div>
    </div>
  </Page>
</template>

<style scoped>
.list { overflow: hidden; }
.sess { display: flex; align-items: center; gap: 12px; padding: 12px 10px 12px 16px; }
.sess + .sess { border-top: 1px solid var(--border); }
.top { gap: 8px; flex-wrap: wrap; }
</style>
