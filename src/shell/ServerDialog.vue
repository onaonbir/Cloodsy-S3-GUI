<script setup lang="ts">
// Add / edit a server: Admin API URL, name (defaults to the host), username,
// password (empty on edit keeps the saved one) and, under Advanced, the public
// S3 endpoint used for share links.
import { computed, ref } from 'vue';
import { ChevronDown, ChevronRight, Eye, EyeOff, KeyRound } from 'lucide-vue-next';
import Modal from '@/components/ui/Modal.vue';
import { closeServerDialog, serverDialog } from './serverDialog';
import { hostnameOf, saveServer, validateServerUrl } from '@/stores/servers';
import { t } from '@/lib/i18n';

const editing = serverDialog.value?.server ?? null;
const url = ref(editing?.url ?? '');
const name = ref(editing?.name ?? '');
const username = ref(editing?.username ?? 'admin');
const password = ref('');
const s3Url = ref(editing?.s3_url ?? '');
const showPw = ref(false);
const advanced = ref(!!editing?.s3_url);
const touched = ref(false);
const saving = ref(false);
const error = ref<string | null>(null);

const urlError = computed(() => {
  const e = validateServerUrl(url.value);
  return e ? t(e) : null;
});
const s3Error = computed(() => (s3Url.value.trim() && validateServerUrl(s3Url.value) ? t(validateServerUrl(s3Url.value)!) : null));
const valid = computed(() => !urlError.value && !s3Error.value && username.value.trim() !== '' && (editing !== null || password.value !== ''));

async function save() {
  touched.value = true;
  if (!valid.value) return;
  saving.value = true;
  error.value = null;
  try {
    const cleanUrl = url.value.trim().replace(/\/+$/, '');
    const saved = await saveServer(
      { id: editing?.id ?? '', name: name.value.trim() || hostnameOf(cleanUrl), url: cleanUrl, username: username.value.trim(), s3_url: s3Url.value.trim().replace(/\/+$/, '') || null },
      password.value || null,
    );
    closeServerDialog(saved);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <Modal :title="editing ? t('Edit server') : t('Add server')" :width="480" @close="closeServerDialog(null)">
    <form class="col form" @submit.prevent="save">
      <div class="field">
        <label>{{ t('Admin API URL') }}</label>
        <input v-model="url" class="input mono" :class="{ invalid: touched && urlError }" placeholder="https://storage.example.com:9001" spellcheck="false" autofocus />
        <span v-if="touched && urlError" class="error">{{ urlError }}</span>
        <span v-else class="hint">{{ t('Include the scheme, e.g. https://host:9001') }}</span>
      </div>
      <div class="field">
        <label>{{ t('Display name') }}</label>
        <input v-model="name" class="input" :placeholder="url ? hostnameOf(url) : t('Optional')" />
      </div>
      <div class="field">
        <label>{{ t('Username') }}</label>
        <input v-model="username" class="input" :class="{ invalid: touched && !username.trim() }" spellcheck="false" autocomplete="username" />
      </div>
      <div class="field">
        <label>{{ t('Password') }}</label>
        <div class="pw">
          <input v-model="password" class="input" :type="showPw ? 'text' : 'password'" :class="{ invalid: touched && !editing && !password }" :placeholder="editing ? t('Leave empty to keep the saved password') : ''" autocomplete="current-password" />
          <button type="button" class="btn ghost icon sm eye" @click="showPw = !showPw"><EyeOff v-if="showPw" :size="15" /><Eye v-else :size="15" /></button>
        </div>
      </div>
      <button type="button" class="adv" @click="advanced = !advanced">
        <ChevronDown v-if="advanced" :size="14" /><ChevronRight v-else :size="14" />{{ t('Advanced') }}
      </button>
      <div v-if="advanced" class="field">
        <label>{{ t('Public S3 endpoint') }}</label>
        <input v-model="s3Url" class="input mono" :class="{ invalid: s3Error }" placeholder="https://s3.example.com" spellcheck="false" />
        <span v-if="s3Error" class="error">{{ s3Error }}</span>
        <span v-else class="hint">{{ t('Used for share links. Leave empty to use the Admin API host and the server\'s S3 port.') }}</span>
      </div>
      <div class="note"><KeyRound :size="14" />{{ t('The password is stored in the system keychain.') }}</div>
      <div v-if="error" class="error">{{ error }}</div>
      <button type="submit" hidden />
    </form>
    <template #footer>
      <button class="btn" @click="closeServerDialog(null)">{{ t('Cancel') }}</button>
      <button class="btn primary" :disabled="saving || (touched && !valid)" @click="save">{{ editing ? t('Save') : t('Add server') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.form { gap: 14px; }
.pw { position: relative; }
.pw .input { padding-right: 40px; }
.eye { position: absolute; right: 4px; top: 4px; }
.adv { display: inline-flex; align-items: center; gap: 4px; align-self: flex-start; border: 0; background: none; color: var(--muted); font: 600 12.5px var(--font-sans); cursor: pointer; padding: 0; }
.note { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--subtle); }
.error { font-size: 12.5px; color: var(--danger); }
</style>
