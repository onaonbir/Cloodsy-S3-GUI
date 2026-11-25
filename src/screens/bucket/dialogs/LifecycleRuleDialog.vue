<script setup lang="ts">
// Create or edit a lifecycle rule with every action a v2 server supports
// (2.0 lifecycle_dialog.dart).
import { onMounted, reactive, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Toggle from '@/components/ui/Toggle.vue';
import { buildRule, ruleForm } from '../../buckets/logic';
import type { LifecycleRule } from '@/lib/api';
import { t } from '@/lib/i18n';

const props = defineProps<{
  existing?: LifecycleRule | null;
  versioned: boolean;
  save: (rule: LifecycleRule) => Promise<void>;
  done: (v: boolean | null) => void;
}>();

const f = reactive(ruleForm(props.existing));
const busy = ref(false);
const error = ref<string | null>(null);
const nameInput = ref<HTMLInputElement | null>(null);
onMounted(() => {
  if (!props.existing) nameInput.value?.focus();
});

async function submit() {
  if (busy.value) return;
  const r = buildRule(f, props.existing?.id ?? 0);
  if ('error' in r) {
    error.value = r.error;
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    await props.save(r.rule);
    props.done(true);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="existing ? t('Edit rule') : t('New lifecycle rule')" :width="580" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('Rules run periodically on the server.') }}</p>
    <div class="two">
      <div class="field">
        <label for="lr-name">{{ t('Name (optional)') }}</label>
        <input id="lr-name" ref="nameInput" v-model="f.name" class="input" :placeholder="t('Log cleanup')" maxlength="255" />
      </div>
      <div class="field">
        <label for="lr-prefix">{{ t('Prefix') }}</label>
        <input id="lr-prefix" v-model="f.prefix" class="input mono" :placeholder="t('logs/ (empty = all)')" spellcheck="false" />
      </div>
    </div>

    <div class="actions">
      <label class="action">
        <input v-model="f.expire" type="checkbox" class="cb" />
        <div class="grow">
          <div class="t-body-lg">{{ t('Expire objects') }}</div>
          <div class="t-body-sm">{{ versioned ? t('Adds a delete marker; older versions stay until removed') : t('Deletes objects older than') }}</div>
        </div>
        <div class="days"><input v-model="f.expireDays" class="input" inputmode="numeric" :disabled="!f.expire" /><span>{{ t('days') }}</span></div>
      </label>
      <label class="action">
        <input v-model="f.noncurrent" type="checkbox" class="cb" />
        <div class="grow" :class="{ dim: !versioned }">
          <div class="t-body-lg">{{ t('Delete old versions') }}</div>
          <div class="t-body-sm">{{ versioned ? t('Removes versions this long after they were replaced') : t('Only relevant for versioned buckets') }}</div>
        </div>
        <div class="days"><input v-model="f.noncurrentDays" class="input" inputmode="numeric" :disabled="!f.noncurrent" /><span>{{ t('days') }}</span></div>
      </label>
      <label class="action">
        <input v-model="f.abort" type="checkbox" class="cb" />
        <div class="grow">
          <div class="t-body-lg">{{ t('Abort incomplete uploads') }}</div>
          <div class="t-body-sm">{{ t('Frees space held by multipart uploads that never finished') }}</div>
        </div>
        <div class="days"><input v-model="f.abortDays" class="input" inputmode="numeric" :disabled="!f.abort" /><span>{{ t('days') }}</span></div>
      </label>
      <label class="action">
        <input v-model="f.markers" type="checkbox" class="cb" />
        <div class="grow" :class="{ dim: !versioned }">
          <div class="t-body-lg">{{ t('Remove orphan delete markers') }}</div>
          <div class="t-body-sm">{{ t('Delete markers with no versions left behind them') }}</div>
        </div>
      </label>
    </div>

    <div class="enabled">
      <span class="grow t-label-lg">{{ t('Rule enabled') }}</span>
      <Toggle v-model="f.enabled" />
    </div>

    <Callout v-if="error" tone="danger">{{ error }}</Callout>

    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit"><Loader2 v-if="busy" :size="15" class="spin" />{{ existing ? t('Save') : t('Add rule') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.two { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 12px; }
.actions { display: flex; flex-direction: column; gap: 2px; }
.action { display: flex; align-items: center; gap: 12px; padding: 6px 0; cursor: pointer; }
.cb { accent-color: var(--primary); width: 16px; height: 16px; margin: 0; flex-shrink: 0; }
.dim { opacity: 0.6; }
.days { display: flex; align-items: center; gap: 6px; width: 120px; flex-shrink: 0; font-size: 12.5px; color: var(--muted); }
.days .input { width: 70px; text-align: right; }
.enabled { display: flex; align-items: center; gap: 12px; padding-top: 4px; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
