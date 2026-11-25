<script setup lang="ts">
// A link to one object: an expiring SigV4 link signed locally with one of the
// bucket's access keys (path-style), or the plain URL of a public-read bucket.
// (2.0 object_dialogs.dart _ShareDialog)
import { computed, onMounted, ref, watch } from 'vue';
import { Copy, ExternalLink, Globe, Timer } from 'lucide-vue-next';
import { openUrl } from '@tauri-apps/plugin-opener';
import Modal from '@/components/ui/Modal.vue';
import Callout from '@/components/ui/Callout.vue';
import States from '@/components/ui/States.vue';
import Segmented from './Segmented.vue';
import { ipc } from '@/lib/ipc';
import type { Credential } from '@/lib/api';
import { t } from '@/lib/i18n';
import { server, status, useApi } from '@/stores/session';
import { copyText, toastError } from '@/stores/toasts';
import { isShareImage, objectUrl, s3Endpoint, validEndpoint } from './helpers';

const props = defineProps<{ bucket: string; objectKey: string; done: (v: null) => void }>();

const EXPIRIES = [
  { secs: 15 * 60, label: () => t('15 min') },
  { secs: 3600, label: () => t('1 hour') },
  { secs: 86400, label: () => t('1 day') },
  { secs: 7 * 86400, label: () => t('7 days') }, // SigV4 maximum
];

const loading = ref(true);
const loadError = ref<string | null>(null);
const publicRead = ref(false);
const creds = ref<Credential[]>([]);
const signed = ref(true);
const credKey = ref('');
const expiry = ref(3600);
const endpoint = ref(s3Endpoint(server.value?.s3_url, server.value?.url, status.value?.s3) ?? '');
const region = computed(() => status.value?.s3?.region || 'us-east-1');
const w = ref('');
const h = ref('');
const q = ref('');
const link = ref<string | null>(null);
const linkError = ref<string | null>(null);

const usable = computed(() => creds.value.filter((c) => (c.secret_key ?? '') !== ''));
const cred = computed(() => usable.value.find((c) => c.access_key === credKey.value) ?? null);
const readOnly = (c: Credential) => c.permission === 'read-only';
const isImage = computed(() => isShareImage(props.objectKey));

