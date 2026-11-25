<script setup lang="ts">
defineProps<{ modelValue: boolean; disabled?: boolean; busy?: boolean }>();
defineEmits<{ 'update:modelValue': [v: boolean] }>();
</script>

<template>
  <button type="button" class="toggle" role="switch" :aria-checked="modelValue" :class="{ on: modelValue, busy }" :disabled="disabled || busy" @click="$emit('update:modelValue', !modelValue)">
    <span class="knob" />
  </button>
</template>

<style scoped>
.toggle { position: relative; width: 36px; height: 20px; border-radius: 999px; border: 1px solid var(--border-strong); background: var(--hover); cursor: pointer; padding: 0; transition: background var(--fast); flex-shrink: 0; }
.toggle.on { background: var(--primary); border-color: var(--primary); }
.toggle:disabled { opacity: 0.5; cursor: default; }
.toggle.busy { opacity: 0.7; }
.knob { position: absolute; top: 2px; left: 2px; width: 14px; height: 14px; border-radius: 50%; background: var(--card); box-shadow: 0 1px 2px rgba(0, 0, 0, 0.25); transition: transform var(--fast); }
.on .knob { transform: translateX(16px); background: var(--on-primary); }
</style>
