<script setup lang="ts">
// In-app PDF viewer: pdf.js renders each page to a canvas when it scrolls
// into view (WebKitGTK on Linux has no built-in PDF viewer, so no <iframe>).
// pdf.js is loaded on first use. (2.0 object_panel.dart _openPdf, pdfrx)
import { nextTick, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue';
import { ExternalLink, FileText, MoveHorizontal, X, ZoomIn, ZoomOut } from 'lucide-vue-next';
import type { PDFDocumentLoadingTask, PDFDocumentProxy, RenderTask } from 'pdfjs-dist';
import States from '@/components/ui/States.vue';
import { t } from '@/lib/i18n';
import { useTopmostEsc } from './overlay';

const props = defineProps<{ data: ArrayBuffer; name: string }>();
const emit = defineEmits<{ close: []; openExternal: [] }>();

const root = ref<HTMLElement | null>(null);
const scroller = ref<HTMLElement | null>(null);
const doc = shallowRef<PDFDocumentProxy | null>(null);
/** Page sizes at scale 1 (PDF points). */
const sizes = ref<{ w: number; h: number }[]>([]);
const error = ref<string | null>(null);
const zoom = ref(1);
const fitScale = ref(1);
const current = ref(1);
const canvases: (HTMLCanvasElement | null)[] = [];
const rendered = new Map<number, number>(); // page index → scale it was rendered at
const tasks = new Map<number, RenderTask>();
let observer: IntersectionObserver | null = null;
const visible = new Set<number>();
let destroyed = false;
let loading: PDFDocumentLoadingTask | null = null;

useTopmostEsc(root, () => emit('close'));

const scale = () => fitScale.value * zoom.value;

async function open() {
  try {
    const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
    const worker = await import('pdfjs-dist/legacy/build/pdf.worker.min.mjs?url');
    pdfjs.GlobalWorkerOptions.workerSrc = worker.default;
    if (destroyed) return;
    // pdf.js takes ownership of the bytes it is given: pass a copy.
    const task = (loading = pdfjs.getDocument({ data: new Uint8Array(props.data.slice(0)), useWasm: false, enableXfa: false, useSystemFonts: true }));
    const d = await task.promise;
    if (destroyed) return;
    const list: { w: number; h: number }[] = [];
    for (let i = 1; i <= d.numPages; i++) {
      const vp = (await d.getPage(i)).getViewport({ scale: 1 });
      list.push({ w: vp.width, h: vp.height });
    }
    doc.value = d;
    sizes.value = list;
    computeFit();
    await nextTick();
    observe();
  } catch (e) {
    const err = e as Error;
    error.value = err?.name === 'PasswordException' ? t('This PDF is password-protected.') : err?.message || String(e);
  }
}

/** Fit the widest page to the viewer width. */
function computeFit() {
  const w = scroller.value?.clientWidth ?? 800;
  const widest = Math.max(1, ...sizes.value.map((s) => s.w));
  fitScale.value = Math.max(0.1, (w - 48) / widest);
}

function observe() {
  observer?.disconnect();
  observer = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        const i = Number((e.target as HTMLElement).dataset.index);
        if (e.isIntersecting) visible.add(i);
        else visible.delete(i);
      }
      if (visible.size) current.value = Math.min(...visible) + 1;
      renderVisible();
    },
    { root: scroller.value, rootMargin: '400px 0px' },
  );
  scroller.value?.querySelectorAll<HTMLElement>('.page').forEach((el) => observer!.observe(el));
}

function renderVisible() {
  for (const i of visible) void renderPage(i);
}

async function renderPage(i: number) {
  const d = doc.value;
  const canvas = canvases[i];
  const s = scale();
  if (!d || !canvas || rendered.get(i) === s) return;
  tasks.get(i)?.cancel();
  rendered.set(i, s);
  try {
    const page = await d.getPage(i + 1);
    const dpr = window.devicePixelRatio || 1;
    const vp = page.getViewport({ scale: s * dpr });
    // Render off-screen, then swap, so the old pixels stay until the new ones are ready.
    const off = document.createElement('canvas');
    off.width = Math.floor(vp.width);
    off.height = Math.floor(vp.height);
    const task = page.render({ canvas: off, viewport: vp });
    tasks.set(i, task);
    await task.promise;
    tasks.delete(i);
    if (rendered.get(i) !== s || destroyed) return;
    canvas.width = off.width;
    canvas.height = off.height;
    canvas.getContext('2d')?.drawImage(off, 0, 0);
  } catch (e) {
    if ((e as Error)?.name !== 'RenderingCancelledException' && rendered.get(i) === s) rendered.delete(i);
  }
}

