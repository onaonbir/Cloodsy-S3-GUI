<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { Check } from 'lucide-vue-next';
import { closeMenu, menu, type MenuItem } from '@/lib/menu';

const el = ref<HTMLElement | null>(null);
const pos = ref({ left: 0, top: 0 });

watch(menu, async (m) => {
  if (!m) return;
  pos.value = { left: m.x, top: m.y };
  await nextTick();
  const r = el.value?.getBoundingClientRect();
  if (!r) return;
  // Opened from a button: align the right edges; keep it on screen.
  let left = m.x - (r.width > 0 && m.x > window.innerWidth / 2 ? r.width : 0);
  let top = m.y;
  if (left + r.width > window.innerWidth - 8) left = window.innerWidth - r.width - 8;
  if (top + r.height > window.innerHeight - 8) top = Math.max(8, m.y - r.height);
  pos.value = { left: Math.max(8, left), top };
});

function pick(i: MenuItem) {
  if (i.disabled) return;
  closeMenu();
  i.action?.();
}

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape' && menu.value) {
    e.stopPropagation();
    closeMenu();
  }
}
onMounted(() => window.addEventListener('keydown', onKey, true));
onBeforeUnmount(() => window.removeEventListener('keydown', onKey, true));
</script>

<template>
  <Teleport to="body">
    <div v-if="menu" class="layer" @mousedown="closeMenu" @contextmenu.prevent="closeMenu">
      <div ref="el" class="menu" :style="{ left: `${pos.left}px`, top: `${pos.top}px` }" @mousedown.stop>
        <template v-for="(i, n) in menu.items" :key="n">
          <div v-if="i.label === '-'" class="sep" />
          <button v-else class="item" :class="{ danger: i.danger }" :disabled="i.disabled" @click="pick(i)">
            <span class="icon"><Check v-if="i.checked" :size="14" /><component :is="i.icon" v-else-if="i.icon" :size="15" /></span>
            <span class="label">{{ i.label }}</span>
            <span v-if="i.shortcut" class="shortcut">{{ i.shortcut }}</span>
          </button>
        </template>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.layer { position: fixed; inset: 0; z-index: 200; }
.menu { position: fixed; min-width: 200px; max-width: 320px; padding: 5px; background: var(--card); border: 1px solid var(--border); border-radius: var(--radius-lg); box-shadow: var(--shadow); }
.item { display: flex; align-items: center; gap: 8px; width: 100%; height: 32px; padding: 0 10px 0 6px; border: 0; border-radius: var(--radius-sm); background: none; color: var(--foreground); font: 500 13px var(--font-sans); cursor: pointer; text-align: left; }
.item:hover:not(:disabled) { background: var(--hover); }
.item:disabled { opacity: 0.45; cursor: default; }
.item.danger { color: var(--danger); }
.icon { width: 18px; display: grid; place-items: center; color: var(--muted); }
.danger .icon { color: var(--danger); }
.label { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.shortcut { font-size: 11px; color: var(--subtle); }
.sep { height: 1px; background: var(--border); margin: 4px 2px; }
</style>
