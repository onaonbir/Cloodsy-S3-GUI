<script setup lang="ts">
// Every bucket in a sortable, filterable table (2.0 buckets_screen.dart).
// Below 760 px of width only NAME and SIZE stay.
import { computed, ref } from 'vue';
import {
  ArrowDown, ArrowUp, Database, FolderCog, FolderOpen, Globe, HardDrive, History, KeyRound, LayoutGrid, Loader2, MoreHorizontal, Package,
  Plus, RefreshCw, Search, SearchX, Trash2, X,
} from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import UsageBar from '@/components/ui/UsageBar.vue';
import IconBadge from './IconBadge.vue';
import { buckets, bucketsError, bucketsLoaded, loadBuckets, refreshStatus } from '@/stores/session';
import { goBucket } from '@/stores/nav';
import { openMenu, SEP, type MenuItem } from '@/lib/menu';
import type { Bucket } from '@/lib/api';
import { formatBytes, formatCount, formatDate, formatDateTime } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import { createBucketFlow, deleteBucketFlow } from './flows';
import { hasQuota, nextSort, quotaFraction, quotaPercent, versioningEnabled, visibleBuckets, type BucketSort, type BucketSortKey } from './logic';

const query = ref('');
const sort = ref<BucketSort>({ key: 'name', asc: true });
const refreshing = ref(false);

const rows = computed(() => visibleBuckets(buckets.value, query.value, sort.value));
const totalUsage = computed(() => buckets.value.reduce((s, b) => s + (b.usage_bytes ?? 0), 0));

function setSort(key: BucketSortKey) {
  sort.value = nextSort(sort.value, key);
}

async function refresh() {
  if (refreshing.value) return;
  refreshing.value = true;
  try {
    await Promise.all([refreshStatus(), loadBuckets()]);
  } finally {
    refreshing.value = false;
  }
}

function menuItems(b: Bucket): MenuItem[] {
  return [
    { label: t('Open overview'), icon: LayoutGrid, action: () => goBucket(b.name, 'overview') },
    { label: t('Open files'), icon: FolderOpen, action: () => goBucket(b.name, 'files') },
    { label: t('Open access keys'), icon: KeyRound, action: () => goBucket(b.name, 'access') },
    SEP,
    { label: t('Delete bucket…'), icon: Trash2, danger: true, action: () => void deleteBucketFlow(b.name) },
  ];
}

const plain = (b: Bucket) => !versioningEnabled(b) && !b.public_read && !b.webdav_enabled && !b.storage_dir;
</script>

