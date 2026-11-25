<script setup lang="ts">
// Loading / empty / error states in one component: `kind` picks which.
import { Loader2, WifiOff, AlertCircle, Inbox } from 'lucide-vue-next';
import { t } from '@/lib/i18n';

defineProps<{ kind: 'loading' | 'empty' | 'error'; title?: string; message?: string; connection?: boolean; compact?: boolean }>();
defineEmits<{ retry: [] }>();
</script>

<template>
  <div class="state" :class="{ compact }">
    <Loader2 v-if="kind === 'loading'" class="spin" :size="22" />
    <template v-else>
      <div class="icon" :class="kind">
        <WifiOff v-if="kind === 'error' && connection" :size="22" />
        <AlertCircle v-else-if="kind === 'error'" :size="22" />
        <slot v-else name="icon"><Inbox :size="22" /></slot>
      </div>
      <div class="title">{{ title ?? (kind === 'error' ? t('Something went wrong') : t('Nothing here yet')) }}</div>
      <div v-if="message" class="message selectable">{{ message }}</div>
      <div class="actions">
        <slot name="actions" />
        <button v-if="kind === 'error'" class="btn" @click="$emit('retry')">{{ t('Try again') }}</button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.state { display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 8px; padding: 56px 24px; color: var(--muted); }
.state.compact { padding: 28px 16px; }
.icon { width: 48px; height: 48px; border-radius: 14px; display: grid; place-items: center; background: var(--hover); color: var(--muted); margin-bottom: 4px; }
.icon.error { background: var(--danger-soft); color: var(--danger); }
.title { font-weight: 600; font-size: 15px; color: var(--foreground); }
.message { font-size: 13px; max-width: 460px; line-height: 1.45; }
.actions { display: flex; gap: 8px; margin-top: 8px; }
.actions:empty { display: none; }
.spin { animation: spin 0.9s linear infinite; color: var(--primary); }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
