<script setup lang="ts" generic="T extends string">
// A segmented button (2.0 SegmentedButton): one of a few options.
import type { Component } from 'vue';
defineProps<{ modelValue: T; options: { value: T; label: string; icon?: Component }[]; disabled?: boolean }>();
defineEmits<{ 'update:modelValue': [v: T] }>();
</script>

<template>
  <div class="seg" role="radiogroup">
    <button
      v-for="o in options" :key="o.value" type="button" role="radio" class="opt"
      :class="{ on: o.value === modelValue }" :aria-checked="o.value === modelValue" :disabled="disabled"
      @click="$emit('update:modelValue', o.value)"
    >
      <component :is="o.icon" v-if="o.icon" :size="14" />{{ o.label }}
    </button>
  </div>
</template>

<style scoped>
.seg { display: inline-flex; border: 1px solid var(--border); border-radius: var(--radius-md); overflow: hidden; background: var(--card); flex-shrink: 0; }
.opt { display: inline-flex; align-items: center; gap: 6px; height: 34px; padding: 0 14px; border: 0; background: none; color: var(--muted); font: 600 13px var(--font-sans); cursor: pointer; white-space: nowrap; }
.opt + .opt { border-left: 1px solid var(--border); }
.opt:hover:not(:disabled) { background: var(--hover); color: var(--foreground); }
.opt.on { background: var(--primary-soft); color: var(--primary); }
.opt:disabled { opacity: 0.5; cursor: default; }
</style>
