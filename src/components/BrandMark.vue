<script setup lang="ts">
// The Cloodsy mark on its cyan tile: ink cloud, white prompt; the two dots are
// dropped below 24 px where they would only be noise.
defineProps<{ size?: number }>();
</script>

<template>
  <svg :width="size ?? 20" :height="size ?? 20" viewBox="0 0 100 100" aria-hidden="true">
    <rect width="100" height="100" rx="24" fill="#2EC8F0" />
    <g transform="translate(-1 1)">
      <path d="M33 70 H69 A14 14 0 0 0 70.5 42.2 A20 20 0 0 0 32.6 38.6 A15.8 15.8 0 0 0 33 70 Z" fill="none" stroke="#161B29" stroke-width="8" stroke-linejoin="round" />
      <path d="M40 46.5 L46.5 53 L40 59.5" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" />
      <path d="M51.5 59.5 H62.5" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" />
      <template v-if="(size ?? 20) >= 24">
        <circle cx="22" cy="22" r="5" fill="#161B29" />
        <circle cx="80" cy="80" r="6" fill="#161B29" />
      </template>
    </g>
  </svg>
</template>
