<script setup lang="ts">
// Live server log: polls /logs every 2 s with since_id and keeps the last
// 3000 lines. Level and search filter on the server (changing them reloads
// the tail). Follows the end until scrolled up; rows are virtualised.
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue';
import { ArrowDown, Copy, Eraser, Pause, Play, ScrollText, Search, X } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import Page from './parts/Page.vue';
import PageHead from './parts/PageHead.vue';
import Segmented from './parts/Segmented.vue';
import { LOG_MAX, appendTail, logLineText, nextSinceId, toLogLine, type LogLine } from './logic';
import { useApi } from '@/stores/session';
import { toast } from '@/stores/toasts';
import { formatTime } from '@/lib/format';
import { t, tn } from '@/lib/i18n';
import type { ApiError } from '@/lib/ipc';

type Level = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
const INTERVAL = 2000;
const ROW = 24;
const PAD = 6;

const entries = shallowRef<LogLine[]>([]);
const level = ref<Level>('DEBUG');
const query = ref('');
const search = ref('');
const paused = ref(false);
const loaded = ref(false);
const error = ref<ApiError | null>(null);
const follow = ref(true);

let sinceId = 0;
/** Bumped by every filter change: answers for an older filter are dropped. */
let gen = 0;
let inflight = -1;
let timer: ReturnType<typeof setInterval> | undefined;
let debounce: ReturnType<typeof setTimeout> | undefined;
let alive = true;

/** `force`: also while paused (a filter change or Try again). */
async function poll(force = false) {
  if (!alive || (paused.value && !force) || inflight === gen) return;
  const my = gen;
  inflight = my;
  try {
    const r = await useApi().logs(sinceId > 0 ? sinceId : undefined, level.value, query.value || undefined);
    if (!alive || my !== gen) return;
    const fresh = (r.entries ?? []).map(toLogLine);
    entries.value = appendTail(entries.value, fresh, LOG_MAX);
    sinceId = nextSinceId(sinceId, r.last_id, fresh);
    error.value = null;
  } catch (e) {
    if (alive && my === gen) error.value = e as ApiError;
  } finally {
    if (my === gen) {
      loaded.value = true;
      inflight = -1;
    }
  }
}

function resetTail() {
  gen++;
  inflight = -1;
  sinceId = 0;
  entries.value = [];
  loaded.value = false;
  follow.value = true;
  void poll(true);
}

watch(level, resetTail);
watch(search, (v) => {
  clearTimeout(debounce);
  debounce = setTimeout(() => {
    const q = v.trim();
    if (q !== query.value) {
      query.value = q;
      resetTail();
    }
  }, 400);
});

function setPaused(p: boolean) {
  paused.value = p;
  if (!p) void poll();
}

function clearView() {
  entries.value = [];
}

/** Every line in the view, as text ("{n} lines copied" rather than copyText's "Copied"). */
async function copyLines() {
  const lines = entries.value;
  if (!lines.length) return;
  try {
    await navigator.clipboard.writeText(lines.map(logLineText).join('\n'));
    toast(tn(lines.length, '{n} line copied', '{n} lines copied'));
  } catch {
    toast(t('Could not copy'), true);
  }
}

// ---- virtualised list ------------------------------------------------------
const scroller = ref<HTMLElement | null>(null);
const scrollTop = ref(0);
const viewHeight = ref(600);
let ro: ResizeObserver | undefined;

const range = computed(() => {
  const n = entries.value.length;
  const start = Math.max(0, Math.floor((scrollTop.value - PAD) / ROW) - 20);
  const end = Math.min(n, Math.ceil((scrollTop.value + viewHeight.value) / ROW) + 20);
  return { start, end };
});
const visible = computed(() => entries.value.slice(range.value.start, range.value.end));

function onScroll() {
  const el = scroller.value;
  if (!el) return;
  scrollTop.value = el.scrollTop;
  const atEnd = el.scrollTop + el.clientHeight >= el.scrollHeight - 24;
  if (atEnd !== follow.value) follow.value = atEnd;
}

function toEnd() {
  const el = scroller.value;
  if (!el) return;
  el.scrollTop = el.scrollHeight;
  scrollTop.value = el.scrollTop;
}

function followNow() {
  follow.value = true;
  toEnd();
}

watch(entries, async () => {
  if (!follow.value) return;
  await nextTick();
  toEnd();
});

watch(scroller, (el, old) => {
  if (old) ro?.unobserve(old);
  if (el) {
    ro?.observe(el);
    viewHeight.value = el.clientHeight;
    if (follow.value) toEnd();
  }
});

onMounted(() => {
  ro = new ResizeObserver(() => {
    if (scroller.value) viewHeight.value = scroller.value.clientHeight;
  });
  if (scroller.value) ro.observe(scroller.value);
  void poll();
  timer = setInterval(() => void poll(), INTERVAL);
});

onBeforeUnmount(() => {
  alive = false;
  clearInterval(timer);
  clearTimeout(debounce);
  ro?.disconnect();
});

