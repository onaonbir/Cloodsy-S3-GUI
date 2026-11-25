<script setup lang="ts">
// A new access key for one bucket: optional label and read-write or
// read-only (2.0 access_dialogs.dart). Answers the created key.
import { onMounted, ref } from 'vue';
import { Eye, Loader2, Pencil } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Segmented from '../../buckets/Segmented.vue';
import type { Credential } from '@/lib/api';
import { t } from '@/lib/i18n';

type Permission = 'read-write' | 'read-only';

const props = defineProps<{
  bucket: string;
  create: (label: string, permission: Permission) => Promise<Credential>;
  done: (v: Credential | null) => void;
}>();

const label = ref('');
const permission = ref<Permission>('read-write');
const busy = ref(false);
const error = ref<string | null>(null);
const input = ref<HTMLInputElement | null>(null);
onMounted(() => input.value?.focus());

const options: { value: Permission; label: string; icon: typeof Eye }[] = [
  { value: 'read-write', label: t('Read & write'), icon: Pencil },
  { value: 'read-only', label: t('Read only'), icon: Eye },
];

async function submit() {
  if (busy.value) return;
  busy.value = true;
  error.value = null;
  try {
    props.done(await props.create(label.value.trim(), permission.value));
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
  }
}
</script>

<template>
  <Modal :title="t('New access key')" :width="460" :persistent="busy" @close="done(null)">
    <p class="t-body">{{ t('Scoped to the bucket “{b}”.', { b: bucket }) }}</p>
    <div class="field">
      <label for="ck-label">{{ t('Label (optional)') }}</label>
      <input id="ck-label" ref="input" v-model="label" class="input" :placeholder="t('e.g. Backend service')" maxlength="255" @keydown.enter="submit" />
    </div>
    <div class="field">
      <label>{{ t('Permission') }}</label>
      <div><Segmented v-model="permission" :disabled="busy" :options="options" /></div>
    </div>
    <Callout v-if="error" tone="danger">{{ error }}</Callout>
    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit"><Loader2 v-if="busy" :size="15" class="spin" />{{ t('Create key') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.spin { animation: spin 0.9s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