<template>
  <div class="page">
    <div class="page-header">
      <div class="grow">
        <h1>{{ t('Buckets') }}</h1>
        <p class="t-body">{{ tn(buckets.length, '{n} bucket · {size} stored', '{n} buckets · {size} stored', { size: formatBytes(totalUsage) }) }}</p>
      </div>
      <div class="search">
        <Search :size="14" class="subtle" />
        <input v-model="query" class="bare" :placeholder="t('Filter buckets')" spellcheck="false" @keydown.esc="query = ''" />
        <button v-if="query" class="btn ghost icon sm" :title="t('Clear')" @click="query = ''"><X :size="13" /></button>
      </div>
      <button class="btn icon" :title="t('Refresh')" :disabled="refreshing" @click="refresh">
        <Loader2 v-if="refreshing" :size="15" class="spin" /><RefreshCw v-else :size="15" />
      </button>
      <button class="btn primary" @click="createBucketFlow()"><Plus :size="16" />{{ t('New bucket') }}</button>
    </div>

    <States v-if="bucketsError && !buckets.length" kind="error" :message="bucketsError" @retry="refresh" />
    <States v-else-if="!bucketsLoaded" kind="loading" />
    <div v-else-if="!buckets.length" class="card">
      <States kind="empty" :title="t('No buckets yet')" :message="t('Buckets hold your objects. Create one, then add an access key to use it from any S3 client.')">
        <template #icon><Package :size="22" /></template>
        <template #actions><button class="btn primary" @click="createBucketFlow()"><Plus :size="16" />{{ t('Create bucket') }}</button></template>
      </States>
    </div>

    <div v-else class="wrap">
      <div class="card table-card">
        <table class="table">
          <thead>
            <tr>
              <th class="sortable" :class="{ on: sort.key === 'name' }" @click="setSort('name')">
                <span class="th">{{ t('Name') }}<component :is="sort.asc ? ArrowUp : ArrowDown" v-if="sort.key === 'name'" :size="12" /></span>
              </th>
              <th class="sortable num wide" :class="{ on: sort.key === 'objects' }" @click="setSort('objects')">
                <span class="th">{{ t('Objects') }}<component :is="sort.asc ? ArrowUp : ArrowDown" v-if="sort.key === 'objects'" :size="12" /></span>
              </th>
              <th class="sortable num" :class="{ on: sort.key === 'size' }" @click="setSort('size')">
                <span class="th">{{ t('Size') }}<component :is="sort.asc ? ArrowUp : ArrowDown" v-if="sort.key === 'size'" :size="12" /></span>
              </th>
              <th class="wide quota-col">{{ t('Quota') }}</th>
              <th class="sortable wide" :class="{ on: sort.key === 'created' }" @click="setSort('created')">
                <span class="th">{{ t('Created') }}<component :is="sort.asc ? ArrowUp : ArrowDown" v-if="sort.key === 'created'" :size="12" /></span>
              </th>
              <th class="menu-col" />
            </tr>
          </thead>
          <tbody>
            <tr v-if="!rows.length" class="no-hover">
              <td colspan="6">
                <States kind="empty" compact :title="t('No matching buckets')"><template #icon><SearchX :size="22" /></template></States>
              </td>
            </tr>
            <tr v-for="b in rows" :key="b.name" class="row-link" @click="goBucket(b.name)" @contextmenu="openMenu($event, menuItems(b))">
              <td>
                <div class="name-cell">
                  <IconBadge :icon="Package" :size="32" />
                  <div class="grow">
                    <div class="name ellipsis">{{ b.name }}</div>
                    <div class="pills">
                      <Pill v-if="versioningEnabled(b)" tone="primary"><History :size="11" />{{ t('Versioned') }}</Pill>
                      <Pill v-if="b.public_read" tone="warning"><Globe :size="11" />{{ t('Public') }}</Pill>
                      <Pill v-if="b.webdav_enabled"><HardDrive :size="11" />{{ t('WebDAV') }}</Pill>
                      <Pill v-if="b.storage_dir"><FolderCog :size="11" />{{ t('Custom storage') }}</Pill>
                      <span v-if="plain(b)" class="t-body-sm">{{ tn(b.credentials ?? 0, '{n} access key', '{n} access keys') }}</span>
                    </div>
                  </div>
                </div>
              </td>
              <td class="num wide">{{ formatCount(b.objects ?? 0) }}</td>
              <td class="num">{{ formatBytes(b.usage_bytes ?? 0) }}</td>
              <td class="wide quota-col">
                <template v-if="hasQuota(b)">
                  <UsageBar :value="quotaFraction(b)" :height="5" />
                  <div class="t-body-sm quota-text">{{ t('{p}% of {size}', { p: quotaPercent(b), size: formatBytes(b.quota_bytes) }) }}</div>
                </template>
                <span v-else class="subtle">{{ t('Unlimited') }}</span>
              </td>
              <td class="wide" :title="formatDateTime(b.created_at)">{{ formatDate(b.created_at) }}</td>
              <td class="menu-col">
                <button class="btn ghost icon sm" :title="t('More')" @click.stop="openMenu($event, menuItems(b))"><MoreHorizontal :size="16" /></button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="query && rows.length" class="t-body-sm count"><Database :size="12" />{{ t('{n} of {total} buckets', { n: rows.length, total: buckets.length }) }}</p>
    </div>
  </div>
</template>

<style scoped>
.search { display: flex; align-items: center; gap: 6px; width: 240px; height: 34px; padding: 0 4px 0 10px; border: 1px solid var(--border); border-radius: var(--radius-md); background: var(--card); }
.search:focus-within { border-color: var(--primary); box-shadow: 0 0 0 3px var(--primary-soft); }
.bare { flex: 1; min-width: 0; border: 0; outline: none; background: none; color: var(--foreground); font: 400 13px var(--font-sans); user-select: text; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.wrap { container-type: inline-size; display: flex; flex-direction: column; gap: 8px; }
.table-card { overflow: hidden; }
.table th { padding-top: 12px; padding-bottom: 12px; }
.table th:first-child, .table td:first-child { padding-left: 18px; }
.table tbody tr:not(.no-hover) td:first-child { max-width: 0; width: 42%; }
.table th.on { color: var(--foreground); }
.th { display: inline-flex; align-items: center; gap: 4px; }
.row-link { cursor: pointer; }
.no-hover:hover td { background: none !important; }
.name-cell { display: flex; align-items: center; gap: 12px; min-width: 0; }
.name { font-weight: 600; font-size: 13.5px; }
.pills { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; align-items: center; }
.quota-col { width: 22%; min-width: 150px; }
.quota-text { margin-top: 4px; }
.menu-col { width: 44px; text-align: right; padding-right: 8px !important; }
.count { display: flex; align-items: center; gap: 6px; padding-left: 4px; }

@container (max-width: 759px) {
  .wide { display: none; }
}
@media (max-width: 700px) {
  .search { width: 180px; }
}
</style>
