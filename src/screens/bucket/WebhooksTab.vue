<script setup lang="ts">
// Webhooks of the bucket (2.0 webhooks_tab.dart). v2 servers add Test
// (40 s), delivery history and Edit (with Active); older ones add and delete.
import { computed, reactive } from 'vue';
import { ListChecks, Loader2, Lock, Pencil, Plus, Send, Trash2, Webhook as WebhookIcon } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import IconBadge from '../buckets/IconBadge.vue';
import WebhookDialog from './dialogs/WebhookDialog.vue';
import DeliveriesDialog from './dialogs/DeliveriesDialog.vue';
import { useBucket } from '../buckets/bucketStore';
import { deliveryOk, parseEvents, type WebhookSave } from '../buckets/logic';
import { has } from '@/stores/session';
import { runAction, toast } from '@/stores/toasts';
import { confirm } from '@/lib/dialogs';
import { openDialog } from '@/lib/overlay';
import { ApiError } from '@/lib/ipc';
import type { Webhook } from '@/lib/api';
import { formatDate, formatDateTime } from '@/lib/format';
import { t } from '@/lib/i18n';

const store = useBucket();
const s = store.state;
const v2 = computed(() => has('webhooks-v2'));
const testing = reactive<Record<number, boolean>>({});

/** The server answers within its own delivery timeout; the GUI gives up after 40 s. */
const TEST_TIMEOUT_MS = 40_000;

function add() {
  void openDialog<boolean>(WebhookDialog, { save: (w: WebhookSave) => store.addWebhook(w) });
}

function edit(h: Webhook) {
  void openDialog<boolean>(WebhookDialog, { existing: h, canEdit: true, save: (w: WebhookSave) => store.updateWebhook(h.id, w) });
}

function events(h: Webhook): string[] {
  const p = parseEvents(h.event_types);
  return p.all ? [t('All events')] : p.events;
}

async function test(h: Webhook) {
  testing[h.id] = true;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const timeout = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new ApiError(0, t('No answer within {n} s', { n: TEST_TIMEOUT_MS / 1000 }))), TEST_TIMEOUT_MS);
    });
    const r = await Promise.race([store.testWebhook(h.id), timeout]);
    const ok = deliveryOk({ error: r.error ?? '', status_code: r.status_code });
    toast(
      ok
        ? t('Test delivered: HTTP {code} in {ms} ms', { code: r.status_code, ms: r.duration_ms })
        : t('Test failed: {e}', { e: r.error || `HTTP ${r.status_code}` }),
      !ok,
    );
  } catch (e) {
    if ((e as ApiError).status !== -1) toast((e as Error).message, true);
  } finally {
    clearTimeout(timer);
    testing[h.id] = false;
  }
}

function deliveries(h: Webhook) {
  void openDialog(DeliveriesDialog, { hook: h, load: () => store.deliveries(h.id) });
}

async function remove(h: Webhook) {
  const ok = await confirm({ title: t('Delete webhook'), message: t('Stop sending events to this URL?'), detail: h.url, confirmLabel: t('Delete'), danger: true });
  if (ok) await runAction(() => store.deleteWebhook(h.id), t('Webhook deleted'));
}
</script>

<template>
  <div class="tab">
    <div class="intro">
      <p class="t-body grow">{{ t('Webhooks notify your services when objects are created or removed in this bucket.') }}</p>
      <button class="btn primary" @click="add"><Plus :size="16" />{{ t('Add webhook') }}</button>
    </div>

    <div v-if="!s.webhooks.length" class="card">
      <States kind="empty" compact :title="t('No webhooks')" :message="t('Send object events to a URL, e.g. to trigger thumbnails, indexing or notifications.')">
        <template #icon><WebhookIcon :size="22" /></template>
        <template #actions><button class="btn" @click="add"><Plus :size="16" />{{ t('Add webhook') }}</button></template>
      </States>
    </div>

    <div v-else class="card list">
      <div v-for="h in s.webhooks" :key="h.id" class="hook">
        <IconBadge :icon="WebhookIcon" :tone="h.active ? 'success' : 'neutral'" :size="34" />
        <div class="grow">
          <div class="row wrap">
            <span class="t-title-sm ellipsis">{{ h.name || t('Webhook #{id}', { id: h.id }) }}</span>
            <Pill :tone="h.active ? 'success' : 'neutral'" dot>{{ h.active ? t('Active') : t('Inactive') }}</Pill>
            <Pill v-if="h.has_secret"><Lock :size="11" />{{ t('Signed') }}</Pill>
          </div>
          <div class="mono url selectable">{{ h.url }}</div>
          <div class="pills"><Pill v-for="e in events(h)" :key="e">{{ e }}</Pill></div>
        </div>
        <span class="t-body-sm date" :title="formatDateTime(h.created_at)">{{ formatDate(h.created_at) }}</span>
        <div class="acts">
          <template v-if="v2">
            <button class="btn ghost icon sm" :title="t('Send a test event')" :disabled="testing[h.id]" @click="test(h)">
              <Loader2 v-if="testing[h.id]" :size="15" class="spin" /><Send v-else :size="15" />
            </button>
            <button class="btn ghost icon sm" :title="t('Delivery history')" @click="deliveries(h)"><ListChecks :size="15" /></button>
            <button class="btn ghost icon sm" :title="t('Edit')" @click="edit(h)"><Pencil :size="15" /></button>
          </template>
          <button class="btn ghost icon sm danger" :title="t('Delete webhook')" @click="remove(h)"><Trash2 :size="15" /></button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tab { display: flex; flex-direction: column; gap: 16px; }
.intro { display: flex; align-items: center; gap: 12px; }
.list { overflow: hidden; }
.hook { display: flex; align-items: flex-start; gap: 12px; padding: 12px 8px 12px 16px; }
.hook + .hook { border-top: 1px solid var(--border); }
.wrap { flex-wrap: wrap; row-gap: 4px; }
.url { font-size: 12px; color: var(--muted); margin-top: 3px; word-break: break-all; }
.pills { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
.date { padding-top: 8px; white-space: nowrap; }
.acts { display: flex; gap: 2px; padding-top: 3px; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
