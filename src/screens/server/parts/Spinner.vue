<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next';
defineProps<{ size?: number }>();
</script>

<template>
  <Loader2 class="spinner" :size="size ?? 15" />
</template>

<style scoped>
.spinner { animation: spinner-turn 0.9s linear infinite; }
@keyframes spinner-turn { to { transform: rotate(360deg); } }
</style>
