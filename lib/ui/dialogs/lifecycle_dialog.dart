import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../models/lifecycle_rule.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Create or edit a lifecycle rule with every action the server supports.
Future<void> showLifecycleRuleDialog(BuildContext context,
        {LifecycleRule? existing,
        required bool versioned,
        required Future<void> Function(LifecycleRule) save}) =>
    showDialog(
      context: context,
      builder: (_) => _RuleDialog(
          existing: existing, versioned: versioned, save: save),
    );

class _RuleDialog extends StatefulWidget {
  final LifecycleRule? existing;
  final bool versioned;
  final Future<void> Function(LifecycleRule) save;
  const _RuleDialog(
      {this.existing, required this.versioned, required this.save});

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final LifecycleRule? r = widget.existing;
  late final _name = TextEditingController(text: r?.name ?? '');
  late final _prefix = TextEditingController(text: r?.prefix ?? '');
  late bool _enabled = r?.enabled ?? true;
  late bool _expire = (r?.expirationDays ?? 30) > 0;
  late final _expireDays =
      TextEditingController(text: '${(r?.expirationDays ?? 0) > 0 ? r!.expirationDays : 30}');
  late bool _noncurrent = (r?.noncurrentDays ?? 0) > 0;
  late final _noncurrentDays =
      TextEditingController(text: '${(r?.noncurrentDays ?? 0) > 0 ? r!.noncurrentDays : 30}');
  late bool _abort = (r?.abortMultipartDays ?? 0) > 0;
  late final _abortDays =
      TextEditingController(text: '${(r?.abortMultipartDays ?? 0) > 0 ? r!.abortMultipartDays : 7}');
  late bool _markers = r?.expireDeleteMarkers ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _prefix, _expireDays, _noncurrentDays, _abortDays]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _days(bool on, TextEditingController c) {
    if (!on) return 0;
    final v = int.tryParse(c.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  Future<void> _submit() async {
    final e = _days(_expire, _expireDays);
    final n = _days(_noncurrent, _noncurrentDays);
    final a = _days(_abort, _abortDays);
    if (e == null || n == null || a == null) {
      setState(() => _error = 'Days must be positive whole numbers');
      return;
    }
    if (e == 0 && n == 0 && a == 0 && !_markers) {
      setState(() => _error = 'Pick at least one action');
      return;
    }
    // S3 rule (enforced by the server too): an expiration rule creates
    // delete markers, so it can't also be the rule that removes them.
    if (e > 0 && _markers) {
      setState(() => _error =
          '“Expire objects” and “Remove orphan delete markers” need separate rules');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(LifecycleRule(
        id: r?.id ?? 0,
        name: _name.text.trim(),
        prefix: _prefix.text.trim(),
        enabled: _enabled,
        expirationDays: e,
        noncurrentDays: n,
        abortMultipartDays: a,
        expireDeleteMarkers: _markers,
      ));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (err) {
      setState(() {
        _busy = false;
        _error = err.message;
      });
    }
  }

  Widget _action({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
    TextEditingController? days,
    bool dim = false,
  }) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          const SizedBox(width: 6),
          Expanded(
            child: Opacity(
              opacity: dim ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyLarge),
                  Text(subtitle, style: t.bodySmall),
                ],
              ),
            ),
          ),
          if (days != null)
            SizedBox(
              width: 110,
              child: TextField(
                controller: days,
                enabled: value,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(suffixText: tr('days')),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: r == null ? 'New lifecycle rule' : 'Edit rule',
      subtitle: tr('Rules run periodically on the server.'),
      icon: LucideIcons.timer,
      width: 580,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: r == null,
                  decoration: InputDecoration(
                      labelText: tr('Name (optional)'), hintText: tr('Log cleanup')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _prefix,
                  decoration: InputDecoration(
                      labelText: tr('Prefix'), hintText: tr('logs/ (empty = all)')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _action(
            value: _expire,
            onChanged: (v) => setState(() => _expire = v),
            title: tr('Expire objects'),
            subtitle: widget.versioned
                ? tr('Adds a delete marker; older versions stay until removed')
                : tr('Deletes objects older than'),
            days: _expireDays,
          ),
          _action(
            value: _noncurrent,
            onChanged: (v) => setState(() => _noncurrent = v),
            title: tr('Delete old versions'),
            subtitle: widget.versioned
                ? tr('Removes versions this long after they were replaced')
                : tr('Only relevant for versioned buckets'),
            days: _noncurrentDays,
            dim: !widget.versioned,
          ),
          _action(
            value: _abort,
            onChanged: (v) => setState(() => _abort = v),
            title: tr('Abort incomplete uploads'),
            subtitle: tr('Frees space held by multipart uploads that never finished'),
            days: _abortDays,
          ),
          _action(
            value: _markers,
            onChanged: (v) => setState(() => _markers = v),
            title: tr('Remove orphan delete markers'),
            subtitle: tr('Delete markers with no versions left behind them'),
            dim: !widget.versioned,
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text(tr('Rule enabled')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
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
              : Text(r == null ? 'Add rule' : 'Save'),
        ),
      ],
    );
  }
}
