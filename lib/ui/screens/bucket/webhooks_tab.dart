import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../models/admin_extras.dart';
import '../../../models/webhook.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/server_controller.dart';
import '../../dialogs/access_dialogs.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

class WebhooksTab extends StatelessWidget {
  const WebhooksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final v2 = context.watch<ServerController>().status?.webhooksV2 ?? false;
    final hooks = ctrl.webhooks;
    final c = context.colors;

    void add() => showWebhookDialog(
          context,
          ({required label, required url, required events, required active, secret}) =>
              ctrl.addWebhook(
                  label: label, url: url, events: events, secret: secret ?? ''),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Webhooks notify your services when objects are created or '
                'removed in this bucket.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: add,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(tr('Add webhook')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (hooks.isEmpty)
          Panel(
            child: EmptyState(
              compact: true,
              icon: LucideIcons.webhook,
              title: tr('No webhooks'),
              message: tr('Send object events to a URL, e.g. to trigger '
                  'thumbnails, indexing or notifications.'),
              action: OutlinedButton.icon(
                onPressed: add,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(tr('Add webhook')),
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
                for (var i = 0; i < hooks.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  _HookRow(hook: hooks[i], v2: v2),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HookRow extends StatefulWidget {
  final Webhook hook;
  final bool v2;
  const _HookRow({required this.hook, required this.v2});

  @override
  State<_HookRow> createState() => _HookRowState();
}

class _HookRowState extends State<_HookRow> {
  bool _testing = false;

  Future<void> _test() async {
    final ctrl = context.read<BucketController>();
    setState(() => _testing = true);
    try {
      final r = await ctrl.testWebhook(widget.hook.id);
      if (!mounted) return;
      showToast(
        context,
        r.ok
            ? tr('Test delivered: HTTP {code} in {ms} ms', {'code': r.statusCode, 'ms': r.durationMs})
            : tr('Test failed: {e}', {'e': r.error.isNotEmpty ? r.error : 'HTTP ${r.statusCode}'}),
        error: !r.ok,
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _edit() {
    final ctrl = context.read<BucketController>();
    final h = widget.hook;
    showWebhookDialog(
      context,
      ({required label, required url, required events, required active, secret}) =>
          ctrl.updateWebhook(h.id,
              label: label,
              url: url,
              events: events,
              active: active,
              secret: secret),
      existing: h,
      canEdit: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final ctrl = context.read<BucketController>();
    final hook = widget.hook;
    final events = hook.eventTypes == '*'
        ? ['All events']
        : hook.eventTypes.split(',').map((e) => e.trim()).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(LucideIcons.webhook,
              tone: hook.active ? Tone.success : Tone.neutral, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        hook.name.isNotEmpty
                            ? hook.name
                            : tr('Webhook #{id}', {'id': hook.id}),
                        style: t.titleSmall),
                    Pill(hook.active ? 'Active' : 'Inactive',
                        tone: hook.active ? Tone.success : Tone.neutral,
                        dot: true),
                    if (hook.hasSecret)
                      Pill(tr('Signed'), icon: LucideIcons.lock),
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(hook.url,
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        color: c.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final e in events) Pill(e)],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(formatDate(hook.createdAt), style: t.bodySmall),
          ),
          const SizedBox(width: 6),
          if (widget.v2) ...[
            IconButton(
              tooltip: tr('Send a test event'),
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const ButtonSpinner()
                  : const Icon(LucideIcons.send, size: 16),
            ),
            IconButton(
              tooltip: tr('Delivery history'),
              icon: const Icon(LucideIcons.listChecks, size: 16),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _DeliveriesDialog(
                    hook: hook, load: () => ctrl.deliveries(hook.id)),
              ),
            ),
            IconButton(
              tooltip: tr('Edit'),
              icon: const Icon(LucideIcons.pencil, size: 16),
              onPressed: _edit,
            ),
          ],
          IconButton(
            tooltip: tr('Delete webhook'),
            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
            onPressed: () async {
              final ok = await confirm(context,
                  title: tr('Delete webhook'),
                  message: tr('Stop sending events to this URL?'),
                  detail: hook.url);
              if (ok && context.mounted) {
                await runAction(context, () => ctrl.deleteWebhook(hook.id),
                    success: 'Webhook deleted');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DeliveriesDialog extends StatefulWidget {
  final Webhook hook;
  final Future<List<WebhookDelivery>> Function() load;
  const _DeliveriesDialog({required this.hook, required this.load});

  @override
  State<_DeliveriesDialog> createState() => _DeliveriesDialogState();
}

class _DeliveriesDialogState extends State<_DeliveriesDialog> {
  List<WebhookDelivery>? _items;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final r = await widget.load();
      if (mounted) setState(() => _items = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final items = _items;

    Widget body;
    if (_error != null) {
      body = Callout(_error!.message, tone: Tone.danger);
    } else if (items == null) {
      body = const LoadingView();
    } else if (items.isEmpty) {
      body = Text(tr('No deliveries yet. Use “Send a test event” to try it.'),
          style: t.bodyMedium);
    } else {
      final ok = items.where((d) => d.ok).length;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('{ok} of {n} recent deliveries succeeded', {'ok': ok, 'n': items.length}),
              style: t.labelLarge),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            items[i].ok
                                ? LucideIcons.circleCheck
                                : LucideIcons.circleX,
                            size: 16,
                            color: items[i].ok ? c.success : c.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${items[i].eventType} · ${items[i].objectKey}',
                                  style: t.bodyLarge),
                              Text(
                                items[i].error.isNotEmpty
                                    ? items[i].error
                                    : 'HTTP ${items[i].statusCode} · ${items[i].durationMs} ms'
                                        '${items[i].attempt > 1 ? ' · attempt ${items[i].attempt}' : ''}',
                                style: t.bodySmall?.copyWith(
                                    color: items[i].ok ? null : c.danger),
                              ),
                            ],
                          ),
                        ),
                        Text(formatRelative(items[i].createdAt),
                            style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return AppDialog(
      title: tr('Deliveries'),
      subtitle: widget.hook.url,
      icon: LucideIcons.listChecks,
      width: 640,
      content: body,
      actions: [
        TextButton.icon(
          onPressed: _reload,
          icon: const Icon(LucideIcons.refreshCw, size: 15),
          label: Text(tr('Refresh')),
        ),
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(tr('Close'))),
      ],
    );
  }
}
