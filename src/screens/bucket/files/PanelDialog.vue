<script setup lang="ts">
// Narrow windows (< 1180 px): the object panel in a 460×640 dialog.
// Its own scrim instead of <Modal>, so Esc closes only the topmost layer
// (the panel opens share, rename, … dialogs and viewers above itself).
import { ref } from 'vue';
import ObjectPanel from './ObjectPanel.vue';
import type { S3Object } from '@/lib/api';
import type { ObjectActions } from './types';
import { useTopmostEsc } from './overlay';

defineProps<{ bucket: string; object: S3Object; actions: ObjectActions }>();
const emit = defineEmits<{ close: [] }>();

const root = ref<HTMLElement | null>(null);
useTopmostEsc(root, () => emit('close'));
</script>

<template>
  <Teleport to="body">
    <div ref="root" class="scrim" @mousedown.self="emit('close')">
      <div class="box" role="dialog" aria-modal="true">
        <ObjectPanel :bucket="bucket" :object="object" :actions="actions" @close="emit('close')" />
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.scrim { position: fixed; inset: 0; background: var(--scrim); display: grid; place-items: center; z-index: 100; padding: 20px; animation: fade var(--fast); }
.box { width: 460px; height: 640px; max-width: 100%; max-height: 100%; border-radius: var(--radius-xl); box-shadow: var(--shadow); animation: pop var(--normal) ease-out; }
.box :deep(.panel) { border-radius: var(--radius-xl); }
@keyframes fade { from { opacity: 0; } }
@keyframes pop { from { opacity: 0; transform: translateY(6px) scale(0.98); } }
</style>
