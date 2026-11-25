<script setup lang="ts">
// The server's effective configuration (read-only, secrets masked by the
// server): one panel per top-level key, Copy JSON.
import { computed, onMounted, ref, shallowRef } from 'vue';
import { Copy, RefreshCw, Settings2 } from 'lucide-vue-next';
import States from '@/components/ui/States.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import Panel from './parts/Panel.vue';
import Spinner from './parts/Spinner.vue';
import ConfigNode from './ConfigNode.vue';
import { useApi } from '@/stores/session';
import { toast } from '@/stores/toasts';
import { t } from '@/lib/i18n';
import type { ApiError } from '@/lib/ipc';

const config = shallowRef<Record<string, unknown> | null>(null);
const loading = ref(false);
const error = ref<ApiError | null>(null);

async function load() {
  loading.value = true;
  try {
    config.value = await useApi().config();
    error.value = null;
  } catch (e) {
    error.value = e as ApiError;
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const sections = computed(() => Object.entries(config.value ?? {}));

async function copyJson() {
  if (!config.value) return;
  try {
    await navigator.clipboard.writeText(JSON.stringify(config.value, null, 2));
    toast(t('Configuration copied as JSON'));
  } catch {
    toast(t('Could not copy'), true);
  }
}
</script>

<template>
  <Page :max="1000">
    <PageHead :title="t('Configuration')" :subtitle="t('Effective server settings (read-only, secrets masked). Change them in config.yaml on the server and restart it.')">
      <button class="btn ghost icon" :title="t('Refresh')" :disabled="loading" @click="load">
        <Spinner v-if="loading" /><RefreshCw v-else :size="16" />
      </button>
      <button v-if="config" class="btn" @click="copyJson"><Copy :size="15" />{{ t('Copy JSON') }}</button>
    </PageHead>

    <template v-if="config">
      <Panel v-for="[key, value] in sections" :key="key" :title="key" :icon="Settings2">
        <ConfigNode :value="value" />
      </Panel>
      <States v-if="!sections.length" kind="empty" :title="t('No configuration reported')" />
    </template>
    <States v-else-if="error" kind="error" :message="error.message" :connection="error.isConnectionError" @retry="load" />
    <States v-else kind="loading" />
  </Page>
</template>
