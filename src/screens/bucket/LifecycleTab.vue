<script setup lang="ts">
// Lifecycle rules (2.0 lifecycle_tab.dart). v2 servers: every action,
// enable switch, edit, delete by id. v1: expiration only, deleted by prefix;
// a rule without a prefix only goes with "Remove all".
import { computed, reactive } from 'vue';
import { Pencil, Plus, Timer, Trash2 } from 'lucide-vue-next';
import Pill from '@/components/ui/Pill.vue';
import States from '@/components/ui/States.vue';
import Toggle from '@/components/ui/Toggle.vue';
import IconBadge from '../buckets/IconBadge.vue';
import LifecycleRuleDialog from './dialogs/LifecycleRuleDialog.vue';
import ExpirationRuleDialog from './dialogs/ExpirationRuleDialog.vue';
import { useBucket } from '../buckets/bucketStore';
import { ruleActions, ruleBody, ruleEnabled, ruleName, versioningEnabled } from '../buckets/logic';
import { has } from '@/stores/session';
import { runAction } from '@/stores/toasts';
import { confirm } from '@/lib/dialogs';
import { openDialog } from '@/lib/overlay';
import type { LifecycleRule } from '@/lib/api';
import { formatDate, formatDateTime } from '@/lib/format';
import { t } from '@/lib/i18n';

const store = useBucket();
const s = store.state;
const v2 = computed(() => has('lifecycle-v2'));
const versioned = computed(() => (s.bucket ? versioningEnabled(s.bucket) : false));
const switching = reactive<Record<number, boolean>>({});

const save = (rule: LifecycleRule) => store.saveRule(rule, ruleBody(rule));

async function add() {
  if (v2.value) {
    await openDialog<boolean>(LifecycleRuleDialog, { versioned: versioned.value, save });
  } else {
    await openDialog<boolean>(ExpirationRuleDialog, {
      add: (name: string, prefix: string, days: number) => store.saveRule({ id: 0 } as LifecycleRule, { name, prefix, expiration_days: days }),
    });
  }
}

function edit(r: LifecycleRule) {
  void openDialog<boolean>(LifecycleRuleDialog, { existing: r, versioned: versioned.value, save });
}

async function setEnabled(r: LifecycleRule, on: boolean) {
  switching[r.id] = true;
  await runAction(() => save({ ...r, status: on ? 'Enabled' : 'Disabled' }), on ? t('Rule enabled') : t('Rule disabled'));
  switching[r.id] = false;
}

const canDelete = (r: LifecycleRule) => v2.value || r.prefix !== '';

async function remove(r: LifecycleRule) {
  if (!canDelete(r)) return;
  const ok = await confirm({ title: t('Delete rule'), message: t('Delete “{name}”?', { name: ruleName(r) }), confirmLabel: t('Delete'), danger: true });
  if (ok) await runAction(() => (v2.value ? store.deleteRuleById(r.id) : store.deleteRules(r.prefix)), t('Rule deleted'));
}

async function removeAll() {
  const ok = await confirm({ title: t('Remove all rules'), message: t('Delete every lifecycle rule of this bucket?'), confirmLabel: t('Remove all'), danger: true });
  if (ok) await runAction(() => store.deleteRules(), t('All rules removed'));
}
</script>

<template>
  <div class="tab">
    <div class="intro">
      <p class="t-body grow">{{ t('Lifecycle rules expire objects, prune old versions and clean up abandoned uploads automatically.') }}</p>
      <button v-if="s.rules.length" class="btn ghost danger" @click="removeAll">{{ t('Remove all') }}</button>
      <button class="btn primary" @click="add"><Plus :size="16" />{{ t('Add rule') }}</button>
    </div>

    <div v-if="!s.rules.length" class="card">
      <States kind="empty" compact :title="t('No lifecycle rules')" :message="t('Add a rule to clean up logs, temporary uploads, old versions or backups after a number of days.')">
        <template #icon><Timer :size="22" /></template>
        <template #actions><button class="btn" @click="add"><Plus :size="16" />{{ t('Add rule') }}</button></template>
      </States>
    </div>

    <div v-else class="card list">
      <div v-for="r in s.rules" :key="r.id" class="rule">
        <IconBadge :icon="Timer" :tone="ruleEnabled(r) ? 'primary' : 'neutral'" :size="34" />
        <div class="grow body" :class="{ off: !ruleEnabled(r) }">
          <div class="row">
            <span class="t-title-sm ellipsis">{{ ruleName(r) }}</span>
            <Pill v-if="!ruleEnabled(r)">{{ t('Disabled') }}</Pill>
          </div>
          <div class="t-body where">
            <template v-if="!r.prefix">{{ t('All objects') }}</template>
            <template v-else>{{ t('Prefix') }} <span class="mono fg selectable">{{ r.prefix }}</span></template>
            <span v-if="r.created_at" :title="formatDateTime(r.created_at)"> · {{ t('added {d}', { d: formatDate(r.created_at) }) }}</span>
          </div>
          <div class="pills"><Pill v-for="a in ruleActions(r)" :key="a">{{ a }}</Pill></div>
        </div>
        <div class="acts">
          <template v-if="v2">
            <Toggle :model-value="ruleEnabled(r)" :busy="switching[r.id]" :title="ruleEnabled(r) ? t('Disable') : t('Enable')" @update:model-value="(v) => setEnabled(r, v)" />
            <button class="btn ghost icon sm" :title="t('Edit')" @click="edit(r)"><Pencil :size="15" /></button>
          </template>
          <button
            class="btn ghost icon sm" :class="{ danger: canDelete(r) }" :disabled="!canDelete(r)"
            :title="canDelete(r) ? t('Delete rule') : t('Rules without a prefix are removed with “Remove all”')" @click="remove(r)"
          >
            <Trash2 :size="15" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tab { display: flex; flex-direction: column; gap: 16px; }
.intro { display: flex; align-items: center; gap: 8px; }
.intro p { margin-right: 4px; }
.list { overflow: hidden; }
.rule { display: flex; align-items: flex-start; gap: 12px; padding: 12px 10px 12px 16px; }
.rule + .rule { border-top: 1px solid var(--border); }
.body.off { opacity: 0.6; }
.where { margin-top: 3px; }
.fg { color: var(--foreground); font-size: 12px; }
.pills { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 6px; }
.pills:empty { display: none; }
.acts { display: flex; align-items: center; gap: 4px; padding-top: 4px; }
.acts .toggle { margin-right: 6px; }
</style>
