<script setup lang="ts">
// A titled card (2.0 Panel): icon, title, optional subtitle and actions.
import type { Component } from 'vue';
defineProps<{ title?: string; subtitle?: string; icon?: Component; flush?: boolean }>();
</script>

<template>
  <section class="panel card">
    <header v-if="title || $slots.actions" class="head">
      <component :is="icon" v-if="icon" :size="16" class="icon" />
      <div class="grow">
        <h3 v-if="title" class="t-title-sm">{{ title }}</h3>
        <p v-if="subtitle" class="t-body-sm sub">{{ subtitle }}</p>
      </div>
      <div class="actions"><slot name="actions" /></div>
    </header>
    <div class="body" :class="{ flush }"><slot /></div>
  </section>
</template>

<style scoped>
.panel { display: flex; flex-direction: column; min-width: 0; }
.head { display: flex; align-items: center; gap: 10px; padding: 14px 16px 0 18px; min-height: 44px; }
.icon { color: var(--muted); }
.sub { margin-top: 2px; }
.actions { display: flex; align-items: center; gap: 4px; }
.actions:empty { display: none; }
.body { padding: 14px 18px 18px; min-width: 0; }
.body.flush { padding: 6px 6px 8px; }
</style>
