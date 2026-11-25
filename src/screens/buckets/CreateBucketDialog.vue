<script setup lang="ts">
// Name (3–63, lowercase letters, digits, hyphens) and an optional custom
// storage directory; server errors stay in the dialog. Answers the new name.
import { nextTick, onMounted, ref } from 'vue';
import { Loader2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Toggle from '@/components/ui/Toggle.vue';
import { useApi } from '@/stores/session';
import { validateBucketName, validateStorageDir } from './logic';
import { t } from '@/lib/i18n';

const props = defineProps<{ done: (v: string | null) => void }>();

const name = ref('');
const customDir = ref(false);
const dir = ref('');
const nameError = ref<string | null>(null);
const dirError = ref<string | null>(null);
const serverError = ref<string | null>(null);
const busy = ref(false);
const nameInput = ref<HTMLInputElement | null>(null);
const dirInput = ref<HTMLInputElement | null>(null);

onMounted(() => nameInput.value?.focus());

async function toggleDir(v: boolean) {
  customDir.value = v;
  dirError.value = null;
  if (v) {
    await nextTick();
    dirInput.value?.focus();
  }
}

async function submit() {
  if (busy.value) return;
  const n = name.value.trim();
  nameError.value = validateBucketName(n);
  const d = customDir.value ? dir.value.trim() : '';
  dirError.value = customDir.value ? validateStorageDir(d) : null;
  if (nameError.value || dirError.value) return;
  busy.value = true;
  serverError.value = null;
  try {
    await useApi().createBucket(n, d || undefined);
    props.done(n);
  } catch (e) {
    serverError.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="t('Create bucket')" :width="480" :persistent="busy" @close="done(null)">
    <div class="field">
      <label for="cb-name">{{ t('Bucket name') }}</label>
      <input
        id="cb-name" ref="nameInput" v-model="name" class="input mono" :class="{ invalid: nameError }" :placeholder="t('my-bucket')"
        spellcheck="false" autocomplete="off" maxlength="63" @input="nameError = null" @keydown.enter="submit"
      />
      <span v-if="nameError" class="error">{{ nameError }}</span>
      <span v-else class="hint">{{ t('Lowercase letters, digits and hyphens') }}</span>
    </div>

    <div class="opt">
      <div class="grow">
        <div class="t-label-lg">{{ t('Custom storage directory') }}</div>
        <div class="t-body-sm">{{ t('Store this bucket outside the default data dir') }}</div>
      </div>
      <Toggle :model-value="customDir" :disabled="busy" @update:model-value="toggleDir" />
    </div>

    <div v-if="customDir" class="field">
      <label for="cb-dir">{{ t('Absolute path on the server') }}</label>
      <input
        id="cb-dir" ref="dirInput" v-model="dir" class="input mono" :class="{ invalid: dirError }" placeholder="/mnt/ssd/buckets · D:\data"
        spellcheck="false" autocomplete="off" @input="dirError = null" @keydown.enter="submit"
      />
      <span v-if="dirError" class="error">{{ dirError }}</span>
    </div>

    <Callout v-if="serverError" tone="danger">{{ serverError }}</Callout>

    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit">
        <Loader2 v-if="busy" :size="15" class="spin" />{{ t('Create bucket') }}
      </button>
    </template>
  </Modal>
</template>

<style scoped>
.opt { display: flex; align-items: center; gap: 12px; }
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
