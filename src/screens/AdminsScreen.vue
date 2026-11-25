<script setup lang="ts">
// Admin users: everyone who can sign in to the Admin API. Add, reset or
// change a password (shown once), delete (type the name; never yourself).
import { computed, onMounted, ref } from 'vue';
import { KeyRound, RefreshCw, Trash2, UserPlus } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import Page from './server/parts/Page.vue';
import PageHead from './server/parts/PageHead.vue';
import Spinner from './server/parts/Spinner.vue';
import AdminPasswordDialog from './admins/AdminPasswordDialog.vue';
import PasswordResultDialog from './admins/PasswordResultDialog.vue';
import type { PasswordResult } from './admins/passwords';
import { ownPasswordChanged, sessionInfo, useApi } from '@/stores/session';
import { runAction, toastError } from '@/stores/toasts';
import { openDialog } from '@/lib/overlay';
import { confirm } from '@/lib/dialogs';
import { formatDate } from '@/lib/format';
import { t } from '@/lib/i18n';
import type { Admin } from '@/lib/api';
import type { ApiError } from '@/lib/ipc';

const admins = ref<Admin[]>([]);
const loaded = ref(false);
const loading = ref(false);
const error = ref<ApiError | null>(null);
const me = computed(() => sessionInfo.value?.username ?? '');

async function load() {
  loading.value = true;
  try {
    admins.value = (await useApi().admins()).sort((a, b) => (a.username < b.username ? -1 : a.username > b.username ? 1 : 0));
    error.value = null;
  } catch (e) {
    error.value = e as ApiError;
  } finally {
    loading.value = false;
    loaded.value = true;
  }
}
onMounted(load);

const showResult = (r: PasswordResult) => openDialog(PasswordResultDialog, { result: r });

async function add() {
  const r = await openDialog<PasswordResult>(AdminPasswordDialog, {});
  if (!r) return;
  void load();
  await showResult(r);
}

async function reset(a: Admin) {
  const own = a.username === me.value;
  const r = await openDialog<PasswordResult>(AdminPasswordDialog, { username: a.username, own });
  if (!r) return;
  if (own) {
    // The server just ended our own session too: sign in again with the new
    // password (and keep it in the keychain) instead of being thrown out.
    try {
      await ownPasswordChanged(r.password);
    } catch (e) {
      toastError(e);
    }
  }
  await showResult(r);
}

async function remove(a: Admin) {
  const ok = await confirm({
    title: t('Delete admin'),
    message: t('Delete “{u}”? Their active sessions end immediately.', { u: a.username }),
    typeToConfirm: a.username,
    confirmLabel: t('Delete'),
    danger: true,
  });
  if (!ok) return;
  const done = await runAction(() => useApi().deleteAdmin(a.username).then(() => true), t('Admin “{u}” deleted', { u: a.username }));
  if (done) await load();
}

const initial = (u: string) => (u ? [...u][0].toUpperCase() : '?');
</script>

<template>
  <Page :max="900">
    <PageHead :title="t('Admin users')" :subtitle="t('Accounts that can sign in to this server’s Admin API.')">
      <button class="btn ghost icon" :title="t('Refresh')" :disabled="loading" @click="load">
        <Spinner v-if="loading" /><RefreshCw v-else :size="16" />
      </button>
      <button class="btn primary" @click="add"><UserPlus :size="16" />{{ t('Add admin') }}</button>
    </PageHead>

    <States v-if="!loaded" kind="loading" />
    <States v-else-if="error && !admins.length" kind="error" :message="error.message" :connection="error.isConnectionError" @retry="load" />
    <div v-else class="card list">
      <div v-for="a in admins" :key="a.id" class="admin">
        <div class="avatar" :class="{ me: a.username === me }">{{ initial(a.username) }}</div>
        <div class="grow">
          <div class="row name-row">
            <span class="t-title-sm ellipsis selectable">{{ a.username }}</span>
            <Pill v-if="a.username === me" tone="primary">{{ t('You') }}</Pill>
          </div>
          <div class="t-body-sm">{{ t('Added {d}', { d: formatDate(a.created_at) }) }}</div>
        </div>
        <button class="btn" @click="reset(a)">
          <KeyRound :size="15" />{{ a.username === me ? t('Change password') : t('Reset password') }}
        </button>
        <!-- the tooltip sits on a wrapper: a disabled button gets no hover -->
        <span :title="a.username === me ? t('You can’t delete your own account') : t('Delete')">
          <button class="btn ghost icon del" :disabled="a.username === me" @click="remove(a)"><Trash2 :size="16" /></button>
        </span>
      </div>
    </div>
  </Page>
</template>

<style scoped>
.list { overflow: hidden; }
.admin { display: flex; align-items: center; gap: 12px; padding: 12px 10px 12px 16px; }
.admin + .admin { border-top: 1px solid var(--border); }
.avatar { width: 34px; height: 34px; border-radius: 50%; display: grid; place-items: center; flex-shrink: 0; background: var(--hover); color: var(--muted); font-weight: 600; font-size: 13px; }
.avatar.me { background: var(--primary-soft); color: var(--primary); }
.name-row { gap: 8px; }
.del { color: var(--danger); }
.del:disabled { color: var(--subtle); }
@media (max-width: 560px) {
  .admin { flex-wrap: wrap; }
}
</style>
