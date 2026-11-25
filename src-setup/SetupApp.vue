<script setup lang="ts">
// The setup window (720×500, frameless): welcome → options → installing →
// done, or update / repair / downgrade / uninstall. The look is the GUI's
// (src/styles/tokens.css, Plus Jakarta Sans, the brand mark); the steps come
// from installer/setup.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { Check, Database, Minus, Server, TriangleAlert, X } from 'lucide-vue-next';
import BrandMark from '@/components/BrandMark.vue';
import { bridge, type Done, type Info, type Step, type StepId } from './bridge';
import { errorText, s } from './strings';

type Scene = 'welcome' | 'options' | 'progress' | 'done' | 'error';
const info = ref<Info | null>(null);
const scene = ref<Scene>('welcome');
const desktop = ref(true);
const dir = ref('');
const openAfter = ref(true);
const wipe = ref(false);
const steps = ref<Partial<Record<StepId, Step>>>({});
const result = ref<Done | null>(null);

const uninstalling = computed(() => info.value?.mode === 'uninstall');
const updating = computed(() => ['update', 'downgrade', 'reinstall'].includes(info.value?.mode ?? ''));
const busy = computed(() => scene.value === 'progress');

const order = computed<StepId[]>(() => (uninstalling.value ? ['close', 'remove', 'clean'] : ['prepare', 'files', 'register']));
const finished = (id: StepId) => ['done', 'skipped'].includes(steps.value[id]?.state ?? '');
const doneCount = computed(() => order.value.filter(finished).length);

// The stepper on top.
const flow = computed(() =>
  uninstalling.value
    ? [s('flow.confirm'), s('flow.remove'), s('flow.done')]
    : updating.value
      ? [s('flow.welcome'), s('flow.update'), s('flow.done')]
      : [s('flow.welcome'), s('flow.options'), s('flow.install'), s('flow.done')],
);
const at = computed(() => {
  const n = flow.value.length;
  switch (scene.value) {
    case 'welcome':
      return 1;
    case 'options':
      return 2;
    case 'progress':
    case 'error':
      return n - 1;
    default:
      return n;
  }
});

function start() {
  steps.value = {};
  result.value = null;
  scene.value = 'progress';
  if (uninstalling.value) bridge.uninstall(wipe.value);
  else bridge.install(info.value?.dir_locked ? null : dir.value, desktop.value);
}
function next() {
  if (scene.value === 'welcome' && !uninstalling.value && !updating.value) scene.value = 'options';
  else start();
}
async function changeDir() {
  const picked = await bridge.pickDir(dir.value, s('options.folder_title'));
  if (picked) dir.value = picked;
}
function finish() {
  if (result.value?.ok && openAfter.value && !uninstalling.value) bridge.launch();
  else bridge.close();
}

const title = computed(() => {
  const i = info.value;
  if (!i) return '';
  switch (scene.value) {
    case 'progress':
      return s(uninstalling.value ? 'h.removing' : updating.value ? 'h.updating' : 'h.installing');
    case 'done':
      return s(uninstalling.value ? 'h.removed' : updating.value ? 'h.updated' : 'h.installed');
    case 'error':
      return s(uninstalling.value ? 'h.failed_uninstall' : 'h.failed_install');
    case 'options':
      return s('h.options');
    default:
      return s(`h.${i.mode}` as 'h.install');
  }
});
const primary = computed(() => {
  switch (scene.value) {
    case 'welcome': {
      const m = info.value?.mode;
      return s(uninstalling.value ? 'btn.remove' : m === 'install' ? 'btn.next' : m === 'downgrade' ? 'btn.anyway' : m === 'reinstall' ? 'btn.repair' : 'btn.update');
    }
    case 'options':
      return s('btn.install');
    case 'error':
      return s('btn.retry');
    case 'done':
      return uninstalling.value || !openAfter.value ? s('btn.close') : s('btn.finish_open');
    default:
      return '';
  }
});
function onPrimary() {
  if (scene.value === 'done') finish();
  else if (scene.value === 'error') start();
  else next();
}

const doneText = computed(() => {
  const i = info.value;
  if (!i) return '';
  if (uninstalling.value) return `${s(wipe.value ? 'done.removed_wipe' : 'done.removed')} ${s('done.servers')}`;
  if (updating.value) return s('done.update', { version: i.version });
  return s('done.install', { desktop: desktop.value ? s('done.install_desktop') : '' });
});

