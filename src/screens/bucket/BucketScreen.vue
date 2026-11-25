<script setup lang="ts">
// One bucket with its tabs (2.0 bucket_screen.dart). The bucket, its keys,
// lifecycle rules and webhooks load in parallel and stay while switching
// tabs; the tab itself lives in the navigation (goBucket(name, tab)).
import { computed, provide } from 'vue';
import { ArrowLeft, Loader2, MoreHorizontal, RefreshCw, Trash2 } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import Tabs from '@/components/ui/Tabs.vue';
import FilesTab from './FilesTab.vue';
import OverviewTab from './OverviewTab.vue';
import AccessTab from './AccessTab.vue';
import SettingsTab from './SettingsTab.vue';
import LifecycleTab from './LifecycleTab.vue';
import WebhooksTab from './WebhooksTab.vue';
import { current, go, goBucket, type BucketTab } from '@/stores/nav';
import { openMenu } from '@/lib/menu';
import { t } from '@/lib/i18n';
import { BUCKET_STORE, createBucketStore } from '../buckets/bucketStore';
import { deleteBucketFlow } from '../buckets/flows';
import { versioningEnabled } from '../buckets/logic';

// AppShell keys this screen by bucket name, so the name is fixed for its life.
const name = current.value.kind === 'bucket' ? current.value.name : '';
const store = createBucketStore(name);
provide(BUCKET_STORE, store);
const s = store.state;
void store.load();

const tab = computed<BucketTab>(() => (current.value.kind === 'bucket' && current.value.name === name ? current.value.tab : 'overview'));
const prefix = computed(() => (current.value.kind === 'bucket' && current.value.name === name ? current.value.prefix : undefined));

const tabs = computed(() => [
  { id: 'overview', label: t('Overview') },
  { id: 'files', label: t('Files') },
  { id: 'access', label: t('Access keys'), badge: s.credentials.length },
  { id: 'settings', label: t('Settings') },
  { id: 'lifecycle', label: t('Lifecycle'), badge: s.rules.length },
  { id: 'webhooks', label: t('Webhooks'), badge: s.webhooks.length },
]);

function more(e: MouseEvent) {
  openMenu(e, [{ label: t('Delete bucket…'), icon: Trash2, danger: true, action: () => void deleteBucketFlow(name) }]);
}
</script>

<template>
  <div class="bucket-screen">
    <div class="top">
      <div class="page-header">
        <button class="btn ghost icon" :title="t('All buckets')" @click="go({ kind: 'buckets' })"><ArrowLeft :size="18" /></button>
        <h1 class="ellipsis selectable title">{{ name }}</h1>
        <template v-if="s.bucket">
          <Pill v-if="versioningEnabled(s.bucket)" tone="primary">{{ t('Versioned') }}</Pill>
          <Pill v-if="s.bucket.public_read" tone="warning">{{ t('Public') }}</Pill>
        </template>
        <span class="spacer" />
        <button class="btn icon" :title="t('Reload')" :disabled="s.loading" @click="store.load()">
          <Loader2 v-if="s.loading" :size="15" class="spin" /><RefreshCw v-else :size="15" />
        </button>
        <button class="btn icon" :title="t('More')" @click="more"><MoreHorizontal :size="16" /></button>
      </div>
      <Tabs :tabs="tabs" :model-value="tab" @update:model-value="(id) => goBucket(name, id as BucketTab)" />
    </div>

    <div v-if="!s.bucket" class="body scroll">
      <States v-if="s.error" kind="error" :message="s.error" :connection="s.connectionError" @retry="store.load()" />
      <States v-else kind="loading" />
    </div>
    <template v-else>
      <div v-show="tab === 'files'" class="body files">
        <KeepAlive><FilesTab v-if="tab === 'files'" :bucket="name" :initial-prefix="prefix" /></KeepAlive>
      </div>
      <div v-if="tab !== 'files'" class="body scroll">
        <OverviewTab v-if="tab === 'overview'" />
        <AccessTab v-else-if="tab === 'access'" />
        <SettingsTab v-else-if="tab === 'settings'" />
        <LifecycleTab v-else-if="tab === 'lifecycle'" />
        <WebhooksTab v-else-if="tab === 'webhooks'" />
      </div>
    </template>
  </div>
</template>

<style scoped>
.bucket-screen { height: 100%; display: flex; flex-direction: column; min-height: 0; }
.top { padding: 24px var(--page) 0; display: flex; flex-direction: column; gap: 14px; flex-shrink: 0; }
.page-header { flex-wrap: nowrap; gap: 10px; }
.page-header > .btn.ghost:first-child { margin-left: -8px; }
.title { font-size: 24px; font-weight: 700; letter-spacing: -0.4px; }
.body { flex: 1; min-height: 0; }
.body.scroll { overflow-y: auto; padding: 18px var(--page) 40px; }
.body.files { display: flex; flex-direction: column; overflow: hidden; }
.body.files > :deep(*) { flex: 1; min-height: 0; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
