<script setup lang="ts">
// "Label   value" (2.0 InfoRow): fixed label column, value in the slot or
// `value` (optionally monospace).
defineProps<{ label: string; value?: string; mono?: boolean; labelWidth?: number }>();
</script>

<template>
  <div class="info-row">
    <div class="label" :style="{ width: `${labelWidth ?? 130}px` }">{{ label }}</div>
    <div class="value selectable">
      <slot><span :class="mono ? 'mono' : 'text'">{{ value }}</span></slot>
    </div>
  </div>
</template>

<style scoped>
.info-row { display: flex; align-items: flex-start; gap: 8px; padding: 7px 0; }
.label { flex-shrink: 0; font-size: 13px; line-height: 1.45; color: var(--muted); }
.value { flex: 1; min-width: 0; overflow-wrap: anywhere; line-height: 1.45; }
.text { font-size: 14px; }
.mono { color: var(--foreground); }
</style>
