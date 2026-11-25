<script setup lang="ts">
// Moves the bucket's data to another directory on the server (long
// operation); empty = the default data directory.
import { onMounted, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import { isAbsolutePath } from '../../buckets/logic';
import { t } from '@/lib/i18n';

const props = defineProps<{ current: string; apply: (dir: string) => Promise<void>; done: (v: boolean | null) => void }>();

const dir = ref(props.current);
const busy = ref(false);
const error = ref<string | null>(null);
const input = ref<HTMLInputElement | null>(null);
onMounted(() => input.value?.focus());

async function save() {
  if (busy.value) return;
  const d = dir.value.trim();
  if (d && !isAbsolutePath(d)) {
    error.value = t('Use an absolute path, e.g. /mnt/ssd/buckets or D:\\data');
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    await props.apply(d);
    props.done(true);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="t('Storage directory')" :width="500" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('Existing objects are moved to the new location. Large buckets can take a while; the bucket is locked meanwhile.') }}</p>
    <div class="field">
      <label for="sd-dir">{{ t('Absolute path on the server') }}</label>
      <input
        id="sd-dir" ref="input" v-model="dir" class="input mono" :placeholder="t('Leave empty for the default directory')" spellcheck="false"
        :disabled="busy" @input="error = null" @keydown.enter="save"
      />
    </div>
    <Callout v-if="error" tone="danger">{{ error }}</Callout>
    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="save">
        <template v-if="busy"><Loader2 :size="15" class="spin" />{{ t('Moving…') }}</template>
        <template v-else>{{ t('Move data') }}</template>
      </button>
    </template>
  </Modal>
</template>

<style scoped>
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
