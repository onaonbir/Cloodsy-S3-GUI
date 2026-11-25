<script setup lang="ts">
// A page centred up to `max` px wide (2.0 PageScaffold); `fill` makes it
// exactly as tall as the content area (the activity log scrolls inside).
defineProps<{ max?: number; fill?: boolean }>();
</script>

<template>
  <div class="page srv-page" :class="{ fill }" :style="{ maxWidth: `calc(${max ?? 1240}px + 2 * var(--page))` }"><slot /></div>
</template>

<style scoped>
.srv-page { width: 100%; margin: 0 auto; }
.srv-page.fill { height: 100%; min-height: 0; padding-bottom: 24px; }
@media (max-width: 600px) {
  .srv-page { padding-left: var(--space-lg); padding-right: var(--space-lg); }
}
</style>
