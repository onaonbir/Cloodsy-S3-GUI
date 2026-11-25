<script setup lang="ts">
// The new key and its secret, with copy buttons.
import { CheckCircle2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import CopyValue from '@/components/ui/CopyValue.vue';
import type { Credential } from '@/lib/api';
import { t } from '@/lib/i18n';

defineProps<{ credential: Credential; done: (v: null) => void }>();
</script>

<template>
  <Modal :width="500" @close="done(null)">
    <template #header>
      <h2 class="head"><CheckCircle2 :size="18" class="success-text" />{{ t('Access key created') }}</h2>
    </template>
    <p class="t-body">{{ t('Use these with any S3 SDK or client. You can view the secret again later from this list.') }}</p>
    <div class="field">
      <label>{{ t('Access key') }}</label>
      <CopyValue :value="credential.access_key" :label="t('Access key')" />
    </div>
    <div class="field">
      <label>{{ t('Secret key') }}</label>
      <CopyValue :value="credential.secret_key ?? ''" :label="t('Secret key')" />
    </div>
    <template #footer>
      <button class="btn primary" @click="done(null)">{{ t('Done') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { flex: 1; display: flex; align-items: center; gap: 8px; font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
</style>
