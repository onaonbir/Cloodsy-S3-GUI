<script setup lang="ts">
// Warning colour above 75 %, danger above 90 % (2.0).
import { computed } from 'vue';
const props = defineProps<{ value: number; height?: number }>();
const pct = computed(() => Math.max(0, Math.min(1, props.value || 0)));
const tone = computed(() => (pct.value > 0.9 ? 'var(--danger)' : pct.value > 0.75 ? 'var(--warning)' : 'var(--primary)'));
</script>

<template>
  <div class="bar" :style="{ height: `${height ?? 6}px` }">
    <div class="fill" :style="{ width: `${pct * 100}%`, background: tone }" />
  </div>
</template>

<style scoped>
.bar { width: 100%; background: var(--hover); border-radius: 999px; overflow: hidden; border: 1px solid var(--border); }
.fill { height: 100%; border-radius: 999px; transition: width var(--normal); }
</style>
