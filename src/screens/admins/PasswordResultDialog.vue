<script setup lang="ts">
// The password the server returned, shown once with copy buttons.
import { CheckCircle2 } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import CopyValue from '@/components/ui/CopyValue.vue';
import { t } from '@/lib/i18n';
import type { PasswordResult } from './passwords';

defineProps<{ result: PasswordResult; done: (v: null) => void }>();
</script>

<template>
  <Modal :width="440" @close="done(null)">
    <template #header>
      <div class="head">
        <div class="ic"><CheckCircle2 :size="17" /></div>
        <h2 class="grow">{{ result.generated ? t('Password generated') : t('Password set') }}</h2>
      </div>
    </template>
    <Callout v-if="result.generated" tone="warning">{{ t('Copy this password now. It will not be shown again.') }}</Callout>
    <div class="field">
      <label>{{ t('Username') }}</label>
      <CopyValue :value="result.username" :label="t('Username')" />
    </div>
    <div class="field">
      <label>{{ t('Password') }}</label>
      <CopyValue :value="result.password" :label="t('Password')" :secret="!result.generated" />
    </div>
    <template #footer>
      <button class="btn primary" @click="done(null)">{{ t('Done') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { flex: 1; display: flex; align-items: center; gap: 12px; min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.ic { width: 34px; height: 34px; border-radius: var(--radius-md); background: var(--success-soft); color: var(--success); display: grid; place-items: center; flex-shrink: 0; }
</style>
