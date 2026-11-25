<script setup lang="ts">
// Page title, subtitle and actions (right, wrapping on narrow windows).
defineProps<{ title: string; subtitle?: string }>();
</script>

<template>
  <header class="page-header head">
    <div class="title">
      <h1 class="ellipsis">{{ title }}</h1>
      <p v-if="subtitle" class="t-body sub">{{ subtitle }}</p>
    </div>
    <div v-if="$slots.default" class="actions"><slot /></div>
  </header>
</template>

<style scoped>
.head { align-items: flex-end; justify-content: space-between; }
.title { flex: 1 1 260px; min-width: 0; }
.sub { margin-top: 4px; }
.actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
</style>