function setZoom(z: number) {
  const el = scroller.value;
  const ratio = el && el.scrollHeight > 0 ? el.scrollTop / el.scrollHeight : 0;
  zoom.value = Math.min(5, Math.max(0.25, Math.round(z * 100) / 100));
  void nextTick(() => {
    if (el) el.scrollTop = ratio * el.scrollHeight;
    renderVisible();
  });
}

function onWheel(e: WheelEvent) {
  if (!(e.ctrlKey || e.metaKey)) return;
  e.preventDefault();
  setZoom(zoom.value * (e.deltaY < 0 ? 1.1 : 1 / 1.1));
}

let resizeTimer: number | undefined;
function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = window.setTimeout(() => {
    computeFit();
    void nextTick(renderVisible);
  }, 150);
}

onMounted(() => {
  void open();
  window.addEventListener('resize', onResize);
});
onBeforeUnmount(() => {
  destroyed = true;
  window.removeEventListener('resize', onResize);
  observer?.disconnect();
  for (const task of tasks.values()) task.cancel();
  void loading?.destroy(); // also ends the worker
});
</script>

<template>
  <Teleport to="body">
    <div ref="root" class="scrim" @mousedown.self="emit('close')">
      <div class="viewer" role="dialog" aria-modal="true">
        <header>
          <FileText :size="17" class="muted" />
          <span class="name ellipsis grow" :title="name">{{ name }}</span>
          <template v-if="doc">
            <span class="pages">{{ t('Page {n} of {total}', { n: current, total: doc.numPages }) }}</span>
            <span class="sep" />
            <button class="btn ghost icon sm" :title="t('Zoom out')" :disabled="zoom <= 0.25" @click="setZoom(zoom / 1.25)"><ZoomOut :size="16" /></button>
            <span class="pct">{{ Math.round(zoom * 100) }}%</span>
            <button class="btn ghost icon sm" :title="t('Zoom in')" :disabled="zoom >= 5" @click="setZoom(zoom * 1.25)"><ZoomIn :size="16" /></button>
            <button class="btn ghost icon sm" :title="t('Fit width')" :disabled="zoom === 1" @click="setZoom(1)"><MoveHorizontal :size="16" /></button>
            <span class="sep" />
          </template>
          <button class="btn ghost sm" @click="emit('openExternal')"><ExternalLink :size="14" />{{ t('Open with default app') }}</button>
          <button class="btn ghost icon sm" :title="t('Close (Esc)')" @click="emit('close')"><X :size="16" /></button>
        </header>
        <div ref="scroller" class="body" @wheel="onWheel">
          <States v-if="error" kind="error" :title="t('Could not open the PDF')" :message="error">
            <template #actions><button class="btn" @click="emit('openExternal')">{{ t('Open with default app') }}</button></template>
          </States>
          <States v-else-if="!doc" kind="loading" />
          <template v-else>
            <div
              v-for="(s, i) in sizes"
              :key="i"
              class="page"
              :data-index="i"
              :style="{ width: `${Math.floor(s.w * fitScale * zoom)}px`, height: `${Math.floor(s.h * fitScale * zoom)}px` }"
            >
              <canvas :ref="(el) => (canvases[i] = el as HTMLCanvasElement | null)" />
            </div>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.scrim { position: fixed; inset: 0; z-index: 120; background: var(--scrim); display: grid; place-items: center; padding: 24px; animation: fade var(--fast); }
.viewer { width: min(1100px, 100%); height: 100%; display: flex; flex-direction: column; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-xl); box-shadow: var(--shadow); overflow: hidden; }
header { display: flex; align-items: center; gap: 6px; padding: 8px 10px 8px 16px; border-bottom: 1px solid var(--border); }
.name { font-weight: 600; font-size: 13.5px; }
.pages, .pct { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; white-space: nowrap; }
.pct { min-width: 40px; text-align: center; }
.sep { width: 1px; height: 18px; background: var(--border); margin: 0 4px; }
.body { flex: 1; min-height: 0; overflow: auto; background: var(--background); padding: 24px; }
/* Block layout: a page wider than the viewer scrolls instead of being cut off on the left. */
.page { margin: 0 auto 16px; background: #fff; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.18); }
canvas { display: block; width: 100%; height: 100%; }
@keyframes fade { from { opacity: 0; } }
</style>
