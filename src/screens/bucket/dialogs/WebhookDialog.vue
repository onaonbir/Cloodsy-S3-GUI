<script setup lang="ts">
// Add or edit a webhook (2.0 access_dialogs.dart _WebhookDialog): URL,
// name, signing secret (editing: empty keeps it), events "All events" or a
// selection where a wildcard covers its specific siblings, Active (edit).
import { computed, onMounted, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Toggle from '@/components/ui/Toggle.vue';
import { coveredByWildcard, eventsValue, isWildcard, parseEvents, toggleEvent, validWebhookUrl, type WebhookSave } from '../../buckets/logic';
import { WEBHOOK_EVENTS, type Webhook } from '@/lib/api';
import { t } from '@/lib/i18n';

const props = defineProps<{
  existing?: Webhook | null;
  canEdit?: boolean;
  save: (w: WebhookSave) => Promise<void>;
  done: (v: boolean | null) => void;
}>();

const w = props.existing ?? null;
const parsed = parseEvents(w ? w.event_types : '*');
const url = ref(w?.url ?? '');
const name = ref(w?.name ?? '');
const secret = ref('');
const all = ref(parsed.all);
const events = ref<string[]>(parsed.events);
const active = ref(w?.active ?? true);
const busy = ref(false);
const error = ref<string | null>(null);
const urlInput = ref<HTMLInputElement | null>(null);
onMounted(() => urlInput.value?.focus());

const labels = computed<Record<string, string>>(() => ({
  's3:ObjectCreated:*': t('All object created events'),
  's3:ObjectCreated:Put': t('Put'),
  's3:ObjectCreated:Copy': t('Copy'),
  's3:ObjectCreated:CompleteMultipartUpload': t('Multipart upload completed'),
  's3:ObjectRemoved:*': t('All object removed events'),
  's3:ObjectRemoved:Delete': t('Delete'),
  's3:ObjectRemoved:DeleteMarkerCreated': t('Delete marker created'),
}));

const checked = (e: string) => events.value.includes(e) || coveredByWildcard(events.value, e);

function onEvent(e: string, ev: Event) {
  events.value = toggleEvent(events.value, e, (ev.target as HTMLInputElement).checked);
  error.value = null;
}

async function submit() {
  if (busy.value) return;
  const u = url.value.trim();
  if (!validWebhookUrl(u)) {
    error.value = t('Enter an http:// or https:// URL');
    return;
  }
  const value = eventsValue(all.value, events.value);
  if (!value) {
    error.value = t('Pick at least one event');
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    await props.save({
      name: name.value.trim(),
      url: u,
      events: value,
      active: active.value,
      // Editing: an empty field keeps the stored secret.
      secret: w && !secret.value ? undefined : secret.value,
    });
    props.done(true);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="w ? t('Edit webhook') : t('Add webhook')" :width="520" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('The server POSTs a JSON event to this URL.') }}</p>
    <div class="field">
      <label for="wh-url">{{ t('Endpoint URL') }}</label>
      <input id="wh-url" ref="urlInput" v-model="url" class="input mono" type="url" :placeholder="t('https://example.com/hooks/s3')" spellcheck="false" @input="error = null" @keydown.enter="submit" />
    </div>
    <div class="two">
      <div class="field">
        <label for="wh-name">{{ t('Name (optional)') }}</label>
        <input id="wh-name" v-model="name" class="input" maxlength="255" />
      </div>
      <div class="field">
        <label for="wh-secret">{{ t('Signing secret (optional)') }}</label>
        <input id="wh-secret" v-model="secret" class="input" type="password" autocomplete="new-password" :placeholder="w?.has_secret ? t('Set · leave empty to keep') : ''" />
      </div>
    </div>

    <div class="field">
      <label>{{ t('Events') }}</label>
      <label class="check ev"><input v-model="all" type="checkbox" @change="error = null" />{{ t('All events') }}</label>
      <div v-if="!all" class="events">
        <label v-for="e in WEBHOOK_EVENTS" :key="e" class="check ev" :class="{ child: !isWildcard(e) }">
          <input type="checkbox" :checked="checked(e)" :disabled="coveredByWildcard(events, e)" @change="onEvent(e, $event)" />
          <span class="grow">
            <span class="ev-label">{{ labels[e] }}</span>
            <span class="mono ev-value">{{ e }}</span>
          </span>
        </label>
      </div>
    </div>

    <div v-if="canEdit" class="active">
      <div class="grow">
        <div class="t-label-lg">{{ t('Active') }}</div>
        <div class="t-body-sm">{{ t('Inactive webhooks receive no events') }}</div>
      </div>
      <Toggle v-model="active" :disabled="busy" />
    </div>

    <Callout v-if="error" tone="danger">{{ error }}</Callout>

    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit"><Loader2 v-if="busy" :size="15" class="spin" />{{ w ? t('Save') : t('Add webhook') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.two { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 12px; }
.events { display: flex; flex-direction: column; gap: 2px; }
.ev { align-items: flex-start; padding: 5px 0; }
.ev input { margin-top: 2px; }
.ev.child { padding-left: 26px; }
.ev:has(input:disabled) { opacity: 0.6; cursor: default; }
.ev-label { display: block; }
.ev-value { display: block; font-size: 11px; color: var(--subtle); margin-top: 1px; }
.active { display: flex; align-items: center; gap: 12px; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
