<script setup lang="ts">
defineProps<{ tone?: 'neutral' | 'primary' | 'success' | 'warning' | 'danger'; dot?: boolean }>();
</script>

<template>
  <span class="pill" :class="tone ?? 'neutral'"><span v-if="dot" class="dot" /><slot /></span>
</template>

<style scoped>
.pill { display: inline-flex; align-items: center; gap: 5px; height: 20px; padding: 0 8px; border-radius: 999px; font-size: 11px; font-weight: 600; white-space: nowrap; }
.dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
.neutral { background: var(--hover); color: var(--muted); border: 1px solid var(--border); }
.primary { background: var(--primary-soft); color: var(--primary); }
.success { background: var(--success-soft); color: var(--success); }
.warning { background: var(--warning-soft); color: var(--warning); }
.danger { background: var(--danger-soft); color: var(--danger); }
</style>
