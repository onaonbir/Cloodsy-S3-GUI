import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../models/lifecycle_rule.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/server_controller.dart';
import '../../dialogs/access_dialogs.dart';
import '../../dialogs/lifecycle_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

class LifecycleTab extends StatelessWidget {
  const LifecycleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final v2 = context.watch<ServerController>().status?.lifecycleV2 ?? false;
    final rules = ctrl.rules;
    final c = context.colors;
    final versioned = ctrl.bucket?.versioningEnabled ?? false;

    void add() => v2
        ? showLifecycleRuleDialog(context,
            versioned: versioned, save: ctrl.saveRule)
        : showLifecycleDialog(context, ctrl.addRule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Lifecycle rules expire objects, prune old versions and clean '
                'up abandoned uploads automatically.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            if (rules.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final ok = await confirm(context,
                      title: tr('Remove all rules'),
                      message: tr('Delete every lifecycle rule of this bucket?'),
                      confirmLabel: tr('Remove all'));
                  if (ok && context.mounted) {
                    await runAction(context, () => ctrl.deleteRules(),
                        success: 'All rules removed');
                  }
                },
                child: Text(tr('Remove all')),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: add,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(tr('Add rule')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (rules.isEmpty)
          Panel(
            child: EmptyState(
              compact: true,
              icon: LucideIcons.timer,
              title: tr('No lifecycle rules'),
              message: tr('Add a rule to clean up logs, temporary uploads, old '
                  'versions or backups after a number of days.'),
              action: OutlinedButton.icon(
                onPressed: add,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(tr('Add rule')),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rules.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  _RuleRow(rule: rules[i], v2: v2, versioned: versioned),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final LifecycleRule rule;
  final bool v2;
  final bool versioned;
  const _RuleRow(
      {required this.rule, required this.v2, required this.versioned});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = context.read<BucketController>();
    final t = Theme.of(context).textTheme;
    final allObjects = rule.prefix.isEmpty;
    final canDelete = v2 || !allObjects;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(LucideIcons.timer,
              tone: rule.enabled ? Tone.primary : Tone.neutral, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: rule.enabled ? 1 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                          child: Text(rule.displayName, style: t.titleSmall)),
                      const SizedBox(width: 8),
                      if (!rule.enabled) Pill(tr('Disabled')),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text.rich(TextSpan(style: t.bodyMedium, children: [
                    if (allObjects)
                      TextSpan(text: tr('All objects'))
                    else ...[
                      TextSpan(text: tr('Prefix ')),
                      TextSpan(
                          text: rule.prefix,
                          style: TextStyle(
                              fontFamily: AppFonts.mono,
                              fontSize: 12,
                              color: c.foreground)),
                    ],
                    TextSpan(text: ' · ${tr('added {d}', {'d': formatDate(rule.createdAt)})}'),
                  ])),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final a in rule.actions) Pill(a)],
                  ),
                ],
              ),
            ),
          ),
          if (v2) ...[
            Switch(
              value: rule.enabled,
              onChanged: (v) => runAction(
                  context, () => ctrl.saveRule(rule.copyWith(enabled: v)),
                  success: v ? 'Rule enabled' : 'Rule disabled'),
            ),
            IconButton(
              tooltip: tr('Edit'),
              icon: const Icon(LucideIcons.pencil, size: 16),
              onPressed: () => showLifecycleRuleDialog(context,
                  existing: rule, versioned: versioned, save: ctrl.saveRule),
            ),
          ],
          IconButton(
            tooltip: canDelete
                ? tr('Delete rule')
                : tr('Rules without a prefix are removed with “Remove all”'),
            icon: Icon(LucideIcons.trash2,
                size: 16, color: canDelete ? c.danger : c.subtle),
            onPressed: !canDelete
                ? null
                : () async {
                    final ok = await confirm(context,
                        title: tr('Delete rule'),
                        message: tr('Delete “{name}”?', {'name': rule.displayName}));
                    if (ok && context.mounted) {
                      await runAction(
                          context,
                          () => v2
                              ? ctrl.deleteRuleById(rule.id)
                              : ctrl.deleteRules(prefix: rule.prefix),
                          success: 'Rule deleted');
                    }
                  },
          ),
        ],
      ),
    );
  }
}