const levelClass = (l: string) => (l === 'ERROR' ? 'error' : l === 'WARN' || l === 'WARNING' ? 'warn' : l === 'DEBUG' ? 'debug' : 'info');
const levels = computed(() => [
  { value: 'DEBUG' as Level, label: t('All') },
  { value: 'INFO' as Level, label: t('Info+') },
  { value: 'WARN' as Level, label: t('Warn+') },
  { value: 'ERROR' as Level, label: t('Errors') },
]);
const fullLine = (l: LogLine) => [l.message, ...l.attrs.map(([k, v]) => `${k}=${v}`)].join('  ');
</script>

<template>
  <Page :max="1400" fill>
    <PageHead :title="t('Activity log')" :subtitle="t('Live server log (last {n} lines).', { n: LOG_MAX })">
      <Segmented v-model="level" :options="levels" />
      <div class="search">
        <Search :size="14" class="s-icon" />
        <input v-model="search" class="input" :placeholder="t('Search log')" spellcheck="false" @keydown.esc="search = ''" />
        <button v-if="search" class="btn ghost icon sm s-clear" :title="t('Clear')" @click="search = ''"><X :size="13" /></button>
      </div>
      <button class="btn ghost icon" :title="paused ? t('Resume') : t('Pause')" @click="setPaused(!paused)">
        <Play v-if="paused" :size="16" /><Pause v-else :size="16" />
      </button>
      <button class="btn ghost icon" :title="t('Copy visible lines')" :disabled="!entries.length" @click="copyLines"><Copy :size="16" /></button>
      <button class="btn ghost icon" :title="t('Clear view')" :disabled="!entries.length" @click="clearView"><Eraser :size="16" /></button>
    </PageHead>

    <div class="card box">
      <States v-if="!loaded" kind="loading" compact />
      <States v-else-if="error && !entries.length" kind="error" compact :message="error.message" :connection="error.isConnectionError" @retry="poll(true)" />
      <States v-else-if="!entries.length" kind="empty" compact :title="query ? t('No log lines match “{q}”', { q: query }) : t('No log lines yet')">
        <template #icon><ScrollText :size="22" /></template>
      </States>
      <div v-else ref="scroller" class="scroller selectable" @scroll.passive="onScroll">
        <div class="spacer" :style="{ height: `${entries.length * ROW + PAD * 2}px` }">
          <div class="rows" :style="{ transform: `translateY(${range.start * ROW + PAD}px)` }">
            <div v-for="l in visible" :key="l.id" class="line">
              <span class="time">{{ formatTime(l.time) }}</span>
              <span class="lvl" :class="levelClass(l.level)">{{ l.level }}</span>
              <span class="msg" :title="fullLine(l)">{{ l.message }}<template v-for="[k, v] in l.attrs" :key="k"><span class="k">&nbsp; {{ k }}=</span><span class="v">{{ v }}</span></template></span>
            </div>
          </div>
        </div>
      </div>

      <div v-if="loaded && entries.length" class="overlay">
        <Pill v-if="paused" tone="warning"><Pause :size="11" />{{ t('Paused') }}</Pill>
        <Pill v-else-if="error" tone="danger" dot>{{ t('Last refresh failed: {e}', { e: error.message }) }}</Pill>
        <span class="spacer-x" />
        <button v-if="!follow" class="btn primary sm follow" @click="followNow"><ArrowDown :size="15" />{{ t('Follow') }}</button>
      </div>
    </div>
  </Page>
</template>

<style scoped>
.search { position: relative; width: 200px; }
.search .input { height: 34px; padding-left: 32px; padding-right: 30px; }
.s-icon { position: absolute; left: 11px; top: 10px; color: var(--subtle); pointer-events: none; }
.s-clear { position: absolute; right: 3px; top: 3px; }
.box { flex: 1; min-height: 240px; position: relative; overflow: hidden; display: flex; flex-direction: column; }
.box > .state { flex: 1; }
.scroller { flex: 1; min-height: 0; overflow: auto; font-family: var(--font-mono); font-size: 12px; }
.spacer { position: relative; min-width: 100%; }
.rows { position: absolute; left: 0; right: 0; top: 0; will-change: transform; }
.line { height: 24px; display: flex; align-items: center; padding: 0 14px; white-space: nowrap; }
.line:hover { background: var(--hover); }
.time { width: 70px; flex-shrink: 0; color: var(--subtle); }
.lvl { width: 52px; flex-shrink: 0; font-size: 11.5px; font-weight: 600; }
.lvl.error { color: var(--danger); }
.lvl.warn { color: var(--warning); }
.lvl.debug { color: var(--subtle); }
.lvl.info { color: var(--primary); }
.msg { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; color: var(--foreground); }
.k { color: var(--subtle); }
.v { color: var(--muted); }
.overlay { position: absolute; left: 16px; right: 16px; bottom: 16px; display: flex; align-items: center; gap: 8px; pointer-events: none; }
.overlay > * { pointer-events: auto; }
.spacer-x { flex: 1; }
.follow { box-shadow: var(--shadow); }
</style>
