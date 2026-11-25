<script setup lang="ts">
// The server at a glance (2.0 dashboard_screen.dart): tiles, the largest
// buckets and the server panel, with update / refresh-failed callouts.
import { computed, ref } from 'vue';
import { Activity, BarChart3, Database, Files, HardDrive, Loader2, Package, Plus, RefreshCw, Server as ServerIcon } from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import UsageBar from '@/components/ui/UsageBar.vue';
import Panel from './buckets/Panel.vue';
import IconBadge from './buckets/IconBadge.vue';
import InfoRow from './buckets/InfoRow.vue';
import {
  buckets, bucketsError, bucketsLoaded, legacyServer, loadBuckets, refreshStatus, server, serverUpdate, sessionInfo, status, statusError,
} from '@/stores/session';
import { go, goBucket } from '@/stores/nav';
import { formatBytes, formatCount, formatUptime } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import { createBucketFlow } from './buckets/flows';
import { hasQuota, quotaFraction, quotaPercent } from './buckets/logic';

const refreshing = ref(false);

async function refresh() {
  if (refreshing.value) return;
  refreshing.value = true;
  try {
    await Promise.all([refreshStatus(), loadBuckets()]);
  } finally {
    refreshing.value = false;
  }
}

const isOk = computed(() => status.value?.status === 'ok');
const statusLabel = computed(() => (isOk.value ? t('Online') : (status.value?.status ?? '')));
const totalObjects = computed(() => buckets.value.reduce((s, b) => s + (b.objects ?? 0), 0));
const totalUsage = computed(() => buckets.value.reduce((s, b) => s + (b.usage_bytes ?? 0), 0));
const publicCount = computed(() => buckets.value.filter((b) => b.public_read).length);
const disk = computed(() => {
  const s = status.value?.storage;
  const total = s?.total_bytes ?? 0;
  if (!s || total <= 0) return null;
  const free = s.free_bytes ?? 0;
  return { total, free, used: Math.max(0, Math.min(1, (total - free) / total)) };
});
const top = computed(() => [...buckets.value].sort((a, b) => (b.usage_bytes ?? 0) - (a.usage_bytes ?? 0)).slice(0, 6));
const refreshError = computed(() => statusError.value ?? (buckets.value.length ? bucketsError.value : null));
const webdavText = computed(() => {
  const w = status.value?.webdav;
  if (!w?.enabled) return t('Off');
  return w.listen ? `${t('Enabled')} · ${w.listen}` : t('Enabled');
});
</script>

