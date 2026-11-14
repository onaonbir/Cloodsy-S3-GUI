import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../models/credential.dart';
import '../../models/webhook.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Creates an access key and then shows it once with copy buttons.
Future<void> showCreateCredentialDialog(
  BuildContext context, {
  required String bucket,
  required Future<Credential> Function(String label, String permission) create,
}) async {
  final cred = await showDialog<Credential>(
    context: context,
    builder: (_) => _CreateCredentialDialog(bucket: bucket, create: create),
  );
  if (cred != null && context.mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: tr('Access key created'),
        subtitle: tr('Use these with any S3 SDK or client. You can view the '
            'secret again later from this list.'),
        icon: LucideIcons.keyRound,
        iconTone: Tone.success,
        content: Column(
          children: [
            CopyValue(label: tr('Access key'), value: cred.accessKey),
            const SizedBox(height: 14),
            CopyValue(
                label: tr('Secret key'),
                value: cred.secretKey ?? '',
                secret: false),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Done'))),
        ],
      ),
    );
  }
}

class _CreateCredentialDialog extends StatefulWidget {
  final String bucket;
  final Future<Credential> Function(String, String) create;
  const _CreateCredentialDialog({required this.bucket, required this.create});

  @override
  State<_CreateCredentialDialog> createState() =>
      _CreateCredentialDialogState();
}

class _CreateCredentialDialogState extends State<_CreateCredentialDialog> {
  final _label = TextEditingController();
  String _permission = 'read-write';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await widget.create(_label.text.trim(), _permission);
      if (mounted) Navigator.pop(context, cred);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: tr('New access key'),
      subtitle: tr('Scoped to the bucket “{b}”.', {'b': widget.bucket}),
      icon: LucideIcons.keyRound,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Label (optional)'),
              hintText: tr('e.g. Backend service'),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(tr('Permission'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: 'read-write',
                  icon: Icon(LucideIcons.pencil, size: 14),
                  label: Text(tr('Read & write'))),
              ButtonSegment(
                  value: 'read-only',
                  icon: Icon(LucideIcons.eye, size: 14),
                  label: Text(tr('Read only'))),
            ],
            selected: {_permission},
            onSelectionChanged: (s) => setState(() => _permission = s.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Callout(_error!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const ButtonSpinner() : Text(tr('Create key')),
        ),
      ],
    );
  }
}

// ============================================================ Lifecycle

Future<void> showLifecycleDialog(BuildContext context,
        Future<void> Function(String label, String prefix, int days) add) =>
    showDialog(context: context, builder: (_) => _LifecycleDialog(add));

class _LifecycleDialog extends StatefulWidget {
  final Future<void> Function(String, String, int) add;
  const _LifecycleDialog(this.add);

  @override
  State<_LifecycleDialog> createState() => _LifecycleDialogState();
}

class _LifecycleDialogState extends State<_LifecycleDialog> {
  final _label = TextEditingController();
  final _prefix = TextEditingController();
  final _days = TextEditingController(text: '30');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _prefix.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days <= 0) {
      setState(() => _error = 'Days must be a positive whole number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.add(_label.text.trim(), _prefix.text.trim(), days);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: tr('Expiration rule'),
      subtitle: tr('Objects older than the given age are deleted automatically.'),
      icon: LucideIcons.timer,
      content: Column(
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            decoration: InputDecoration(
                labelText: tr('Name (optional)'), hintText: tr('e.g. Log cleanup')),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _prefix,
                  decoration: InputDecoration(
                    labelText: tr('Prefix'),
                    hintText: tr('logs/'),
                    helperText: tr('Empty applies to every object'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr('Expire after'), suffixText: tr('days')),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Callout(_error!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const ButtonSpinner() : Text(tr('Add rule')),
        ),
      ],
    );
  }
}

// ============================================================ Webhooks

