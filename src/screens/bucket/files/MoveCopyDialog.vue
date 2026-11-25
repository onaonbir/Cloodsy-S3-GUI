<script setup lang="ts">
// Move / copy / rename an object, a folder or a selection, on the server.
// `run` does the work and answers the success message; errors stay in the
// dialog. (2.0 object_dialogs.dart _MoveCopyDialog)
import { computed, nextTick, onMounted, ref } from 'vue';
import { Copy, FolderInput } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import Segmented from './Segmented.vue';
import { t } from '@/lib/i18n';
import { toast } from '@/stores/toasts';
import { fileName, moveCopyError, moveCopyTarget, sourceParent, splitExt, type MoveCopyError, type MoveCopyInput } from './helpers';

const props = defineProps<{
  bucket: string;
  /** Object key, folder prefix, or for a selection the open folder (default destination). */
  sourceKey: string;
  isFolder: boolean;
  renameOnly?: boolean;
  /** Moving a selection of this many objects. */
  count?: number;
  buckets: string[];
  run: (destBucket: string, dest: string, move: boolean) => Promise<string>;
  done: (v: boolean | null) => void;
}>();

const move = ref(true);
const destBucket = ref(props.bucket);
const dest = ref(props.renameOnly ? fileName(props.sourceKey) : props.sourceKey);
const busy = ref(false);
const error = ref<string | null>(null);
const input = ref<HTMLInputElement | null>(null);

const parent = computed(() => sourceParent(props.sourceKey, props.isFolder));
const bucketChoices = computed(() => (props.buckets.includes(props.bucket) ? props.buckets : [props.bucket, ...props.buckets]));

const title = computed(() => {
  if (props.count !== undefined) return move.value ? t('Move {n} objects', { n: props.count }) : t('Copy {n} objects', { n: props.count });
  if (props.renameOnly) return props.isFolder ? t('Rename folder') : t('Rename object');
  if (props.isFolder) return move.value ? t('Move folder') : t('Copy folder');
  return move.value ? t('Move object') : t('Copy object');
});
const subtitle = computed(() => {
  if (props.count !== undefined) return t('Copied on the server; nothing is downloaded.');
  if (props.isFolder) return t('Every object under “{p}” is processed on the server.', { p: props.sourceKey });
  return null;
});
const label = computed(() => {
  if (props.renameOnly) return t('New name');
  if (props.isFolder || props.count !== undefined) return t('Destination folder (empty = bucket root)');
  return t('Destination key');
});

function message(e: Exclude<MoveCopyError, null>): string {
  switch (e) {
    case 'leading-slash': return t('Enter a destination key without a leading “/”');
    case 'other-folder': return t('Pick a different folder or bucket');
    case 'slash-in-name': return t('A name can’t contain “/”');
    case 'same': return t('Destination is the same as the source');
    case 'into-itself': return t('Can’t move a folder into itself');
  }
}

async function submit() {
  if (busy.value) return;
  const req: MoveCopyInput = {
    bucket: props.bucket, sourceKey: props.sourceKey, isFolder: props.isFolder, renameOnly: !!props.renameOnly,
    count: props.count, destBucket: destBucket.value, dest: dest.value,
  };
  const bad = moveCopyError(req);
  if (bad) {
    error.value = message(bad);
    return;
  }
  busy.value = true;
  error.value = null;
  try {
    const msg = await props.run(destBucket.value, moveCopyTarget(req), props.renameOnly ? true : move.value);
    toast(msg);
    props.done(true);
  } catch (e) {
    busy.value = false;
    error.value = (e as Error).message;
  }
}

onMounted(async () => {
  await nextTick();
  const el = input.value;
  if (!el) return;
  el.focus();
  // Rename: select the name without its extension, like a file manager.
  if (props.renameOnly && !props.isFolder) el.setSelectionRange(0, splitExt(dest.value)[0].length);
  else el.select();
});
</script>

<template>
  <Modal :width="520" @close="!busy && done(null)">
    <template #header>
      <div class="head grow">
        <h2>{{ title }}</h2>
        <div v-if="subtitle" class="sub">{{ subtitle }}</div>
      </div>
    </template>

    <template v-if="!renameOnly">
      <Segmented
        v-model="move"
        :options="[
          { value: true, label: t('Move'), icon: FolderInput },
          { value: false, label: t('Copy'), icon: Copy },
        ]"
      />
      <div class="field">
        <label>{{ t('Destination bucket') }}</label>
        <select v-model="destBucket" class="input">
          <option v-for="b in bucketChoices" :key="b" :value="b">{{ b }}</option>
        </select>
      </div>
    </template>

    <div class="field">
      <label>{{ label }}</label>
      <div class="dest" :class="{ prefixed: renameOnly && parent }">
        <span v-if="renameOnly && parent" class="parent mono ellipsis" :title="parent">{{ parent }}</span>
        <input ref="input" v-model="dest" class="input mono" spellcheck="false" :disabled="busy" @keydown.enter="submit" />
      </div>
    </div>

    <Callout v-if="error" tone="danger">{{ error }}</Callout>

    <template #footer>
      <button class="btn" :disabled="busy" @click="done(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="busy" @click="submit">
        <span v-if="busy" class="spinner" />
        {{ renameOnly ? t('Rename') : move ? t('Move') : t('Copy') }}
      </button>
    </template>
  </Modal>
</template>

<style scoped>
.head { min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.sub { color: var(--muted); font-size: 12.5px; margin-top: 3px; user-select: text; }
.dest { display: flex; align-items: stretch; }
.prefixed .input { border-top-left-radius: 0; border-bottom-left-radius: 0; }
.parent { display: flex; align-items: center; max-width: 50%; padding: 0 10px; border: 1px solid var(--border); border-right: 0; border-radius: var(--radius-md) 0 0 var(--radius-md); background: var(--hover); color: var(--muted); }
.spinner { width: 13px; height: 13px; border-radius: 50%; border: 2px solid currentColor; border-right-color: transparent; animation: spin 0.8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