<template>
  <States v-if="!status && statusError" kind="error" :message="statusError" @retry="refresh" />
  <States v-else-if="!status" kind="loading" />
  <div v-else class="page dash">
    <div class="page-header">
      <div class="grow">
        <h1>{{ t('Dashboard') }}</h1>
        <p class="t-body">{{ server?.name ?? '' }} · {{ t('signed in as {u}', { u: sessionInfo?.username ?? '' }) }}</p>
      </div>
      <button class="btn" :disabled="refreshing" @click="refresh">
        <Loader2 v-if="refreshing" :size="15" class="spin" /><RefreshCw v-else :size="15" />{{ t('Refresh') }}
      </button>
      <button class="btn primary" @click="createBucketFlow()"><Plus :size="16" />{{ t('New bucket') }}</button>
    </div>

    <Callout v-if="serverUpdate" tone="info">
      {{ t('Cloodsy S3 v{v} is available (this server runs v{c}). Run "cloodsys3 update" on the server to upgrade.', { v: serverUpdate.replace(/^v/, ''), c: status.version }) }}
    </Callout>
    <Callout v-if="refreshError" tone="danger">{{ t('Last refresh failed: {e}', { e: refreshError }) }}</Callout>

    <div class="tiles-wrap">
      <div class="tiles">
        <div class="tile card">
          <div class="tile-head"><span class="t-label">{{ t('Buckets') }}</span><IconBadge :icon="Package" :size="30" /></div>
          <div class="tile-value ellipsis">{{ bucketsLoaded ? formatCount(buckets.length) : '—' }}</div>
          <div class="t-body-sm ellipsis">{{ t('{n} public', { n: publicCount }) }}</div>
        </div>
        <div class="tile card">
          <div class="tile-head"><span class="t-label">{{ t('Objects') }}</span><IconBadge :icon="Files" :size="30" /></div>
          <div class="tile-value ellipsis">{{ bucketsLoaded ? formatCount(totalObjects) : '—' }}</div>
          <div class="t-body-sm ellipsis">{{ t('across all buckets') }}</div>
        </div>
        <div class="tile card">
          <div class="tile-head"><span class="t-label">{{ t('Stored') }}</span><IconBadge :icon="Database" :size="30" /></div>
          <div class="tile-value ellipsis">{{ bucketsLoaded ? formatBytes(totalUsage) : '—' }}</div>
          <div class="t-body-sm ellipsis">{{ t('latest object versions') }}</div>
        </div>
        <div v-if="disk" class="tile card">
          <div class="tile-head"><span class="t-label">{{ t('Disk') }}</span><IconBadge :icon="HardDrive" :size="30" /></div>
          <div class="tile-value ellipsis">{{ t('{size} free', { size: formatBytes(disk.free) }) }}</div>
          <UsageBar :value="disk.used" :height="4" class="tile-bar" />
          <div class="t-body-sm ellipsis">{{ t('of {size}', { size: formatBytes(disk.total) }) }}</div>
        </div>
        <div v-else class="tile card">
          <div class="tile-head"><span class="t-label">{{ t('Status') }}</span><IconBadge :icon="Activity" :size="30" :tone="isOk ? 'success' : 'danger'" /></div>
          <div class="tile-value ellipsis">{{ statusLabel }}</div>
          <div class="t-body-sm ellipsis">{{ status.version ? `v${status.version}` : '' }}</div>
        </div>
      </div>
    </div>

    <div class="cols-wrap">
      <div class="cols">
        <Panel :title="t('Largest buckets')" :icon="BarChart3" flush class="main-col">
          <template #actions><button class="btn ghost sm" @click="go({ kind: 'buckets' })">{{ t('View all') }}</button></template>
          <States v-if="!bucketsLoaded" kind="loading" compact />
          <States v-else-if="!top.length" kind="empty" compact :title="t('No buckets yet')" :message="t('Create a bucket to start storing objects.')">
            <template #icon><Package :size="22" /></template>
            <template #actions><button class="btn primary" @click="createBucketFlow()"><Plus :size="16" />{{ t('New bucket') }}</button></template>
          </States>
          <div v-else class="top">
            <button v-for="b in top" :key="b.name" class="top-row" @click="goBucket(b.name)">
              <IconBadge :icon="Package" :size="32" />
              <div class="grow">
                <div class="row"><span class="grow ellipsis t-title-sm">{{ b.name }}</span><span class="t-label size">{{ formatBytes(b.usage_bytes ?? 0) }}</span></div>
                <UsageBar v-if="hasQuota(b)" :value="quotaFraction(b)" :height="4" class="top-bar" />
                <div class="t-body-sm">
                  {{ hasQuota(b)
                    ? tn(b.objects ?? 0, '{n} object · {p}% of {size} quota', '{n} objects · {p}% of {size} quota', { n: formatCount(b.objects ?? 0), p: quotaPercent(b), size: formatBytes(b.quota_bytes) })
                    : tn(b.objects ?? 0, '{n} object · no quota', '{n} objects · no quota', { n: formatCount(b.objects ?? 0) }) }}
                </div>
              </div>
            </button>
          </div>
        </Panel>

        <Panel :title="t('Server')" :icon="ServerIcon" class="side-col">
          <InfoRow :label="t('Status')"><Pill :tone="isOk ? 'success' : 'danger'" dot>{{ statusLabel }}</Pill></InfoRow>
          <InfoRow :label="t('Version')" :value="status.version ? `v${status.version}` : '—'" />
          <InfoRow v-if="status.uptime_seconds != null" :label="t('Uptime')" :value="formatUptime(status.uptime_seconds)" />
          <template v-if="status.tls">
            <InfoRow :label="t('S3 TLS')"><Pill :tone="status.tls.s3 ? 'success' : 'neutral'" dot>{{ status.tls.s3 ? t('Enabled') : t('Off') }}</Pill></InfoRow>
            <InfoRow :label="t('Admin TLS')"><Pill :tone="status.tls.admin ? 'success' : 'neutral'" dot>{{ status.tls.admin ? t('Enabled') : t('Off') }}</Pill></InfoRow>
            <InfoRow v-if="status.tls.acme" :label="t('Certificates')" :value="`Let’s Encrypt · ${(status.tls.acme_domains ?? []).join(', ')}`" />
          </template>
          <InfoRow :label="t('WebDAV')"><Pill :tone="status.webdav?.enabled ? 'success' : 'neutral'" dot>{{ webdavText }}</Pill></InfoRow>
          <InfoRow v-if="status.storage?.path" :label="t('Data directory')" :value="status.storage.path" mono />
          <Callout v-if="legacyServer" class="legacy">{{ t('This server predates file upload/download in the admin API. Update the server to browse, upload and download objects here.') }}</Callout>
        </Panel>
      </div>
    </div>
  </div>
</template>

<style scoped>
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.tiles-wrap, .cols-wrap { container-type: inline-size; }
.tiles { display: grid; grid-template-columns: 1fr; gap: 14px; }
@container (min-width: 521px) { .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@container (min-width: 901px) { .tiles { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
.tile { height: 128px; padding: 18px; display: flex; flex-direction: column; min-width: 0; }
.tile-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: auto; }
.tile-value { font-size: 22px; font-weight: 700; letter-spacing: -0.3px; margin-bottom: 4px; }
.tile-bar { margin-bottom: 5px; }

.cols { display: flex; flex-direction: column; gap: 16px; }
@container (min-width: 901px) {
  .cols { flex-direction: row; align-items: flex-start; }
  .main-col { flex: 3; }
  .side-col { flex: 2; }
}
.top { display: flex; flex-direction: column; padding: 2px; }
.top-row { display: flex; align-items: center; gap: 12px; padding: 10px; border: 0; border-radius: var(--radius-md); background: none; color: var(--foreground); font-family: inherit; text-align: left; cursor: pointer; }
.top-row:hover { background: var(--hover); }
.size { color: var(--foreground); }
.top-bar { margin-top: 6px; }
.top-row .t-body-sm { margin-top: 4px; }
.legacy { margin-top: 10px; }
</style>
