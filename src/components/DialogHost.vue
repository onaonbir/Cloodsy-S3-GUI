<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import Modal from './ui/Modal.vue';
import { pending, settle } from '@/lib/dialogs';
import { t } from '@/lib/i18n';

const text = ref('');
const input = ref<HTMLInputElement | null>(null);

watch(pending, async (p) => {
  text.value = p?.kind === 'prompt' ? (p.opts.initial ?? '') : '';
  await nextTick();
  input.value?.focus();
  input.value?.select();
});

const promptError = computed(() => {
  const p = pending.value;
  return p?.kind === 'prompt' && p.opts.validate ? p.opts.validate(text.value) : null;
});
const canConfirm = computed(() => {
  const p = pending.value;
  if (!p) return false;
  if (p.kind === 'confirm') return !p.opts.typeToConfirm || text.value.trim() === p.opts.typeToConfirm;
  return text.value.trim() !== '' && !promptError.value;
});

function ok() {
  const p = pending.value;
  if (!p || !canConfirm.value) return;
  settle(p.kind === 'confirm' ? true : text.value.trim());
}
</script>

<template>
  <Modal v-if="pending" :title="pending.opts.title" :width="440" @close="settle(pending.kind === 'confirm' ? false : null)">
    <template v-if="pending.kind === 'confirm'">
      <p v-if="pending.opts.message" class="t-body-lg msg">{{ pending.opts.message }}</p>
      <div v-if="pending.opts.detail" class="detail mono selectable">{{ pending.opts.detail }}</div>
      <div v-if="pending.opts.typeToConfirm" class="field">
        <label>{{ t('Type {name} to confirm', { name: pending.opts.typeToConfirm }) }}</label>
        <input ref="input" v-model="text" class="input mono" spellcheck="false" @keydown.enter="ok" />
      </div>
    </template>
    <template v-else>
      <div class="field">
        <label v-if="pending.opts.label">{{ pending.opts.label }}</label>
        <input ref="input" v-model="text" class="input" :class="{ invalid: text && promptError }" :placeholder="pending.opts.placeholder" spellcheck="false" @keydown.enter="ok" />
        <span v-if="text && promptError" class="error">{{ promptError }}</span>
        <span v-else-if="pending.opts.hint" class="hint">{{ pending.opts.hint }}</span>
      </div>
    </template>
    <template #footer>
      <button class="btn" @click="settle(pending.kind === 'confirm' ? false : null)">{{ t('Cancel') }}</button>
      <button class="btn" :class="pending.kind === 'confirm' && pending.opts.danger ? 'danger solid' : 'primary'" :disabled="!canConfirm" @click="ok">
        {{ pending.opts.confirmLabel ?? (pending.kind === 'confirm' ? t('Confirm') : t('Save')) }}
      </button>
    </template>
  </Modal>
</template>

<style scoped>
.msg { color: var(--muted); user-select: text; }
.detail { padding: 8px 10px; background: var(--hover); border: 1px solid var(--border); border-radius: var(--radius-md); word-break: break-all; }
</style>
