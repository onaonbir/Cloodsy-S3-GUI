import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Mirrors the server's rule (admin/buckets.go validBucketName):
/// 3–63 chars of lowercase letters, digits and hyphens, starting and ending
/// with a letter or digit. Dots are not accepted by Cloodsy S3.
String? validateBucketName(String name) {
  if (name.length < 3 || name.length > 63) return 'Use 3–63 characters';
  if (!RegExp(r'^[a-z0-9][a-z0-9-]*[a-z0-9]$').hasMatch(name)) {
    return 'Lowercase letters, digits and hyphens only; '
        'start and end with a letter or digit';
  }
  return null;
}

/// Asks for bucket details and runs [create]. Returns the new name.
Future<String?> showCreateBucketDialog(BuildContext context,
        Future<void> Function(String name, String storageDir) create) =>
    showDialog<String>(
        context: context, builder: (_) => _CreateBucketDialog(create));

class _CreateBucketDialog extends StatefulWidget {
  final Future<void> Function(String, String) create;
  const _CreateBucketDialog(this.create);

  @override
  State<_CreateBucketDialog> createState() => _CreateBucketDialogState();
}

class _CreateBucketDialogState extends State<_CreateBucketDialog> {
  final _name = TextEditingController();
  final _dir = TextEditingController();
  bool _customDir = false;
  bool _busy = false;
  String? _nameError;
  String? _serverError;

  @override
  void dispose() {
    _name.dispose();
    _dir.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final err = validateBucketName(name);
    if (err != null) {
      setState(() => _nameError = err);
      return;
    }
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      await widget.create(name, _customDir ? _dir.text.trim() : '');
      if (mounted) Navigator.pop(context, name);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _serverError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: tr('Create bucket'),
      icon: LucideIcons.package,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Bucket name'),
              hintText: tr('my-bucket'),
              errorText: _nameError,
              helperText: tr('Lowercase letters, digits and hyphens'),
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _customDir,
            onChanged: (v) => setState(() => _customDir = v),
            title: Text(tr('Custom storage directory')),
            subtitle: Text(tr('Store this bucket outside the default data dir')),
          ),
          if (_customDir)
            TextField(
              controller: _dir,
              decoration: InputDecoration(
                labelText: tr('Absolute path on the server'),
                hintText: r'/mnt/ssd/buckets or D:\data',
              ),
            ),
          if (_serverError != null) ...[
            const SizedBox(height: 14),
            Callout(_serverError!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const ButtonSpinner() : Text(tr('Create bucket')),
        ),
      ],
    );
  }
}

/// Quota editor; [apply] receives bytes (0 = unlimited).
Future<void> showQuotaDialog(BuildContext context,
        {required int current, required Future<void> Function(int) apply}) =>
    showDialog(
        context: context,
        builder: (_) => _QuotaDialog(current: current, apply: apply));

class _QuotaDialog extends StatefulWidget {
  final int current;
  final Future<void> Function(int) apply;
  const _QuotaDialog({required this.current, required this.apply});

  @override
  State<_QuotaDialog> createState() => _QuotaDialogState();
}

class _QuotaDialogState extends State<_QuotaDialog> {
  late final TextEditingController _value;
  String _unit = 'GB';
  bool _busy = false;
  String? _error;

  static const _units = ['MB', 'GB', 'TB'];

  @override
  void initState() {
    super.initState();
    var text = '';
    if (widget.current > 0) {
      const gb = 1024 * 1024 * 1024;
      if (widget.current >= 1024 * gb && widget.current % (1024 * gb) == 0) {
        _unit = 'TB';
        text = '${widget.current ~/ (1024 * gb)}';
      } else if (widget.current >= gb) {
        _unit = 'GB';
        text = _trim(widget.current / gb);
      } else {
        _unit = 'MB';
        text = _trim(widget.current / (1024 * 1024));
      }
    }
    _value = TextEditingController(text: text);
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _run(int bytes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.apply(bytes);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  void _save() {
    final bytes = parseSize(_value.text, defaultUnit: _unit);
    if (bytes == null || bytes <= 0) {
      setState(() => _error = 'Enter a positive size');
      return;
    }
    _run(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: tr('Storage quota'),
      subtitle: tr('Uploads that would exceed the quota are rejected.'),
      icon: LucideIcons.gauge,
      width: 420,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('Size')),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final u in _units) ButtonSegment(value: u, label: Text(u)),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Callout(_error!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        if (widget.current > 0)
          TextButton(
            onPressed: _busy ? null : () => _run(0),
            child: Text(tr('Remove quota')),
          ),
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const ButtonSpinner() : Text(tr('Save')),
        ),
      ],
    );
  }
}

/// Storage directory editor (moves the bucket's data on the server).
Future<void> showStorageDialog(BuildContext context,
        {required String current,
        required Future<void> Function(String) apply}) =>
    showDialog(
        context: context,
        builder: (_) => _StorageDialog(current: current, apply: apply));

class _StorageDialog extends StatefulWidget {
  final String current;
  final Future<void> Function(String) apply;
  const _StorageDialog({required this.current, required this.apply});

  @override
  State<_StorageDialog> createState() => _StorageDialogState();
}

class _StorageDialogState extends State<_StorageDialog> {
  late final _ctrl = TextEditingController(text: widget.current);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.apply(_ctrl.text.trim());
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
      title: tr('Storage directory'),
      subtitle: tr('Existing objects are moved to the new location. Large '
          'buckets can take a while; the bucket is locked meanwhile.'),
      icon: LucideIcons.hardDrive,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Absolute path on the server'),
              hintText: tr('Leave empty for the default directory'),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Callout(_error!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  ButtonSpinner(),
                  SizedBox(width: 8),
                  Text(tr('Moving…')),
                ])
              : Text(tr('Move data')),
        ),
      ],
    );
  }
}
