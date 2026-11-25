<script setup lang="ts">
// A titled card (2.0 Panel): icon, title, subtitle, actions on the right.
import type { Component } from 'vue';
defineProps<{ title?: string; subtitle?: string; icon?: Component; flush?: boolean }>();
</script>

<template>
  <section class="card panel">
    <header v-if="title || $slots.actions" class="ph">
      <component :is="icon" v-if="icon" :size="16" class="ic" />
      <div class="grow">
        <div class="t-title-sm ellipsis">{{ title }}</div>
        <div v-if="subtitle" class="t-body-sm">{{ subtitle }}</div>
      </div>
      <div v-if="$slots.actions" class="acts"><slot name="actions" /></div>
    </header>
    <div class="pb" :class="{ flush }"><slot /></div>
  </section>
</template>

<style scoped>
.panel { display: flex; flex-direction: column; min-width: 0; }
.ph { display: flex; align-items: center; gap: 8px; padding: 14px 12px 0 18px; min-height: 32px; }
.ic { color: var(--muted); align-self: flex-start; margin-top: 1px; }
.acts { display: flex; align-items: center; gap: 4px; }
.pb { padding: 18px; min-width: 0; }
.pb.flush { padding: 8px 0 0; }
</style>
