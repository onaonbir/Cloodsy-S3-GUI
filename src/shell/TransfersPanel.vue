<script setup lang="ts">
import { ArrowDown, ArrowUp, ExternalLink, FolderSearch, RotateCcw, X, Minus } from 'lucide-vue-next';
import { active, cancel, cancelAll, clearFinished, panelOpen, retry, transfers, type Transfer } from '@/stores/transfers';
import { ipc } from '@/lib/ipc';
import { formatBytes } from '@/lib/format';
import { t } from '@/lib/i18n';
import { toastError } from '@/stores/toasts';

function line(x: Transfer): string {
  switch (x.state) {
    case 'waiting': return t('Waiting');
    case 'running': return t('{done} of {total}', { done: formatBytes(x.done), total: formatBytes(x.size) });
    case 'done': return x.kind === 'upload' ? t('Upload finished') : t('Saved');
    case 'cancelled': return t('Cancelled');
    default: return x.error ?? t('Failed');
  }
}
</script>

<template>
  <div v-if="panelOpen && transfers.length" class="panel">
    <header>
      <span class="grow t-title-sm">{{ t('Transfers') }}</span>
      <button v-if="active.length" class="btn ghost sm" @click="cancelAll()">{{ t('Cancel all') }}</button>
      <button v-if="transfers.length > active.length" class="btn ghost sm" @click="clearFinished()">{{ t('Clear') }}</button>
      <button class="btn ghost icon sm" :title="t('Hide')" @click="panelOpen = false"><Minus :size="15" /></button>
    </header>
    <div class="items">
      <div v-for="x in transfers" :key="x.id" class="item">
        <div class="kind" :class="x.state"><ArrowUp v-if="x.kind === 'upload'" :size="14" /><ArrowDown v-else :size="14" /></div>
        <div class="grow">
          <div class="name ellipsis" :title="x.key">{{ x.name }}</div>
          <div class="sub ellipsis" :class="{ 'danger-text': x.state === 'error' }" :title="x.error">{{ line(x) }}</div>
          <div v-if="x.state === 'running'" class="bar"><div class="fill" :style="{ width: `${x.size ? (x.done / x.size) * 100 : 0}%` }" /></div>
        </div>
        <div class="acts">
          <button v-if="x.state === 'waiting' || x.state === 'running'" class="btn ghost icon sm" :title="t('Cancel')" @click="cancel(x.id)"><X :size="14" /></button>
          <button v-if="x.state === 'error' || x.state === 'cancelled'" class="btn ghost sm" @click="retry(x.id)">
            <RotateCcw :size="13" />{{ x.resumeParts ? t('Resume ({n} parts)', { n: x.resumeParts }) : t('Retry') }}
          </button>
          <template v-if="x.state === 'done' && x.kind === 'download'">
            <button class="btn ghost icon sm" :title="t('Open')" @click="ipc.openPath(x.path).catch(toastError)"><ExternalLink :size="14" /></button>
            <button class="btn ghost icon sm" :title="t('Show in folder')" @click="ipc.revealPath(x.path).catch(toastError)"><FolderSearch :size="14" /></button>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.panel { position: fixed; right: 20px; bottom: 20px; width: 380px; max-height: 420px; display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-xl); box-shadow: var(--shadow); z-index: 90; }
header { display: flex; align-items: center; gap: 4px; padding: 10px 10px 10px 16px; border-bottom: 1px solid var(--border); }
.items { overflow-y: auto; padding: 4px 6px 8px; }
.item { display: flex; align-items: center; gap: 10px; padding: 8px; border-radius: var(--radius-md); }
.item:hover { background: var(--hover); }
.kind { width: 28px; height: 28px; border-radius: var(--radius-md); display: grid; place-items: center; background: var(--primary-soft); color: var(--primary); flex-shrink: 0; }
.kind.done { background: var(--success-soft); color: var(--success); }
.kind.error { background: var(--danger-soft); color: var(--danger); }
.kind.cancelled, .kind.waiting { background: var(--hover); color: var(--muted); }
.name { font-size: 13px; font-weight: 600; }
.sub { font-size: 11.5px; color: var(--muted); }
.bar { height: 3px; margin-top: 5px; border-radius: 3px; background: var(--hover); overflow: hidden; }
.fill { height: 100%; background: var(--primary); transition: width var(--normal); }
.acts { display: flex; gap: 2px; }
</style>
