<script setup lang="ts">
// A rounded square with an icon (2.0 IconBadge).
import type { Component } from 'vue';
defineProps<{ icon: Component; tone?: 'neutral' | 'primary'; size?: number }>();
</script>

<template>
  <div class="badge" :class="tone ?? 'primary'" :style="{ width: `${size ?? 34}px`, height: `${size ?? 34}px` }">
    <component :is="icon" :size="Math.round((size ?? 34) * 0.47)" />
  </div>
</template>

<style scoped>
.badge { border-radius: var(--radius-md); display: grid; place-items: center; flex-shrink: 0; }
.primary { background: var(--primary-soft); color: var(--primary); }
.neutral { background: var(--hover); color: var(--muted); border: 1px solid var(--border); }
</style>
