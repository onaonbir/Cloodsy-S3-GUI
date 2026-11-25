<script setup lang="ts">
// The app's licence and the bundled fonts' SIL Open Font Licences.
import { computed, ref } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Tabs from '@/components/ui/Tabs.vue';
import { t } from '@/lib/i18n';
import appLicence from '../../../LICENSE?raw';
import jakartaLicence from '../../../assets/fonts/OFL-PlusJakartaSans.txt?raw';
import monoLicence from '../../../assets/fonts/OFL-JetBrainsMono.txt?raw';

defineProps<{ done: (v: null) => void }>();

const tab = ref('app');
const items = computed(() => [
  { id: 'app', label: t('Cloodsy S3 GUI'), text: appLicence, note: t('This app') },
  { id: 'jakarta', label: 'Plus Jakarta Sans', text: jakartaLicence, note: t('Interface font · SIL Open Font License 1.1') },
  { id: 'mono', label: 'JetBrains Mono', text: monoLicence, note: t('Monospace font · SIL Open Font License 1.1') },
]);
const current = computed(() => items.value.find((i) => i.id === tab.value) ?? items.value[0]);
</script>

<template>
  <Modal :title="t('Licenses')" :width="680" fill @close="done(null)">
    <Tabs v-model="tab" :tabs="items.map(({ id, label }) => ({ id, label }))" />
    <div class="t-body-sm">{{ current.note }}</div>
    <pre class="text mono selectable">{{ current.text.trim() }}</pre>
    <template #footer>
      <button class="btn primary" @click="done(null)">{{ t('Close') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.text { flex: 1; min-height: 0; margin: 0; overflow: auto; padding: 14px 16px; background: var(--hover); border: 1px solid var(--border); border-radius: var(--radius-md); white-space: pre-wrap; overflow-wrap: anywhere; font-size: 12px; line-height: 1.55; color: var(--foreground); }
</style>
