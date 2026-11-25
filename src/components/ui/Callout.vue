<script setup lang="ts">
import { AlertTriangle, CheckCircle2, Info, XCircle, X } from 'lucide-vue-next';
defineProps<{ tone?: 'info' | 'success' | 'warning' | 'danger'; title?: string; dismissable?: boolean }>();
defineEmits<{ dismiss: [] }>();
</script>

<template>
  <div class="callout" :class="tone ?? 'info'">
    <CheckCircle2 v-if="tone === 'success'" :size="17" />
    <AlertTriangle v-else-if="tone === 'warning'" :size="17" />
    <XCircle v-else-if="tone === 'danger'" :size="17" />
    <Info v-else :size="17" />
    <div class="body">
      <div v-if="title" class="title">{{ title }}</div>
      <div class="text"><slot /></div>
    </div>
    <div class="actions"><slot name="actions" /></div>
    <button v-if="dismissable" class="btn ghost icon sm" @click="$emit('dismiss')"><X :size="14" /></button>
  </div>
</template>

<style scoped>
.callout { display: flex; align-items: flex-start; gap: 10px; padding: 12px 14px; border-radius: var(--radius-lg); border: 1px solid transparent; font-size: 13px; line-height: 1.45; }
.callout > svg { margin-top: 1px; }
.body { flex: 1; min-width: 0; }
.title { font-weight: 600; margin-bottom: 2px; color: var(--foreground); }
.text { color: var(--muted); user-select: text; }
.actions { display: flex; gap: 6px; align-self: center; }
.info { background: var(--primary-soft); border-color: color-mix(in srgb, var(--primary) 25%, transparent); color: var(--primary); }
.success { background: var(--success-soft); border-color: color-mix(in srgb, var(--success) 25%, transparent); color: var(--success); }
.warning { background: var(--warning-soft); border-color: color-mix(in srgb, var(--warning) 25%, transparent); color: var(--warning); }
.danger { background: var(--danger-soft); border-color: color-mix(in srgb, var(--danger) 25%, transparent); color: var(--danger); }
</style>
