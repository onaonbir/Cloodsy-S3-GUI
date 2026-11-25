<script setup lang="ts">
// The v1 lifecycle rule (servers without lifecycle-v2): name, prefix and
// days until objects expire (2.0 access_dialogs.dart _LifecycleDialog).
import { onMounted, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import { parseDays } from '../../buckets/logic';
import { t } from '@/lib/i18n';

const props = defineProps<{
  add: (name: string, prefix: string, days: number) => Promise<void>;
  done: (v: boolean | null) => void;
}>();

const name = ref('');
const prefix = ref('');
const days = ref('30');
const busy = ref(false);
const error = ref<string | null>(null);
const input = ref<HTMLInputElement | null>(null);
onMounted(() => input.value?.focus());

async function submit() {
  if (busy.value) return;
  const d = parseDays(true, days.value);
  if (d === null) {
    error.value = t('Days must be a positive whole number');
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    await props.add(name.value.trim(), prefix.value.trim(), d);
    props.done(true);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="t('Expiration rule')" :width="500" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('Objects older than the given age are deleted automatically.') }}</p>
    <div class="field">
      <label for="er-name">{{ t('Name (optional)') }}</label>
      <input id="er-name" ref="input" v-model="name" class="input" :placeholder="t('e.g. Log cleanup')" maxlength="255" />
    </div>
    <div class="two">
      <div class="field">
        <label for="er-prefix">{{ t('Prefix') }}</label>
        <input id="er-prefix" v-model="prefix" class="input mono" :placeholder="t('logs/')" spellcheck="false" />
        <span class="hint">{{ t('Empty applies to every object') }}</span>
      </div>
      <div class="field">
        <label for="er-days">{{ t('Expire after') }}</label>
        <div class="days"><input id="er-days" v-model="days" class="input" inputmode="numeric" @keydown.enter="submit" /><span>{{ t('days') }}</span></div>
      </div>
    </div>
    <Callout v-if="error" tone="danger">{{ error }}</Callout>
    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit"><Loader2 v-if="busy" :size="15" class="spin" />{{ t('Add rule') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.two { display: grid; grid-template-columns: 3fr 2fr; gap: 12px; }
.days { display: flex; align-items: center; gap: 8px; font-size: 12.5px; color: var(--muted); }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
