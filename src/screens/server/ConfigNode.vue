<script setup lang="ts">
// One level of the configuration tree. Non-empty sections get a heading and
// are indented; their label column shrinks by the indent, so every value
// starts at the same x however deep it sits. Values are plain mono text:
// true green, false muted, masked secrets dimmed.
import { computed } from 'vue';

defineOptions({ name: 'ConfigNode' });
const props = withDefaults(defineProps<{ value: unknown; depth?: number }>(), { depth: 0 });

const INDENT = 14;
const LABEL = 200;
const MASKED = '••••';

const isMap = (v: unknown): v is Record<string, unknown> => v !== null && typeof v === 'object' && !Array.isArray(v);

const entries = computed(() => (isMap(props.value) ? Object.entries(props.value) : null));

function text(v: unknown): string {
  if (v === null || v === undefined) return '—';
  if (Array.isArray(v)) return v.length ? v.map((x) => (x !== null && typeof x === 'object' ? JSON.stringify(x) : String(x))).join(', ') : '[]';
  if (typeof v === 'string') return v === '' ? '""' : v;
  if (isMap(v)) return '{}';
  return String(v);
}

function tone(v: unknown): string {
  if (v === true) return 'yes';
  if (v === false) return 'no';
  if (v === MASKED) return 'masked';
  return '';
}
</script>

<template>
  <div v-if="entries" class="node">
    <template v-for="[k, v] in entries" :key="k">
      <div v-if="isMap(v) && Object.keys(v).length" class="section">
        <div class="t-label-lg heading">{{ k }}</div>
        <div class="nested" :style="{ paddingLeft: `${INDENT}px` }">
          <ConfigNode :value="v" :depth="depth + 1" />
        </div>
      </div>
      <div v-else class="leaf">
        <div class="label ellipsis" :style="{ width: `${Math.max(80, LABEL - INDENT * depth)}px` }" :title="k">{{ k }}</div>
        <div class="value mono selectable" :class="tone(v)">{{ text(v) }}</div>
      </div>
    </template>
  </div>
  <div v-else class="value mono selectable" :class="tone(value)">{{ text(value) }}</div>
</template>

<style scoped>
.node { display: flex; flex-direction: column; }
.section { padding-top: 8px; }
.nested { padding-top: 2px; }
.leaf { display: flex; align-items: baseline; gap: 8px; padding: 7px 0; }
.label { flex-shrink: 0; font-size: 13px; color: var(--muted); }
.value { flex: 1; min-width: 0; font-size: 12.5px; color: var(--foreground); overflow-wrap: anywhere; }
.value.yes { color: var(--success); font-weight: 600; }
.value.no { color: var(--muted); }
.value.masked { color: var(--subtle); }
</style>
