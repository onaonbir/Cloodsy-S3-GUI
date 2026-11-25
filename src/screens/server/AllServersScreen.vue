<script setup lang="ts">
// Every saved server at a glance. The Rust side probes each one with its open
// session or a throwaway login (logged out after): latency, version, buckets,
// objects, stored bytes and disk.
import { onMounted, reactive, ref } from 'vue';
import { RefreshCw, Server as ServerIcon } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import UsageBar from '@/components/ui/UsageBar.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import InfoRow from './parts/InfoRow.vue';
import IconBadge from './parts/IconBadge.vue';
import Spinner from './parts/Spinner.vue';
import { servers, hostOf } from '@/stores/servers';
import { connect, connecting, serverId } from '@/stores/session';
import { toastError } from '@/stores/toasts';
import { ipc, type Server } from '@/lib/ipc';
import { formatBytes, formatCount } from '@/lib/format';
import { t } from '@/lib/i18n';
import type { Bucket, ServerStatus } from '@/lib/api';

interface Snapshot {
  loading: boolean;
  error?: string;
  ms?: number;
  version?: string;
  buckets?: number;
  objects?: number;
  stored?: number;
  disk?: { free: number; total: number };
}

const snaps = reactive<Record<string, Snapshot>>({});
const refreshing = ref(false);
/** Bumped per refresh: a slow answer from an older round is dropped. */
let round = 0;

async function probe(s: Server, r: number) {
  try {
    const o = await ipc.overview(s.id);
    if (r !== round) return;
    const st = o.status as unknown as ServerStatus;
    const buckets = (o.buckets ?? []) as Bucket[];
    const total = st.storage?.total_bytes ?? 0;
    snaps[s.id] = {
      loading: false,
      ms: o.ms,
      version: st.version,
      buckets: buckets.length,
      objects: buckets.reduce((a, b) => a + (b.objects ?? 0), 0),
      stored: buckets.reduce((a, b) => a + (b.usage_bytes ?? 0), 0),
      disk: total > 0 ? { free: st.storage?.free_bytes ?? 0, total } : undefined,
    };
  } catch (e) {
    if (r === round) snaps[s.id] = { loading: false, error: (e as Error).message };
  }
}

async function refresh() {
  const r = ++round;
  refreshing.value = true;
  for (const s of servers.value) snaps[s.id] = { loading: true };
  await Promise.all(servers.value.map((s) => probe(s, r)));
  if (r === round) refreshing.value = false;
}
onMounted(refresh);

async function switchTo(s: Server) {
  if (connecting.value) return;
  try {
    await connect(s.id);
  } catch (e) {
    toastError(e);
  }
}
</script>

<template>
  <Page>
    <PageHead :title="t('All servers')" :subtitle="t('Every saved server at a glance.')">
      <button class="btn" :disabled="refreshing" @click="refresh">
        <Spinner v-if="refreshing" /><RefreshCw v-else :size="15" />{{ t('Refresh') }}
      </button>
    </PageHead>

    <div class="wrap">
      <div class="grid">
        <div v-for="s in servers" :key="s.id" class="card srv">
          <div class="row head">
            <IconBadge :icon="ServerIcon" />
            <div class="grow">
              <div class="t-title-sm ellipsis">{{ s.name }}</div>
              <div class="t-body-sm ellipsis">{{ hostOf(s.url) }}</div>
            </div>
            <Spinner v-if="!snaps[s.id] || snaps[s.id].loading" class="muted" />
            <Pill v-else-if="snaps[s.id].error" tone="danger" dot>{{ t('Offline') }}</Pill>
            <Pill v-else tone="success" dot>{{ t('Online · {ms} ms', { ms: snaps[s.id].ms ?? 0 }) }}</Pill>
          </div>

          <div class="body">
            <div v-if="snaps[s.id]?.error" class="t-body-sm danger-text selectable err">{{ snaps[s.id].error }}</div>
            <template v-else-if="snaps[s.id] && !snaps[s.id].loading">
              <InfoRow :label="t('Version')" :value="snaps[s.id].version ? `v${snaps[s.id].version}` : '—'" />
              <InfoRow :label="t('Buckets')" :value="formatCount(snaps[s.id].buckets ?? 0)" />
              <InfoRow :label="t('Objects')" :value="formatCount(snaps[s.id].objects ?? 0)" />
              <InfoRow :label="t('Stored')" :value="formatBytes(snaps[s.id].stored ?? 0)" />
              <div v-if="snaps[s.id].disk" class="disk">
                <UsageBar :value="1 - snaps[s.id].disk!.free / snaps[s.id].disk!.total" :height="5" />
                <div class="t-body-sm">{{ t('{free} free of {total}', { free: formatBytes(snaps[s.id].disk!.free), total: formatBytes(snaps[s.id].disk!.total) }) }}</div>
              </div>
            </template>
          </div>

          <div class="foot">
            <Pill v-if="s.id === serverId" tone="primary">{{ t('Connected') }}</Pill>
            <button v-else class="btn" :disabled="!!connecting" @click="switchTo(s)">
              <Spinner v-if="connecting === s.id" />{{ t('Switch to') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Page>
</template>

<style scoped>
.wrap { container-type: inline-size; }
.grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; }
@container (max-width: 1000px) { .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@container (max-width: 640px) { .grid { grid-template-columns: minmax(0, 1fr); } }
.srv { padding: 18px; display: flex; flex-direction: column; gap: 14px; min-width: 0; }
.head { gap: 10px; }
.body { flex: 1; }
.body :deep(.info-row) { padding: 4px 0; }
.err { overflow-wrap: anywhere; }
.disk { display: flex; flex-direction: column; gap: 4px; margin-top: 6px; }
.foot { display: flex; justify-content: flex-end; }
</style>
