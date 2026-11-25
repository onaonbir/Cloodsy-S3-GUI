<script setup lang="ts">
import { AlertCircle, CheckCircle2 } from 'lucide-vue-next';
import { toasts } from '@/stores/toasts';
</script>

<template>
  <Teleport to="body">
    <div class="toasts">
      <TransitionGroup name="toast">
        <div v-for="x in toasts" :key="x.id" class="toast" :class="{ error: x.error }">
          <AlertCircle v-if="x.error" :size="16" /><CheckCircle2 v-else :size="16" />
          <span class="selectable">{{ x.text }}</span>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.toasts { position: fixed; left: 50%; bottom: 20px; transform: translateX(-50%); display: flex; flex-direction: column; align-items: center; gap: 8px; z-index: 300; pointer-events: none; }
.toast { display: flex; align-items: center; gap: 8px; max-width: 560px; padding: 10px 14px; border-radius: var(--radius-lg); background: var(--foreground); color: var(--background); font-size: 13px; font-weight: 500; box-shadow: var(--shadow); pointer-events: auto; }
.toast svg { color: var(--success); }
[data-theme='light'] .toast svg { color: #4fd08a; }
.toast.error svg { color: #f2665e; }
.toast-enter-active, .toast-leave-active { transition: all var(--normal); }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateY(8px); }
</style>