let unStep: (() => void) | undefined;
let unDone: (() => void) | undefined;
onMounted(async () => {
  info.value = await bridge.info();
  dir.value = info.value.dir;
  desktop.value = info.value.desktop;
  unStep = await bridge.onStep((st) => (steps.value = { ...steps.value, [st.id]: st }));
  unDone = await bridge.onDone((d) => {
    result.value = d;
    scene.value = d.ok ? 'done' : 'error';
  });
  // An updater (/P, /UPDATE): straight to installing.
  if (info.value.auto_start) start();
  // Design work in a browser: ?scene=options|done|error
  const sc = new URLSearchParams(location.search).get('scene') as Scene | null;
  if (sc && sc !== 'progress') scene.value = sc;
  if (sc === 'error') result.value = { ok: false, message: 'swap', detail: 'cloodsy-s3.exe: Access is denied. (os error 5)', step: 'files' };
});
onBeforeUnmount(() => {
  unStep?.();
  unDone?.();
});
</script>

<template>
  <div class="frame" @contextmenu.prevent>
    <header class="bar" data-tauri-drag-region>
      <span class="bar-logo"><BrandMark :size="18" /></span>
      <span class="bar-title" data-tauri-drag-region>{{ s(uninstalling ? 'title.uninstall' : 'title.setup') }}</span>
      <button type="button" class="bar-btn" :aria-label="s('minimize')" @click="bridge.minimize()"><Minus :size="16" /></button>
      <button type="button" class="bar-btn bar-close" :aria-label="s('close')" :disabled="busy" @click="bridge.close()"><X :size="16" /></button>
    </header>

    <main v-if="info" class="card">
      <ol class="flow" :aria-label="s('title.setup')">
        <li v-for="(l, i) in flow" :key="l" :class="{ on: i + 1 <= at }" :aria-current="i + 1 === at ? 'step' : undefined">
          <span class="dot" :class="{ current: i + 1 === at && scene !== 'done', past: i + 1 < at || scene === 'done' }">
            <Check v-if="i + 1 < at || scene === 'done'" :size="12" :stroke-width="3" /><template v-else>{{ i + 1 }}</template>
          </span>
          {{ l }}
        </li>
      </ol>
      <p v-if="info.trial" class="trial">{{ s('trial') }}</p>

      <section class="body">
        <!-- Welcome: install or update -->
        <template v-if="scene === 'welcome' && !uninstalling">
          <div class="eyebrow">{{ info.mode === 'install' ? s('eyebrow.install', { version: info.version }) : s('eyebrow.update') }}</div>
          <h1>{{ title }}</h1>
          <template v-if="info.mode === 'install'">
            <p class="lead">{{ s('welcome.body') }}</p>
            <div class="tiles">
              <div class="tile">
                <span class="tile-icon"><Database :size="18" /></span>
                <div><b>{{ s('welcome.app') }}</b><span>{{ s('welcome.app_d') }}</span></div>
              </div>
              <div class="tile">
                <span class="tile-icon soft"><Server :size="18" /></span>
                <div><b>{{ s('welcome.servers') }}</b><span>{{ s('welcome.servers_d') }}</span></div>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="versions">
              <div><small>{{ s('update.installed') }}</small><code>{{ info.installed ?? '—' }}</code></div>
              <span class="arrow">→</span>
              <div><small>{{ s('update.new') }}</small><code>{{ info.version }}</code></div>
            </div>
            <p class="lead">{{ info.mode === 'downgrade' ? s('update.downgrade') : info.mode === 'reinstall' ? s('update.reinstall') : s('update.body') }}</p>
          </template>
        </template>

        <!-- Uninstall: confirm -->
        <template v-if="scene === 'welcome' && uninstalling">
          <h1>{{ title }}</h1>
          <p class="lead">{{ s('uninstall.body') }}</p>
          <button type="button" role="switch" :aria-checked="wipe" class="choice" @click="wipe = !wipe">
            <span class="choice-text"><b>{{ s('uninstall.wipe') }}</b><span>{{ s('uninstall.wipe_d') }}</span></span>
            <span class="switch danger" :class="{ on: wipe }"><i /></span>
          </button>
        </template>

        <!-- Options -->
        <template v-if="scene === 'options'">
          <h1>{{ title }}</h1>
          <p class="lead">{{ s('options.body') }}</p>
          <div class="choices">
            <button type="button" role="switch" :aria-checked="desktop" class="choice" @click="desktop = !desktop">
              <span class="choice-text"><b>{{ s('options.desktop') }}</b><span>{{ s('options.desktop_d') }}</span></span>
              <span class="switch" :class="{ on: desktop }"><i /></span>
            </button>
          </div>
          <details class="advanced">
            <summary>{{ s('options.advanced') }}</summary>
            <div class="dir">
              <span class="dir-path" :title="dir">{{ dir }}</span>
              <button type="button" class="btn" @click="changeDir">{{ s('options.change') }}</button>
              <button v-if="dir !== info.default_dir" type="button" class="link" @click="dir = info.default_dir">{{ s('options.default') }}</button>
            </div>
          </details>
        </template>

        <!-- Working, or done -->
        <template v-if="scene === 'progress' || scene === 'done'">
          <div v-if="scene === 'done'" class="badge ok"><Check :size="24" /></div>
          <h1>{{ title }}</h1>
          <p v-if="scene === 'progress'" class="lead">{{ s('progress.body') }}</p>
          <p v-else class="lead">{{ doneText }}</p>
          <div v-if="scene === 'progress'" class="meter"><div :style="{ width: `${(doneCount / order.length) * 100}%` }" /></div>
          <ul v-if="scene === 'progress'" class="steps">
            <li v-for="id in order" :key="id">
              <span class="state" :class="steps[id]?.state ?? 'waiting'">
                <Check v-if="finished(id)" :size="12" :stroke-width="3" /><template v-else-if="steps[id]?.state === 'failed'">!</template>
              </span>
              <span :class="{ dim: !steps[id] }">{{ s(`step.${id}` as 'step.prepare') }}</span>
              <span class="step-detail">{{ steps[id]?.state === 'running' ? s('progress.running') : steps[id]?.detail === 'kept' ? s('step.kept') : steps[id]?.detail }}</span>
            </li>
          </ul>
          <button v-if="scene === 'done' && !uninstalling" type="button" role="switch" :aria-checked="openAfter" class="choice" @click="openAfter = !openAfter">
            <span class="choice-text"><b>{{ s('done.open') }}</b><span>{{ s(updating ? 'done.open_update_d' : 'done.open_d') }}</span></span>
            <span class="switch" :class="{ on: openAfter }"><i /></span>
          </button>
        </template>

        <!-- Error -->
        <template v-if="scene === 'error'">
          <div class="badge bad"><TriangleAlert :size="24" /></div>
          <h1>{{ title }}</h1>
          <p class="lead">{{ errorText(result?.message ?? '') }}</p>
          <pre class="detail">{{ result?.detail }}
{{ s('error.log') }}: {{ info.log }}</pre>
          <p v-if="!uninstalling && info.mode !== 'install'" class="note">{{ s('error.kept') }}</p>
        </template>
      </section>

      <footer class="actions">
        <span class="hint">{{ scene === 'welcome' && info.mode === 'install' ? s('terms') : busy ? s('progress.steps', { done: doneCount, total: order.length }) : '' }}</span>
        <button v-if="scene === 'options'" type="button" class="btn" @click="scene = 'welcome'">{{ s('btn.back') }}</button>
        <button v-if="scene === 'error'" type="button" class="btn" @click="bridge.openLog()">{{ s('btn.open_log') }}</button>
        <button v-if="scene === 'error' || (scene === 'welcome' && uninstalling)" type="button" class="btn" @click="bridge.close()">{{ s('btn.cancel') }}</button>
        <button v-if="!busy" type="button" class="btn primary" :class="{ danger: scene === 'welcome' && uninstalling }" @click="onPrimary">{{ primary }}</button>
      </footer>
    </main>
  </div>
