<script setup lang="ts">
// A dialog: title, body, footer slot. Esc and the scrim close it unless
// `persistent`. With dialogs stacked, Esc closes only the topmost one.
import { onBeforeUnmount, onMounted } from 'vue';
import { X } from 'lucide-vue-next';
import { t } from '@/lib/i18n';
import { isTopModal, popModal, pushModal } from './modalStack';

const props = defineProps<{ title?: string; width?: number; persistent?: boolean; bodyClass?: string; fill?: boolean }>();
const emit = defineEmits<{ close: [] }>();
const id = pushModal();

function onKey(e: KeyboardEvent) {
  if (e.key !== 'Escape' || !isTopModal(id)) return;
  e.stopImmediatePropagation();
  if (!props.persistent) emit('close');
}
onMounted(() => window.addEventListener('keydown', onKey, true));
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKey, true);
  popModal(id);
});
</script>

<template>
  <Teleport to="body">
    <div class="scrim" @mousedown.self="!persistent && emit('close')">
      <div class="modal" :class="{ fill }" :style="{ width: `${width ?? 460}px` }" role="dialog" aria-modal="true">
        <header v-if="title || $slots.header">
          <slot name="header"><h2>{{ title }}</h2></slot>
          <button v-if="!persistent" class="btn ghost icon sm" :title="t('Close (Esc)')" @click="emit('close')"><X :size="16" /></button>
        </header>
        <div class="body" :class="bodyClass"><slot /></div>
        <footer v-if="$slots.footer"><slot name="footer" /></footer>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.scrim { position: fixed; inset: 0; background: var(--scrim); display: grid; place-items: center; z-index: 100; padding: 24px; animation: fade var(--fast); }
.modal { max-width: 100%; max-height: calc(100vh - 48px); display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-xl); box-shadow: var(--shadow); animation: pop var(--normal) ease-out; }
.modal.fill { height: calc(100vh - 48px); }
header { display: flex; align-items: center; gap: 8px; padding: 16px 16px 4px 20px; }
header h2 { flex: 1; font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.body { padding: 12px 20px 16px; overflow: auto; display: flex; flex-direction: column; gap: 14px; flex: 1; min-height: 0; }
footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 20px 16px; border-top: 1px solid var(--border); }
@keyframes fade { from { opacity: 0; } }
@keyframes pop { from { opacity: 0; transform: translateY(6px) scale(0.98); } }
</style>
