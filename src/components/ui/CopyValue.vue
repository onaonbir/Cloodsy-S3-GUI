<script setup lang="ts">
// A value with a copy button ("{label} copied"); `secret` hides it behind a
// reveal toggle.
import { ref } from 'vue';
import { Copy, Eye, EyeOff } from 'lucide-vue-next';
import { copyText } from '@/stores/toasts';
import { t } from '@/lib/i18n';

const props = defineProps<{ value: string; label?: string; secret?: boolean; mono?: boolean }>();
const shown = ref(!props.secret);
</script>

<template>
  <div class="copy-value">
    <span class="v ellipsis selectable" :class="{ mono: mono !== false }" :title="shown ? value : ''">{{ shown ? value : '•'.repeat(Math.min(32, value.length || 8)) }}</span>
    <button v-if="secret" class="btn ghost icon sm" :title="shown ? t('Hide') : t('Show')" @click="shown = !shown">
      <EyeOff v-if="shown" :size="14" /><Eye v-else :size="14" />
    </button>
    <button class="btn ghost icon sm" :title="t('Copy')" @click="copyText(value, props.label)"><Copy :size="14" /></button>
  </div>
</template>

<style scoped>
.copy-value { display: flex; align-items: center; gap: 2px; min-width: 0; background: var(--hover); border: 1px solid var(--border); border-radius: var(--radius-md); padding: 2px 2px 2px 10px; }
.v { flex: 1; font-size: 12.5px; }
</style>
