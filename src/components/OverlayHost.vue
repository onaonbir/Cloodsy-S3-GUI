<script setup lang="ts">
import { overlays } from '@/lib/overlay';
</script>

<template>
  <component :is="o.component" v-for="o in overlays" :key="o.id" v-bind="o.props" />
</template>
