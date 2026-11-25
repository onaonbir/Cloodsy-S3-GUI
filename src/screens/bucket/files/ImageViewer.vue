<script setup lang="ts">
// Full-window image viewer: wheel or buttons zoom (up to 8×) around the
// cursor, drag pans, double-click toggles 1× / 2×, Esc closes.
// (2.0 object_panel.dart _openImageFull, InteractiveViewer maxScale 8)
import { computed, ref } from 'vue';
import { Minimize2, X, ZoomIn, ZoomOut } from 'lucide-vue-next';
import { t } from '@/lib/i18n';
import { useTopmostEsc } from './overlay';

defineProps<{ src: string; name: string }>();
const emit = defineEmits<{ close: [] }>();

const MAX = 8;
const root = ref<HTMLElement | null>(null);
const stage = ref<HTMLElement | null>(null);
const scale = ref(1);
const tx = ref(0);
const ty = ref(0);
const dragging = ref(false);
let last: { x: number; y: number } | null = null;

useTopmostEsc(root, () => emit('close'));

const transform = computed(() => `translate(${tx.value}px, ${ty.value}px) scale(${scale.value})`);

/** Zooms to `next`, keeping the stage point (px, py) still. */
function zoomTo(next: number, px?: number, py?: number) {
  const s = Math.min(MAX, Math.max(1, next));
  const r = stage.value?.getBoundingClientRect();
  if (!r) return;
  const cx = r.width / 2;
  const cy = (r.height - 24) / 2; // the stage's bottom padding
  const x = px ?? cx;
  const y = py ?? cy;
  // Image point under the cursor, relative to the centre, before zooming.
  const ux = (x - cx - tx.value) / scale.value;
  const uy = (y - cy - ty.value) / scale.value;
  scale.value = s;
  if (s === 1) {
    tx.value = 0;
    ty.value = 0;
  } else {
    tx.value = x - cx - s * ux;
    ty.value = y - cy - s * uy;
  }
}

function onWheel(e: WheelEvent) {
  const r = stage.value!.getBoundingClientRect();
  zoomTo(scale.value * Math.exp(-e.deltaY * 0.0015), e.clientX - r.left, e.clientY - r.top);
}

function onDown(e: MouseEvent) {
  if (e.button !== 0 || scale.value === 1) return;
  dragging.value = true;
  last = { x: e.clientX, y: e.clientY };
}
function onMove(e: MouseEvent) {
  if (!dragging.value || !last) return;
  tx.value += e.clientX - last.x;
  ty.value += e.clientY - last.y;
  last = { x: e.clientX, y: e.clientY };
}
function onUp() {
  dragging.value = false;
  last = null;
}
function onDouble(e: MouseEvent) {
  const r = stage.value!.getBoundingClientRect();
  zoomTo(scale.value > 1 ? 1 : 2, e.clientX - r.left, e.clientY - r.top);
}
</script>

<template>
  <Teleport to="body">
    <div ref="root" class="viewer" role="dialog" aria-modal="true" @mousemove="onMove" @mouseup="onUp" @mouseleave="onUp">
      <div class="bar">
        <span class="name ellipsis">{{ name }}</span>
        <span class="zoom">{{ Math.round(scale * 100) }}%</span>
        <button class="tool" :title="t('Zoom out')" :disabled="scale <= 1" @click="zoomTo(scale / 1.5)"><ZoomOut :size="17" /></button>
        <button class="tool" :title="t('Zoom in')" :disabled="scale >= 8" @click="zoomTo(scale * 1.5)"><ZoomIn :size="17" /></button>
        <button class="tool" :title="t('Fit to window')" :disabled="scale === 1" @click="zoomTo(1)"><Minimize2 :size="17" /></button>
        <button class="tool" :title="t('Close (Esc)')" @click="emit('close')"><X :size="18" /></button>
      </div>
      <div
        ref="stage"
        class="stage"
        :class="{ zoomed: scale > 1, dragging }"
        @wheel.prevent="onWheel"
        @mousedown.prevent="onDown"
        @dblclick="onDouble"
        @click.self="scale === 1 && emit('close')"
      >
        <img :src="src" :alt="name" draggable="false" :style="{ transform }" />
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
/* Always dark, like 2.0 (black backdrop) in both themes. */
.viewer { position: fixed; inset: 0; z-index: 150; background: rgba(0, 0, 0, 0.92); display: flex; flex-direction: column; animation: fade var(--fast); }
.bar { display: flex; align-items: center; gap: 4px; height: 48px; padding: 0 8px 0 18px; color: #f2efe8; flex-shrink: 0; }
.name { flex: 1; font-weight: 600; font-size: 13.5px; }
.zoom { font-size: 12px; opacity: 0.7; margin-right: 6px; font-variant-numeric: tabular-nums; }
.tool { width: 34px; height: 34px; display: grid; place-items: center; border: 0; border-radius: var(--radius-md); background: transparent; color: inherit; cursor: pointer; }
.tool:hover:not(:disabled) { background: rgba(255, 255, 255, 0.12); }
.tool:disabled { opacity: 0.35; cursor: default; }
.stage { flex: 1; min-height: 0; display: grid; place-items: center; overflow: hidden; padding: 0 24px 24px; cursor: zoom-in; }
.stage.zoomed { cursor: grab; }
.stage.dragging { cursor: grabbing; }
img { max-width: 100%; max-height: 100%; object-fit: contain; transform-origin: center center; user-select: none; transition: transform 60ms linear; }
.dragging img { transition: none; }
@keyframes fade { from { opacity: 0; } }
</style>
