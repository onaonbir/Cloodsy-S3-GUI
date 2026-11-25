<script setup lang="ts">
// The bucket's access keys as cards (2.0 access_tab.dart): create → the
// key and secret once more in a result dialog; revoke with the key shown.
import { KeyRound, Plus, Trash2 } from 'lucide-vue-next';
import CopyValue from '@/components/ui/CopyValue.vue';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import IconBadge from '../buckets/IconBadge.vue';
import CreateCredentialDialog from './dialogs/CreateCredentialDialog.vue';
import CredentialResultDialog from './dialogs/CredentialResultDialog.vue';
import { useBucket } from '../buckets/bucketStore';
import type { Credential } from '@/lib/api';
import { confirm } from '@/lib/dialogs';
import { openDialog } from '@/lib/overlay';
import { formatDate, formatDateTime } from '@/lib/format';
import { t } from '@/lib/i18n';
import { runAction } from '@/stores/toasts';

const store = useBucket();
const s = store.state;

async function create() {
  const cred = await openDialog<Credential>(CreateCredentialDialog, { bucket: s.name, create: store.createCredential });
  if (cred) await openDialog(CredentialResultDialog, { credential: cred });
}

async function revoke(c: Credential) {
  const ok = await confirm({
    title: t('Revoke access key'),
    message: t('Clients using this key lose access immediately.'),
    detail: c.access_key,
    confirmLabel: t('Revoke'),
    danger: true,
  });
  if (ok) await runAction(() => store.deleteCredential(c.access_key), t('Access key revoked'));
}

const readOnly = (c: Credential) => c.permission === 'read-only';
</script>

<template>
  <div class="tab">
    <div class="intro">
      <p class="t-body grow">{{ t('Access keys authenticate S3 clients (SigV4) and WebDAV mounts for this bucket only.') }}</p>
      <button class="btn primary" @click="create"><Plus :size="16" />{{ t('New access key') }}</button>
    </div>

    <div v-if="!s.credentials.length" class="card">
      <States kind="empty" compact :title="t('No access keys')" :message="t('Create a key to connect an S3 SDK, rclone or the Cloodsy app to this bucket.')">
        <template #icon><KeyRound :size="22" /></template>
        <template #actions><button class="btn primary" @click="create"><Plus :size="16" />{{ t('Create access key') }}</button></template>
      </States>
    </div>

    <div v-for="c in s.credentials" :key="c.access_key" class="card cred">
      <div class="head">
        <IconBadge :icon="KeyRound" :tone="readOnly(c) ? 'neutral' : 'primary'" :size="34" />
        <div class="grow">
          <div class="t-title-sm ellipsis">{{ c.name || t('Unnamed key') }}</div>
          <div class="t-body-sm" :title="formatDateTime(c.created_at)">{{ t('Created {d}', { d: formatDate(c.created_at) }) }}</div>
        </div>
        <Pill :tone="readOnly(c) ? 'neutral' : 'primary'">{{ readOnly(c) ? t('Read only') : t('Read & write') }}</Pill>
        <button class="btn ghost icon sm danger" :title="t('Revoke key')" @click="revoke(c)"><Trash2 :size="15" /></button>
      </div>
      <div class="keys">
        <div class="field">
          <label>{{ t('Access key') }}</label>
          <CopyValue :value="c.access_key" :label="t('Access key')" />
        </div>
        <div class="field">
          <label>{{ t('Secret key') }}</label>
          <CopyValue :value="c.secret_key ?? ''" :label="t('Secret key')" secret />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tab { display: flex; flex-direction: column; gap: 12px; container-type: inline-size; }
.intro { display: flex; align-items: center; gap: 12px; margin-bottom: 4px; }
.cred { padding: 16px 16px 18px 18px; display: flex; flex-direction: column; gap: 16px; }
.head { display: flex; align-items: center; gap: 12px; }
.keys { display: grid; grid-template-columns: 1fr; gap: 12px; }
@container (min-width: 620px) {
  .keys { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 14px; }
}
</style>