async function load() {
  loading.value = true;
  loadError.value = null;
  try {
    const api = useApi();
    const [b, c] = await Promise.all([api.bucket(props.bucket), api.credentials(props.bucket)]);
    publicRead.value = b.public_read;
    creds.value = c;
    signed.value = !b.public_read;
    // Prefer a read-only key: a leaked link then can't be used to write.
    const pick = usable.value.find(readOnly) ?? usable.value[0];
    credKey.value = pick?.access_key ?? '';
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const digits = (s: string) => s.replace(/\D/g, '');
const imageQuery = computed<[string, string][]>(() => {
  if (!isImage.value) return [];
  const out: [string, string][] = [];
  if (digits(w.value)) out.push(['w', digits(w.value)]);
  if (digits(h.value)) out.push(['h', digits(h.value)]);
  if (digits(q.value)) out.push(['q', digits(q.value)]);
  return out;
});

let seq = 0;
async function build() {
  const my = ++seq;
  linkError.value = null;
  const ep = endpoint.value.trim();
  if (!validEndpoint(ep)) {
    link.value = null;
    return;
  }
  if (!signed.value) {
    link.value = objectUrl(ep, props.bucket, props.objectKey, imageQuery.value);
    return;
  }
  const c = cred.value;
  if (!c) {
    link.value = null;
    return;
  }
  try {
    const url = await ipc.presign({
      endpoint: ep, bucket: props.bucket, key: props.objectKey, accessKey: c.access_key, secretKey: c.secret_key,
      region: region.value, expiresSecs: expiry.value, extraQuery: imageQuery.value,
    });
    if (my === seq) link.value = url;
  } catch (e) {
    if (my === seq) {
      link.value = null;
      linkError.value = (e as Error).message;
    }
  }
}
watch([endpoint, signed, credKey, expiry, imageQuery, loading], () => void build(), { immediate: true });

// Resize fields take digits only.
for (const r of [w, h, q]) watch(r, (v) => { if (digits(v) !== v) r.value = digits(v); });

function openLink() {
  if (link.value) openUrl(link.value).catch(toastError);
}
</script>

<template>
  <Modal :width="560" @close="done(null)">
    <template #header>
      <div class="head grow">
        <h2>{{ t('Share link') }}</h2>
        <div class="sub mono ellipsis selectable" :title="objectKey">{{ objectKey }}</div>
      </div>
    </template>

    <States v-if="loading" kind="loading" compact />
    <States v-else-if="loadError" kind="error" compact :message="loadError" @retry="load" />
    <template v-else>
      <div class="col tight">
        <Segmented
          v-model="signed"
          :options="[
            { value: true, label: t('Expiring link'), icon: Timer },
            { value: false, label: t('Public URL'), icon: Globe, disabled: !publicRead },
          ]"
        />
        <span v-if="!publicRead" class="t-body-sm">{{ t('Public URLs need “Public read” on the bucket.') }}</span>
      </div>

      <template v-if="signed">
        <Callout v-if="usable.length === 0" tone="warning">
          {{ t('This bucket has no access key yet. Create one under “Access keys” to sign links.') }}
        </Callout>
        <template v-else>
          <div class="row top">
            <div class="field grow">
              <label>{{ t('Sign with key') }}</label>
              <select v-model="credKey" class="input">
                <option v-for="c in usable" :key="c.access_key" :value="c.access_key">
                  {{ c.name || c.access_key }}{{ readOnly(c) ? ` · ${t('read only')}` : '' }}
                </option>
              </select>
            </div>
            <div class="field expiry">
              <label>{{ t('Expires in') }}</label>
              <select v-model.number="expiry" class="input">
                <option v-for="x in EXPIRIES" :key="x.secs" :value="x.secs">{{ x.label() }}</option>
              </select>
            </div>
          </div>
          <Callout v-if="cred && !readOnly(cred)" tone="info">
            {{ t('Signed with a read & write key. The link only allows downloading this object, but a read-only key is safer.') }}
          </Callout>
        </template>
      </template>

      <div class="field">
        <label>{{ t('S3 endpoint') }}</label>
        <input v-model="endpoint" class="input mono" spellcheck="false" placeholder="https://s3.example.com" />
        <span class="hint">{{ t('The address clients use to reach the S3 API') }}</span>
      </div>

      <div v-if="isImage" class="field">
        <label>{{ t('Image resize (optional)') }}</label>
        <div class="row">
          <input class="input" inputmode="numeric" v-model="w" :placeholder="t('Width')" />
          <input class="input" inputmode="numeric" v-model="h" :placeholder="t('Height')" />
          <input class="input" inputmode="numeric" v-model="q" :placeholder="t('Quality')" />
        </div>
      </div>

      <div v-if="link" class="field">
        <label>{{ t('Link') }}</label>
        <div class="link">
          <div class="url mono selectable">{{ link }}</div>
          <div class="link-actions">
            <button class="btn sm" @click="copyText(link, t('Link'))"><Copy :size="14" />{{ t('Copy') }}</button>
            <button class="btn ghost sm" @click="openLink"><ExternalLink :size="14" />{{ t('Open in browser') }}</button>
          </div>
        </div>
      </div>
      <Callout v-else-if="linkError" tone="danger">{{ linkError }}</Callout>
      <Callout v-else-if="!validEndpoint(endpoint)" tone="info">{{ t('Enter a valid S3 endpoint to build the link.') }}</Callout>
    </template>

    <template #footer>
      <button class="btn primary" @click="done(null)">{{ t('Done') }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { min-width: 0; }
.head h2 { font-size: 16px; font-weight: 700; letter-spacing: -0.2px; }
.sub { color: var(--muted); font-size: 12px; margin-top: 2px; }
.tight { gap: 6px; }
.top { align-items: flex-start; gap: 12px; }
.expiry { width: 150px; flex-shrink: 0; }
.link { border: 1px solid var(--border); border-radius: var(--radius-md); background: var(--hover); overflow: hidden; }
.url { padding: 10px 12px; word-break: break-all; font-size: 12px; line-height: 1.5; max-height: 110px; overflow: auto; }
.link-actions { display: flex; gap: 6px; padding: 6px 8px; border-top: 1px solid var(--border); background: var(--card); }
</style>
