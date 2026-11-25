<script setup lang="ts">
// Usage against the quota, the bucket's details and how to connect
// (2.0 overview_tab.dart).
import { computed } from 'vue';
import { Database, Globe, Info, KeyRound, Lock, Plug } from 'lucide-vue-next';
import Callout from '@/components/ui/Callout.vue';
import CopyValue from '@/components/ui/CopyValue.vue';
import Pill from '@/components/ui/Pill.vue';
import UsageBar from '@/components/ui/UsageBar.vue';
import Panel from '../buckets/Panel.vue';
import InfoRow from '../buckets/InfoRow.vue';
import { useBucket } from '../buckets/bucketStore';
import { hasQuota, quotaFraction, versioningEnabled, webdavMountUrl } from '../buckets/logic';
import { server, status } from '@/stores/session';
import { goBucket } from '@/stores/nav';
import { formatBytes, formatCount, formatDateTime } from '@/lib/format';
import { t, tn } from '@/lib/i18n';

const { state: s } = useBucket();
const b = computed(() => s.bucket!);

const mount = computed(() => (b.value.webdav_enabled ? webdavMountUrl(server.value?.url, status.value) : null));
const versioningLabel = computed(() => {
  const v = b.value.versioning;
  return v === 'Enabled' ? t('Enabled') : v === 'Suspended' ? t('Suspended') : t('Disabled');
});
const storage = computed(() => b.value.storage_path || b.value.storage_dir || '');
</script>

<template>
  <div class="ov-wrap"><div class="overview">
    <div class="col-a">
      <Panel :title="t('Usage')" :icon="Database">
        <div class="usage">
          <span class="big">{{ formatBytes(b.usage_bytes ?? 0) }}</span>
          <span class="t-body">{{ hasQuota(b) ? t('of {size}', { size: formatBytes(b.quota_bytes) }) : t('no quota') }}</span>
        </div>
        <UsageBar v-if="hasQuota(b)" :value="quotaFraction(b)" :height="8" class="bar" />
        <div class="metrics">
          <div><div class="t-title">{{ formatCount(b.objects ?? 0) }}</div><div class="t-body-sm">{{ t('Objects') }}</div></div>
          <div><div class="t-title">{{ formatCount(b.credentials ?? s.credentials.length) }}</div><div class="t-body-sm">{{ t('Access keys') }}</div></div>
          <div><div class="t-title">{{ s.rules.length }}</div><div class="t-body-sm">{{ t('Rules') }}</div></div>
          <div><div class="t-title">{{ s.webhooks.length }}</div><div class="t-body-sm">{{ t('Webhooks') }}</div></div>
        </div>
      </Panel>

      <Panel :title="t('Connect')" :subtitle="t('Use any S3 SDK, rclone, s3cmd or the Cloodsy app.')" :icon="Plug">
        <div class="connect">
          <div class="field">
            <label>{{ t('Bucket') }}</label>
            <CopyValue :value="b.name" :label="t('Bucket')" />
          </div>
          <div v-if="mount" class="field">
            <label>{{ t('WebDAV mount') }}</label>
            <!-- The WebDAV root is per credential: the access key decides which bucket the mount shows. -->
            <CopyValue :value="mount" :label="t('WebDAV mount')" />
            <span class="hint">{{ t('Sign in with an access key of this bucket as username and its secret key as password.') }}</span>
          </div>
          <Callout v-if="!s.credentials.length" tone="info">
            {{ t('No access keys yet. Create one to connect clients.') }}
            <template #actions><button class="btn sm" @click="goBucket(b.name, 'access')">{{ t('Create key') }}</button></template>
          </Callout>
          <div v-else class="keys">
            <KeyRound :size="14" class="muted" />
            <span class="grow t-body">{{ tn(s.credentials.length, '{n} access key can reach this bucket.', '{n} access keys can reach this bucket.') }}</span>
            <button class="btn ghost sm" @click="goBucket(b.name, 'access')">{{ t('Manage') }}</button>
          </div>
        </div>
      </Panel>
    </div>

    <div class="col-b">
      <Panel :title="t('Details')" :icon="Info">
        <InfoRow :label="t('Name')" :value="b.name" mono />
        <InfoRow :label="t('Created')" :value="formatDateTime(b.created_at)" />
        <InfoRow :label="t('Versioning')"><Pill :tone="versioningEnabled(b) ? 'primary' : 'neutral'">{{ versioningLabel }}</Pill></InfoRow>
        <InfoRow :label="t('Access')">
          <Pill v-if="b.public_read" tone="warning"><Globe :size="11" />{{ t('Public read') }}</Pill>
          <Pill v-else tone="success"><Lock :size="11" />{{ t('Private') }}</Pill>
        </InfoRow>
        <InfoRow :label="t('WebDAV')"><Pill :tone="b.webdav_enabled ? 'success' : 'neutral'">{{ b.webdav_enabled ? t('Enabled') : t('Off') }}</Pill></InfoRow>
        <InfoRow :label="t('Storage')" :value="storage || t('Default directory')" :mono="!!storage" />
      </Panel>
    </div>
  </div></div>
</template>

<style scoped>
.ov-wrap { container-type: inline-size; }
.overview { display: grid; grid-template-columns: 1fr; gap: var(--space-lg); }
.col-a, .col-b { display: flex; flex-direction: column; gap: var(--space-lg); min-width: 0; }
@container (min-width: 860px) {
  .overview { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
}
.usage { display: flex; align-items: baseline; gap: 8px; }
.big { font-size: 28px; font-weight: 700; letter-spacing: -0.5px; }
.bar { margin-top: 10px; }
.metrics { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; margin-top: 16px; }
.connect { display: flex; flex-direction: column; gap: 14px; }
.keys { display: flex; align-items: center; gap: 8px; }
</style>
