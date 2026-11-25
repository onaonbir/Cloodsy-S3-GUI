<script setup lang="ts" generic="T extends string | number | boolean">
// A two-or-more way switch (2.0 SegmentedButton).
import type { Component } from 'vue';

defineProps<{ modelValue: T; options: { value: T; label: string; icon?: Component; disabled?: boolean }[] }>();
defineEmits<{ 'update:modelValue': [v: T] }>();
</script>

<template>
  <div class="seg" role="radiogroup">
    <button
      v-for="o in options"
      :key="String(o.value)"
      type="button"
      role="radio"
      :aria-checked="o.value === modelValue"
      :class="{ on: o.value === modelValue }"
      :disabled="o.disabled"
      @click="$emit('update:modelValue', o.value)"
    >
      <component :is="o.icon" v-if="o.icon" :size="14" />{{ o.label }}
    </button>
  </div>
</template>

<style scoped>
.seg { display: inline-flex; border: 1px solid var(--border); border-radius: var(--radius-md); overflow: hidden; background: var(--card); align-self: flex-start; }
button { display: inline-flex; align-items: center; gap: 6px; height: 32px; padding: 0 14px; border: 0; background: none; color: var(--muted); font: 600 12.5px var(--font-sans); cursor: pointer; }
button + button { border-left: 1px solid var(--border); }
button:hover:not(:disabled):not(.on) { background: var(--hover); color: var(--foreground); }
button.on { background: var(--selected); color: var(--primary); }
button:disabled { opacity: 0.45; cursor: default; }
</style>
