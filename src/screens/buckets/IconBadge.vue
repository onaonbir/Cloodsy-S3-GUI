<script setup lang="ts">
// A tinted square with an icon (2.0 IconBadge).
import type { Component } from 'vue';
withDefaults(defineProps<{ icon: Component; tone?: 'primary' | 'success' | 'warning' | 'danger' | 'neutral'; size?: number }>(), { tone: 'primary', size: 32 });
</script>

<template>
  <div class="badge" :class="tone" :style="{ width: `${size}px`, height: `${size}px` }">
    <component :is="icon" :size="Math.round(size * 0.5)" />
  </div>
</template>

<style scoped>
.badge { display: grid; place-items: center; border-radius: var(--radius-md); flex-shrink: 0; }
.primary { background: var(--primary-soft); color: var(--primary); }
.success { background: var(--success-soft); color: var(--success); }
.warning { background: var(--warning-soft); color: var(--warning); }
.danger { background: var(--danger-soft); color: var(--danger); }
.neutral { background: var(--hover); color: var(--muted); }
</style>
