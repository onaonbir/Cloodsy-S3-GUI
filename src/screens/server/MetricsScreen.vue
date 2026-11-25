<script setup lang="ts">
// S3 API traffic: totals since the server started and four per-minute charts
// for the last 60 minutes. Refreshes every 10 s while the page is open.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue';
import { RefreshCw } from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import States from '@/components/ui/States.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import Panel from './parts/Panel.vue';
import Spinner from './parts/Spinner.vue';
import BarChart from './BarChart.vue';
import { errorRate, methodSummary } from './logic';
import { useApi } from '@/stores/session';
import { formatBytes, formatCount, formatDateTime, parseServerDate } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import type { Metrics } from '@/lib/api';
import type { ApiError } from '@/lib/ipc';

const INTERVAL = 10_000;
const metrics = shallowRef<Metrics | null>(null);
const loading = ref(false);
const error = ref<ApiError | null>(null);
let timer: ReturnType<typeof setInterval> | undefined;
let alive = true;

async function load() {
  if (loading.value) return;
  loading.value = true;
  try {
    const m = await useApi().metrics();
    if (alive) {
      metrics.value = m;
      error.value = null;
    }
  } catch (e) {
    if (alive) error.value = e as ApiError;
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  void load();
  timer = setInterval(() => void load(), INTERVAL);
});
onBeforeUnmount(() => {
  alive = false;
  clearInterval(timer);
});

const two = (n: number) => String(n).padStart(2, '0');
function hm(iso: string) {
  const d = parseServerDate(iso);
  return d ? `${two(d.getHours())}:${two(d.getMinutes())}` : '';
}

const view = computed(() => {
  const m = metrics.value;
  if (!m) return null;
  const s3 = m.s3 ?? { requests: 0, errors_4xx: 0, errors_5xx: 0, bytes_in: 0, bytes_out: 0, by_method: {} };
  const series = m.series ?? [];
  const rate = errorRate(s3.requests, s3.errors_4xx, s3.errors_5xx);
  return {
    since: m.since,
    labels: series.map((p) => hm(p.time)),
    tiles: [
      { label: t('Requests'), value: formatCount(s3.requests), caption: methodSummary(s3.by_method, formatCount) || t('No requests yet') },
      { label: t('Errors'), value: `${(rate * 100).toFixed(1)}%`, caption: `${formatCount(s3.errors_4xx)} 4xx · ${formatCount(s3.errors_5xx)} 5xx` },
      { label: t('Uploaded'), value: formatBytes(s3.bytes_in), caption: t('request bodies') },
      { label: t('Downloaded'), value: formatBytes(s3.bytes_out), caption: t('response bodies') },
    ],
    charts: [
      { title: t('Requests'), values: series.map((p) => p.requests ?? 0), format: (v: number) => tn(Math.round(v), '{n} request', '{n} requests', { n: formatCount(Math.round(v)) }) },
      { title: t('Errors'), values: series.map((p) => p.errors ?? 0), format: (v: number) => tn(Math.round(v), '{n} error', '{n} errors', { n: formatCount(Math.round(v)) }) },
      { title: t('Uploaded'), values: series.map((p) => p.bytes_in ?? 0), format: (v: number) => formatBytes(Math.round(v)) },
      { title: t('Downloaded'), values: series.map((p) => p.bytes_out ?? 0), format: (v: number) => formatBytes(Math.round(v)) },
    ],
  };
});
</script>

<template>
  <Page>
    <PageHead
      :title="t('Metrics')"
      :subtitle="view ? t('S3 API traffic since {t} (refreshes every 10 s).', { t: formatDateTime(view.since) }) : undefined"
    >
      <button class="btn ghost icon" :title="t('Refresh')" :disabled="loading" @click="load">
        <Spinner v-if="loading" /><RefreshCw v-else :size="16" />
      </button>
    </PageHead>

    <template v-if="view">
      <Callout v-if="error" tone="warning">{{ t('Last refresh failed: {e}', { e: error.message }) }}</Callout>
      <div class="wrap"><div class="grid">
        <div v-for="tile in view.tiles" :key="tile.label" class="card tile">
          <div class="t-label">{{ tile.label }}</div>
          <div class="t-headline-sm value">{{ tile.value }}</div>
          <div class="t-body-sm ellipsis" :title="tile.caption">{{ tile.caption }}</div>
        </div>
        <Panel v-for="c in view.charts" :key="c.title" class="chart" :title="c.title" :subtitle="t('Per minute, last 60 minutes')">
          <BarChart :values="c.values" :labels="view.labels" :format="c.format" />
        </Panel>
      </div></div>
    </template>
    <States v-else-if="error" kind="error" :message="error.message" :connection="error.isConnectionError" @retry="load" />
    <States v-else kind="loading" />
  </Page>
</template>

<style scoped>
.wrap { container-type: inline-size; }
.grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px; }
.tile { padding: 18px; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.value { margin-top: 6px; font-variant-numeric: tabular-nums; }
.chart { grid-column: span 2; }
/* 2.0: four tiles per row and charts side by side above 900 px, else two tiles and full-width charts. */
@container (max-width: 900px) {
  .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
</style>
