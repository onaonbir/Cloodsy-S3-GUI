<script setup lang="ts">
// Content-Type and x-amz-meta-* of one object. (2.0 object_dialogs.dart _MetadataDialog)
import { ref } from 'vue';
import { Plus, X } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import { t } from '@/lib/i18n';
import { metadataFromRows } from './helpers';

const props = defineProps<{
  objectKey: string;
  contentType: string;
  metadata: Record<string, string>;
  versioned: boolean;
  save: (contentType: string, meta: Record<string, string>) => Promise<void>;
  done: (v: boolean | null) => void;
}>();

let nextId = 1;
const type = ref(props.contentType);
const rows = ref(Object.entries(props.metadata ?? {}).map(([key, value]) => ({ id: nextId++, key, value })));
const busy = ref(false);
const error = ref<string | null>(null);

function add() {
  rows.value.push({ id: nextId++, key: '', value: '' });
}

async function submit() {
  if (busy.value) return;
  const r = metadataFromRows(rows.value);
  if ('bad' in r) {
    error.value = t('Metadata keys may only contain letters, digits and “-” ({key})', { key: r.bad });
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    await props.save(type.value.trim(), r.meta);
    props.done(true);
  } catch (e) {
    busy.value = false;
    error.value = (e as Error).message;
  }
}
</script>

<template>
  <Modal :width="560" @close="!busy && done(null)">
    <template #header>
      <div class="head grow">
        <h2>{{ t('Edit metadata') }}</h2>
        <div class="sub mono ellipsis selectable" :title="objectKey">{{ objectKey }}</div>
      </div>
    </template>

    <div class="field">
      <label>{{ t('Content-Type') }}</label>
      <input v-model="type" class="input mono" spellcheck="false" placeholder="application/octet-stream" @keydown.enter="submit" />
    </div>

    <div class="field">
      <label>{{ t('User metadata (x-amz-meta-*)') }}</label>
      <div v-for="(r, i) in rows" :key="r.id" class="meta-row">
        <input v-model="r.key" class="input mono key" spellcheck="false" :placeholder="t('key')" />
        <input v-model="r.value" class="input grow" spellcheck="false" :placeholder="t('value')" @keydown.enter="submit" />
        <button class="btn ghost icon sm" :title="t('Remove')" @click="rows.splice(i, 1)"><X :size="15" /></button>
      </div>
      <button class="btn ghost sm add" @click="add"><Plus :size="15" />{{ t('Add field') }}</button>
    </div>

    <Callout v-if="versioned">{{ t('The bucket is versioned: saving creates a new version of the object with the same content.') }}</Callout>
    <Callout v-if="error" tone="danger">{{ error }}</Callout>

    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit"><span v-if="busy" class="spinner" />{{ t('Save') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.sub { color: var(--muted); font-size: 12px; margin-top: 2px; }
.meta-row { display: flex; align-items: center; gap: 8px; }
.key { width: 36%; flex-shrink: 0; }
.add { align-self: flex-start; }
.spinner { width: 13px; height: 13px; border-radius: 50%; border: 2px solid currentColor; border-right-color: transparent; animation: spin 0.8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
