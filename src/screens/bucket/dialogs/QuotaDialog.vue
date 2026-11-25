<script setup lang="ts">
// Storage quota: a size in MB / GB / TB; "Remove quota" sets 0 (unlimited).
import { onMounted, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Segmented from '../../buckets/Segmented.vue';
import { QUOTA_UNITS, quotaInitial, type QuotaUnit } from '../../buckets/logic';
import { parseSize } from '@/lib/format';
import { t } from '@/lib/i18n';

const props = defineProps<{ current: number; apply: (bytes: number) => Promise<void>; done: (v: boolean | null) => void }>();

const init = quotaInitial(props.current);
const value = ref(init.value);
const unit = ref<QuotaUnit>(init.unit);
const busy = ref(false);
const error = ref<string | null>(null);
const input = ref<HTMLInputElement | null>(null);
const units = QUOTA_UNITS.map((u) => ({ value: u, label: u }));
onMounted(() => {
  input.value?.focus();
  input.value?.select();
});

async function run(bytes: number) {
  busy.value = true;
  error.value = null;
  try {
    await props.apply(bytes);
    props.done(true);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}

function save() {
  if (busy.value) return;
  const bytes = parseSize(value.value, unit.value);
  if (bytes === null || bytes <= 0) {
    error.value = t('Enter a positive size');
    return;
  }
  void run(bytes);
}
</script>

<template>
  <Modal :title="t('Storage quota')" :width="440" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('Uploads that would exceed the quota are rejected.') }}</p>
    <div class="row size">
      <div class="field grow">
        <label for="q-size">{{ t('Size') }}</label>
        <input id="q-size" ref="input" v-model="value" class="input" inputmode="decimal" :class="{ invalid: error }" @input="error = null" @keydown.enter="save" />
      </div>
      <Segmented v-model="unit" :disabled="busy" :options="units" />
    </div>
    <Callout v-if="error" tone="danger">{{ error }}</Callout>
    <template #footer>
      <button v-if="current > 0" class="btn ghost danger remove" :disabled="busy" @click="run(0)">{{ t('Remove quota') }}</button>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="save"><Loader2 v-if="busy" :size="15" class="spin" />{{ t('Save') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.size { align-items: flex-end; gap: 10px; }
.remove { margin-right: auto; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
