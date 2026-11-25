<script setup lang="ts">
// The last 50 delivery attempts of a webhook (v2 servers).
import { computed, onMounted, ref } from 'vue';
import { CheckCircle2, Loader2, RefreshCw, XCircle } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import States from '@/components/ui/States.vue';
import { deliveryOk } from '../../buckets/logic';
import type { Delivery, Webhook } from '@/lib/api';
import { formatDateTime, formatRelative } from '@/lib/format';
import { t } from '@/lib/i18n';

const props = defineProps<{ hook: Webhook; load: () => Promise<Delivery[]>; done: (v: null) => void }>();

const items = ref<Delivery[] | null>(null);
const error = ref<string | null>(null);
const loading = ref(false);
let seq = 0;

async function reload() {
  const my = ++seq;
  loading.value = true;
  error.value = null;
  try {
    const r = await props.load();
    if (my === seq) items.value = r;
  } catch (e) {
    if (my === seq) error.value = (e as Error).message;
  } finally {
    if (my === seq) loading.value = false;
  }
}
onMounted(reload);

const okCount = computed(() => (items.value ?? []).filter(deliveryOk).length);

function detail(d: Delivery): string {
  if (d.error) return d.error;
  const base = t('HTTP {code} · {ms} ms', { code: d.status_code, ms: d.duration_ms });
  return d.attempt > 1 ? `${base} · ${t('attempt {n}', { n: d.attempt })}` : base;
}
</script>

<template>
  <Modal :width="640" @close="done(null)">
    <template #header>
      <div class="head grow">
        <h2>{{ t('Deliveries') }}</h2>
        <div class="mono subtle ellipsis" :title="hook.url">{{ hook.url }}</div>
      </div>
    </template>

    <Callout v-if="error" tone="danger">{{ error }}</Callout>
    <States v-else-if="items === null" kind="loading" compact />
    <p v-else-if="!items.length" class="t-body">{{ t('No deliveries yet. Use “Send a test event” to try it.') }}</p>
    <template v-else>
      <div class="t-label-lg">{{ t('{ok} of {n} recent deliveries succeeded', { ok: okCount, n: items.length }) }}</div>
      <div class="list">
        <div v-for="d in items" :key="d.id" class="item">
          <CheckCircle2 v-if="deliveryOk(d)" :size="16" class="success-text icon" />
          <XCircle v-else :size="16" class="danger-text icon" />
          <div class="grow">
            <div class="ellipsis selectable what" :title="`${d.event_type} · ${d.object_key}`">{{ d.event_type }}<template v-if="d.object_key"> · {{ d.object_key }}</template></div>
            <div class="t-body-sm selectable" :class="{ 'danger-text': !deliveryOk(d) }">{{ detail(d) }}</div>
          </div>
          <span class="t-body-sm when" :title="formatDateTime(d.created_at)">{{ formatRelative(d.created_at) }}</span>
        </div>
      </div>
    </template>

    <template #footer>
      <button class="btn ghost refresh" :disabled="loading" @click="reload">
        <Loader2 v-if="loading" :size="15" class="spin" /><RefreshCw v-else :size="15" />{{ t('Refresh') }}
      </button>
      <button class="btn primary" @click="done(null)">{{ t('Close') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.head .mono { font-size: 12px; }
.list { border: 1px solid var(--border); border-radius: var(--radius-md); }
.item { display: flex; align-items: flex-start; gap: 10px; padding: 8px 12px; }
.item + .item { border-top: 1px solid var(--border); }
.icon { margin-top: 2px; }
.what { font-size: 13.5px; }
.when { white-space: nowrap; padding-top: 2px; }
.refresh { margin-right: auto; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