</template>

<style scoped>
.frame {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--titlebar);
}
.bar {
  display: flex;
  align-items: center;
  gap: 10px;
  height: var(--titlebar-height);
  flex-shrink: 0;
  padding-left: 14px;
}
.bar-logo {
  display: grid;
  pointer-events: none;
}
.bar-title {
  flex: 1;
  font-size: 12px;
  font-weight: 700;
  color: var(--muted);
}
.bar-btn {
  display: grid;
  place-items: center;
  width: 44px;
  height: var(--titlebar-height);
  border: 0;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
}
.bar-btn:hover {
  background: var(--hover);
  color: var(--foreground);
}
.bar-close:hover {
  background: #c42b1c;
  color: #fff;
}
.bar-btn:disabled {
  opacity: 0.3;
  pointer-events: none;
}
.card {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
  margin: 0 10px 10px;
  border-radius: var(--radius-xl);
  background: var(--background);
  border: 1px solid var(--border);
  overflow: hidden;
}
.flow {
  display: flex;
  gap: 18px;
  margin: 0;
  padding: 18px var(--page) 0;
  list-style: none;
}
.flow li {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12px;
  font-weight: 700;
  color: var(--subtle);
}
.flow li.on {
  color: var(--foreground);
}
.dot {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  font-size: 11px;
  background: var(--border);
  color: var(--muted);
}
.dot.current {
  background: var(--primary);
  color: var(--on-primary);
}
.dot.past {
  background: var(--success);
  color: var(--background);
}
.trial {
  margin: 10px var(--page) 0;
  padding: 6px 10px;
  border-radius: var(--radius-md);
  font-size: 11px;
  font-weight: 600;
  color: var(--warning);
  background: var(--warning-soft);
}
.body {
  display: flex;
  flex-direction: column;
  gap: 14px;
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 20px var(--page) 0;
}
.eyebrow {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.12em;
  color: var(--primary);
}
h1 {
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.4px;
}
.lead {
  font-size: 13px;
  line-height: 1.5;
  color: var(--muted);
}
.tiles,
.choices {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.tile,
.choice {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--card);
  color: var(--foreground);
  font: inherit;
  text-align: left;
}
.choice {
  cursor: pointer;
}
.choice:hover {
  background: var(--card-hover);
  border-color: var(--border-strong);
}
.tile b,
.choice b {
  display: block;
  font-size: 13px;
  font-weight: 700;
}
.tile span,
.choice-text span {
  font-size: 12px;
  color: var(--muted);
}
.tile-icon {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  flex-shrink: 0;
  border-radius: 9px;
  background: var(--primary);
  color: var(--on-primary);
}
.tile-icon.soft {
  background: var(--primary-soft);
  color: var(--primary);
}
.choice-text {
  flex: 1;
}
.switch {
  position: relative;
  width: 38px;
  height: 22px;
  flex-shrink: 0;
  border-radius: 11px;
  background: var(--border-strong);
  transition: background var(--fast);
}
.switch i {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
  transition: left var(--fast);
}
.switch.on {
  background: var(--primary);
}
.switch.danger.on {
  background: var(--danger);
}
.switch.on i {
  left: 19px;
}
.versions {
  display: flex;
  align-items: center;
  gap: 14px;
  align-self: flex-start;
  padding: 12px 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--card);
}
.versions small {
  display: block;
  font-size: 11px;
  font-weight: 600;
  color: var(--muted);
}
.versions code {
  font-family: var(--font-mono);
  font-size: 17px;
  font-weight: 500;
}
.arrow {
  font-size: 20px;
  color: var(--primary);
}
.advanced {
  font-size: 13px;
}
.advanced summary {
  cursor: pointer;
  font-weight: 700;
  color: var(--muted);
}
.dir {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}
.dir-path {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  padding: 8px 10px;
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--card);
  font-family: var(--font-mono);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
  user-select: text;
}
.badge {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 50%;
}
.badge.ok {
  background: var(--success-soft);
  color: var(--success);
}
.badge.bad {
  background: var(--danger-soft);
  color: var(--danger);
}
.meter {
  height: 8px;
  flex-shrink: 0;
  border-radius: 4px;
  background: var(--border);
  overflow: hidden;
}
.meter div {
  height: 100%;
  border-radius: 4px;
  background: var(--primary);
  transition: width 300ms;
}
.steps {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.steps li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 13px;
  font-weight: 600;
}
.state {
  display: grid;
  place-items: center;
  width: 20px;
  height: 20px;
  flex-shrink: 0;
  border-radius: 50%;
  font-size: 11px;
  font-weight: 700;
}
.state.waiting {
  border: 2px solid var(--border-strong);
}
.state.running {
  background: var(--primary);
  box-shadow: 0 0 0 4px var(--primary-soft);
}
.state.done,
.state.skipped {
  background: var(--success);
  color: var(--background);
}
.state.failed {
  background: var(--danger);
  color: #fff;
}
.dim {
  color: var(--muted);
  font-weight: 500;
}
.step-detail {
  margin-left: auto;
  font-size: 12px;
  font-weight: 500;
  color: var(--muted);
}
.detail {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-md);
  background: var(--hover);
  border: 1px solid var(--border);
  font-family: var(--font-mono);
  font-size: 11px;
  white-space: pre-wrap;
  color: var(--muted);
  user-select: text;
}
.note {
  font-size: 12px;
  color: var(--muted);
}
.actions {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px var(--page) 18px;
}
.hint {
  flex: 1;
  font-size: 12px;
  color: var(--subtle);
}
.btn {
  min-height: 36px;
  padding: 0 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--card);
  color: var(--foreground);
  font: 600 13px var(--font-sans);
  white-space: nowrap;
  cursor: pointer;
  transition: background var(--fast), border-color var(--fast);
}
.btn:hover {
  background: var(--card-hover);
  border-color: var(--border-strong);
}
.btn.primary {
  padding: 0 20px;
  border-color: var(--primary);
  background: var(--primary);
  color: var(--on-primary);
}
.btn.primary:hover {
  filter: brightness(1.08);
}
.btn.primary.danger {
  border-color: var(--danger);
  background: var(--danger);
  color: #fff;
}
.link {
  border: 0;
  background: none;
  color: var(--muted);
  font: 600 12px var(--font-sans);
  cursor: pointer;
}
.link:hover {
  color: var(--foreground);
}
</style>
