<script setup lang="ts">
// "Label   value" in the details panels; `value` or the default slot.
defineProps<{ label: string; value?: string; mono?: boolean }>();
</script>

<template>
  <div class="info-row">
    <div class="label">{{ label }}</div>
    <div class="value selectable" :class="{ mono }"><slot>{{ value }}</slot></div>
  </div>
</template>

<style scoped>
.info-row { display: flex; align-items: flex-start; gap: 12px; padding: 7px 0; font-size: 13px; }
.info-row + .info-row { border-top: 1px solid var(--border); }
.label { width: 130px; flex-shrink: 0; color: var(--muted); padding-top: 1px; }
.value { flex: 1; min-width: 0; word-break: break-word; display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
</style>
