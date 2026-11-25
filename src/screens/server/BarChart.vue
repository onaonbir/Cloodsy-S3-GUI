<script setup lang="ts">
// Single-series column chart for a short time series (one value per minute;
// 2.0 MiniBarChart). Thin columns with a 2 px gap and rounded tops, a base
// line, first / peak / last labels underneath and a tooltip per column. The
// panel title names the series, so there is no legend.
import { computed, ref } from 'vue';
import { t } from '@/lib/i18n';

const props = defineProps<{
  values: number[];
  /** Tooltip label per column (e.g. "14:05"). */
  labels: string[];
  format: (v: number) => string;
  height?: number;
}>();

const hover = ref<number | null>(null);
const plot = ref<HTMLElement | null>(null);
const max = computed(() => props.values.reduce((m, v) => (v > m ? v : m), 0));
const h = computed(() => props.height ?? 120);

/** Column height in px (the top 4 px stay free, like 2.0). */
const barHeight = (v: number) => (max.value > 0 && v > 0 ? Math.max(1, (v / max.value) * (h.value - 5)) : 0);

function onMove(e: MouseEvent) {
  const el = plot.value;
  const n = props.values.length;
  if (!el || !n) return;
  const r = el.getBoundingClientRect();
  const i = Math.floor(((e.clientX - r.left) / r.width) * n);
  hover.value = i >= 0 && i < n ? i : null;
}

const tip = computed(() => {
  const i = hover.value;
  const el = plot.value;
  if (i === null || !el || i >= props.values.length) return null;
  const w = el.clientWidth;
  const slot = w / props.values.length;
  const left = Math.min(Math.max(0, slot * i + slot / 2 - 70), Math.max(0, w - 140));
  return { left, value: props.format(props.values[i]), label: props.labels[i] ?? '' };
});
</script>

<template>
  <div class="chart">
    <div
      ref="plot" class="plot" :style="{ height: `${h}px` }" role="img" :aria-label="t('peak {v}', { v: format(max) })"
      @mousemove="onMove" @mouseleave="hover = null"
    >
      <div v-for="(v, i) in values" :key="i" class="slot">
        <div class="bar" :class="{ dim: hover !== null && hover !== i }" :style="{ height: `${barHeight(v)}px` }" />
      </div>
      <div v-if="tip" class="tip" :style="{ left: `${tip.left}px` }">
        <div class="tv">{{ tip.value }}</div>
        <div class="tl">{{ tip.label }}</div>
      </div>
    </div>
    <div class="axis t-body-sm">
      <span>{{ labels[0] ?? '' }}</span>
      <span>{{ t('peak {v}', { v: format(max) }) }}</span>
      <span>{{ labels.length ? labels[labels.length - 1] : '' }}</span>
    </div>
  </div>
</template>

<style scoped>
.chart { display: flex; flex-direction: column; gap: 6px; }
.plot { position: relative; display: flex; align-items: flex-end; border-bottom: 1px solid var(--border); }
.slot { flex: 1; min-width: 0; height: 100%; display: flex; align-items: flex-end; justify-content: center; }
.bar { width: clamp(1px, calc(100% - 2px), 18px); background: var(--primary); border-radius: 3px 3px 0 0; transition: opacity var(--fast); }
.bar.dim { opacity: 0.45; }
.tip { position: absolute; top: -6px; width: 140px; padding: 6px 10px; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-md); box-shadow: 0 3px 10px rgba(0, 0, 0, 0.13); pointer-events: none; z-index: 2; }
.tv { font-size: 13px; font-weight: 600; color: var(--foreground); }
.tl { font-size: 12px; color: var(--subtle); }
.axis { display: flex; justify-content: space-between; gap: 8px; }
</style>