/// Event types the server emits (see webhook/dispatcher.go).
const webhookEvents = <(String, String)>[
  ('s3:ObjectCreated:*', 'All object created events'),
  ('s3:ObjectCreated:Put', 'Put'),
  ('s3:ObjectCreated:Copy', 'Copy'),
  ('s3:ObjectCreated:CompleteMultipartUpload', 'Multipart upload completed'),
  ('s3:ObjectRemoved:*', 'All object removed events'),
  ('s3:ObjectRemoved:Delete', 'Delete'),
  ('s3:ObjectRemoved:DeleteMarkerCreated', 'Delete marker created'),
];

/// Saves a webhook. [secret] is null when it should stay unchanged (edit).
typedef WebhookSave = Future<void> Function({
  required String label,
  required String url,
  required String events,
  required bool active,
  String? secret,
});

/// Add (existing == null) or edit a webhook.
Future<void> showWebhookDialog(BuildContext context, WebhookSave save,
        {Webhook? existing, bool canEdit = false}) =>
    showDialog(
        context: context,
        builder: (_) =>
            _WebhookDialog(save, existing: existing, canEdit: canEdit));

class _WebhookDialog extends StatefulWidget {
  final WebhookSave save;
  final Webhook? existing;
  final bool canEdit;
  const _WebhookDialog(this.save, {this.existing, this.canEdit = false});

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  late final Webhook? _w = widget.existing;
  late final _label = TextEditingController(text: _w?.name ?? '');
  late final _url = TextEditingController(text: _w?.url ?? '');
  final _secret = TextEditingController();
  late bool _all = _w == null || _w.eventTypes.trim() == '*';
  late final Set<String> _events = _w == null || _all
      ? {}
      : _w.eventTypes.split(',').map((e) => e.trim()).toSet();
  late bool _active = _w?.active ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  String get _eventString {
    if (_all) return '*';
    final list = _events.toList();
    // A wildcard makes its specific siblings redundant.
    for (final w in list.where((e) => e.endsWith(':*')).toList()) {
      final base = w.substring(0, w.length - 1);
      list.removeWhere((e) => e != w && e.startsWith(base));
    }
    return list.join(',');
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(() => _error = 'Enter an http:// or https:// URL');
      return;
    }
    if (!_all && _events.isEmpty) {
      setState(() => _error = 'Pick at least one event');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(
          label: _label.text.trim(),
          url: url,
          events: _eventString,
          active: _active,
          // Editing: an empty field keeps the stored secret.
          secret: _w != null && _secret.text.isEmpty ? null : _secret.text);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppDialog(
      title: _w == null ? 'Add webhook' : 'Edit webhook',
      subtitle: tr('The server POSTs a JSON event to this URL.'),
      icon: LucideIcons.webhook,
      width: 500,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
                labelText: tr('Endpoint URL'),
                hintText: tr('https://example.com/hooks/s3')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _label,
                  decoration:
                      InputDecoration(labelText: tr('Name (optional)')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _secret,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: tr('Signing secret (optional)'),
                    hintText: _w?.hasSecret == true
                        ? tr('Set · leave empty to keep')
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tr('Events'), style: t.labelMedium),
          const SizedBox(height: 4),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _all,
            onChanged: (v) => setState(() => _all = v ?? true),
            title: Text(tr('All events')),
          ),
          if (!_all)
            for (final (value, label) in webhookEvents)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.only(
                    left: value.endsWith(':*') ? 0 : 28),
                controlAffinity: ListTileControlAffinity.leading,
                value: _events.contains(value),
                onChanged: (v) => setState(() =>
                    v == true ? _events.add(value) : _events.remove(value)),
                title: Text(label),
                subtitle: Text(value),
              ),
          if (widget.canEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: Text(tr('Active')),
              subtitle: Text(tr('Inactive webhooks receive no events')),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Callout(_error!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const ButtonSpinner()
              : Text(_w == null ? 'Add webhook' : 'Save'),
        ),
      ],
    );
  }
}
