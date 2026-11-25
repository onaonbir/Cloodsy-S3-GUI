<script setup lang="ts">
export interface TabItem { id: string; label: string; badge?: number | string | null }
defineProps<{ tabs: TabItem[]; modelValue: string }>();
defineEmits<{ 'update:modelValue': [id: string] }>();
</script>

<template>
  <div class="tabs" role="tablist">
    <button v-for="tab in tabs" :key="tab.id" role="tab" class="tab" :class="{ active: tab.id === modelValue }" :aria-selected="tab.id === modelValue" @click="$emit('update:modelValue', tab.id)">
      {{ tab.label }}<span v-if="tab.badge !== undefined && tab.badge !== null && tab.badge !== 0" class="badge">{{ tab.badge }}</span>
    </button>
  </div>
</template>

<style scoped>
.tabs { display: flex; gap: 2px; border-bottom: 1px solid var(--border); overflow-x: auto; overflow-y: hidden; scrollbar-width: none; }
.tabs::-webkit-scrollbar { display: none; }
.tab { position: relative; display: inline-flex; align-items: center; gap: 6px; height: 38px; padding: 0 12px; border: 0; background: none; color: var(--muted); font: 600 13px var(--font-sans); cursor: pointer; white-space: nowrap; }
.tab:hover { color: var(--foreground); }
.tab.active { color: var(--foreground); }
.tab.active::after { content: ''; position: absolute; left: 8px; right: 8px; bottom: -1px; height: 2px; border-radius: 2px; background: var(--primary); }
.badge { min-width: 18px; height: 18px; padding: 0 5px; border-radius: 999px; background: var(--hover); border: 1px solid var(--border); font-size: 11px; display: inline-grid; place-items: center; color: var(--muted); }
</style>
