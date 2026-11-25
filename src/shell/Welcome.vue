<script setup lang="ts">
// Signed out: the saved servers with a reachability probe (any HTTP answer
// from /admin/status = online), click to connect.
import { onMounted, reactive } from 'vue';
import { Lock, LockOpen, Pencil, Plus, Trash2, Loader2 } from 'lucide-vue-next';
import BrandMark from '@/components/BrandMark.vue';
import Callout from '@/components/ui/Callout.vue';
import Pill from '@/components/ui/Pill.vue';
import { servers, removeServer, hostOf } from '@/stores/servers';
import { connect, connecting, sessionError } from '@/stores/session';
import { openServerDialog } from './serverDialog';
import { confirm } from '@/lib/dialogs';
import { ipc, type Server } from '@/lib/ipc';
import { t } from '@/lib/i18n';

const probes = reactive<Record<string, { ms?: number; down?: boolean }>>({});

function probe(s: Server) {
  probes[s.id] = {};
  ipc.probe(s.url).then((ms) => (probes[s.id] = { ms })).catch(() => (probes[s.id] = { down: true }));
}
onMounted(() => servers.value.forEach(probe));

async function open(s: Server) {
  if (connecting.value) return;
  try {
    await connect(s.id);
  } catch (e) {
    sessionError.value = (e as Error).message;
  }
}

async function add() {
  const s = await openServerDialog(null);
  if (s) {
    probe(s);
    await open(s);
  }
}

async function edit(s: Server) {
  const saved = await openServerDialog(s);
  if (saved) probe(saved);
}

async function remove(s: Server) {
  if (await confirm({ title: t('Remove server'), message: t('Remove {name} and its saved password from this computer?', { name: s.name }), confirmLabel: t('Remove'), danger: true })) {
    await removeServer(s.id);
  }
}
</script>

<template>
  <div class="welcome">
    <div class="box">
      <BrandMark :size="56" />
      <h1>{{ t('Cloodsy S3') }}</h1>
      <p class="t-body">{{ t('Manage your Cloodsy S3 servers: buckets, files, keys and server tools.') }}</p>

      <Callout v-if="sessionError" tone="danger" dismissable class="err" @dismiss="sessionError = null">{{ sessionError }}</Callout>

      <div v-if="!servers.length" class="empty">
        <button class="btn primary" @click="add"><Plus :size="15" />{{ t('Add server') }}</button>
      </div>
      <div v-else class="list">
        <div v-for="s in servers" :key="s.id" class="srv" role="button" @click="open(s)">
          <div class="lock"><Lock v-if="s.url.startsWith('https')" :size="15" /><LockOpen v-else :size="15" /></div>
          <div class="grow">
            <div class="row"><span class="name ellipsis">{{ s.name }}</span>
              <Pill v-if="probes[s.id]?.ms !== undefined" tone="success" dot>{{ t('Online · {ms} ms', { ms: probes[s.id].ms! }) }}</Pill>
              <Pill v-else-if="probes[s.id]?.down" tone="danger" dot>{{ t('Unreachable') }}</Pill>
            </div>
            <div class="sub ellipsis">{{ hostOf(s.url) }} · {{ s.username }}</div>
          </div>
          <Loader2 v-if="connecting === s.id" :size="18" class="spin" />
          <div v-else class="acts">
            <button class="btn ghost icon sm" :title="t('Edit')" @click.stop="edit(s)"><Pencil :size="14" /></button>
            <button class="btn ghost icon sm" :title="t('Remove')" @click.stop="remove(s)"><Trash2 :size="14" /></button>
          </div>
        </div>
        <button class="btn ghost add" @click="add"><Plus :size="15" />{{ t('Add another server') }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.welcome { flex: 1; display: grid; place-items: center; overflow-y: auto; padding: 32px; }
.box { width: 480px; max-width: 100%; display: flex; flex-direction: column; align-items: center; gap: 10px; text-align: center; }
h1 { font-size: 24px; font-weight: 700; letter-spacing: -0.4px; margin-top: 6px; }
.err { width: 100%; text-align: left; margin-top: 8px; }
.empty { margin-top: 18px; }
.list { width: 100%; display: flex; flex-direction: column; gap: 8px; margin-top: 18px; }
.srv { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--card); cursor: pointer; text-align: left; }
.srv:hover { border-color: var(--border-strong); background: var(--card-hover); }
.lock { width: 34px; height: 34px; border-radius: var(--radius-md); background: var(--primary-soft); color: var(--primary); display: grid; place-items: center; flex-shrink: 0; }
.name { font-weight: 600; font-size: 14px; }
.sub { font-size: 12px; color: var(--muted); margin-top: 2px; }
.acts { display: flex; gap: 2px; opacity: 0; transition: opacity var(--fast); }
.srv:hover .acts { opacity: 1; }
.add { align-self: center; }
.spin { animation: spin 0.9s linear infinite; color: var(--primary); }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
