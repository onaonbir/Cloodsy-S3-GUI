import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/presign.dart';
import '../../models/credential.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

// ============================================================ Share link

const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'bmp'};

/// Builds a link to an object: a direct URL for public-read buckets, or a
/// time-limited presigned URL signed with one of the bucket's access keys.
Future<void> showShareDialog(
  BuildContext context, {
  required String bucket,
  required String objectKey,
  required String? endpoint,
  required bool publicRead,
  required List<Credential> credentials,
  String region = 'us-east-1',
}) =>
    showDialog(
      context: context,
      builder: (_) => _ShareDialog(
        bucket: bucket,
        objectKey: objectKey,
        endpoint: endpoint,
        publicRead: publicRead,
        credentials: credentials,
        region: region,
      ),
    );

class _ShareDialog extends StatefulWidget {
  final String bucket, objectKey, region;
  final String? endpoint;
  final bool publicRead;
  final List<Credential> credentials;

  const _ShareDialog({
    required this.bucket,
    required this.objectKey,
    required this.endpoint,
    required this.publicRead,
    required this.credentials,
    required this.region,
  });

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  static const _expiries = <(String, Duration)>[
    ('15 min', Duration(minutes: 15)),
    ('1 hour', Duration(hours: 1)),
    ('1 day', Duration(days: 1)),
    ('7 days', Duration(days: 7)), // SigV4 maximum
  ];

  late final _endpoint = TextEditingController(text: widget.endpoint ?? '');
  late bool _signed = !widget.publicRead;
  Duration _expiry = const Duration(hours: 1);
  Credential? _cred;
  final _w = TextEditingController();
  final _h = TextEditingController();
  final _q = TextEditingController();

  bool get _isImage {
    final name = widget.objectKey.split('/').last;
    final i = name.lastIndexOf('.');
    return i > 0 && _imageExts.contains(name.substring(i + 1).toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    // Prefer a read-only key: a leaked link then can't be used to write.
    final keys = widget.credentials.where((c) => (c.secretKey ?? '').isNotEmpty);
    _cred = keys.where((c) => c.isReadOnly).firstOrNull ?? keys.firstOrNull;
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _w.dispose();
    _h.dispose();
    _q.dispose();
    super.dispose();
  }

  Map<String, String> get _imageParams => {
        if (_w.text.trim().isNotEmpty) 'w': _w.text.trim(),
        if (_h.text.trim().isNotEmpty) 'h': _h.text.trim(),
        if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
      };

  String? get _link {
    final ep = _endpoint.text.trim();
    if (ep.isEmpty || Uri.tryParse(ep)?.hasScheme != true) return null;
    final base = Presigner.objectUrl(ep, widget.bucket, widget.objectKey);
    if (!_signed) {
      final p = _imageParams;
      return p.isEmpty ? base.toString() : base.replace(queryParameters: p).toString();
    }
    final c = _cred;
    if (c == null) return null;
    return Presigner.presign(
      url: base,
      accessKey: c.accessKey,
      secretKey: c.secretKey!,
      region: widget.region,
      expires: _expiry,
      extraQuery: _imageParams,
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final usable =
        widget.credentials.where((c) => (c.secretKey ?? '').isNotEmpty).toList();
    final link = _link;

    return AppDialog(
      title: tr('Share link'),
      subtitle: widget.objectKey,
      icon: LucideIcons.link,
      width: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: true,
                  icon: Icon(LucideIcons.timer, size: 14),
                  label: Text(tr('Expiring link'))),
              ButtonSegment(
                  value: false,
                  enabled: widget.publicRead,
                  icon: const Icon(LucideIcons.globe, size: 14),
                  label: Text(tr('Public URL'))),
            ],
            selected: {_signed},
            onSelectionChanged: (s) => setState(() => _signed = s.first),
          ),
          if (!widget.publicRead) ...[
            const SizedBox(height: 6),
            Text(tr('Public URLs need “Public read” on the bucket.'),
                style: t.bodySmall),
          ],
          const SizedBox(height: 16),
          if (_signed) ...[
            if (usable.isEmpty)
              Callout(
                  tr('This bucket has no access key yet. Create one under '
                  '“Access keys” to sign links.'),
                  tone: Tone.warning)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Credential>(
                      initialValue: _cred,
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: tr('Sign with key')),
                      items: [
                        for (final c in usable)
                          DropdownMenuItem(
                            value: c,
                            child: Text(
                              '${c.name.isNotEmpty ? c.name : c.accessKey}'
                              '${c.isReadOnly ? ' · ${tr('read only')}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (c) => setState(() => _cred = c),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<Duration>(
                      initialValue: _expiry,
                      decoration:
                          InputDecoration(labelText: tr('Expires in')),
                      items: [
                        for (final (label, d) in _expiries)
                          DropdownMenuItem(value: d, child: Text(label)),
                      ],
                      onChanged: (d) => setState(() => _expiry = d!),
                    ),
                  ),
                ],
              ),
              if (_cred != null && !_cred!.isReadOnly) ...[
                const SizedBox(height: 10),
                Callout(
                    tr('Signed with a read & write key. The link only allows '
                    'downloading this object, but a read-only key is safer.'),
                    tone: Tone.neutral),
              ],
            ],
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _endpoint,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr('S3 endpoint'),
              helperText: tr('The address clients use to reach the S3 API'),
            ),
          ),
          if (_isImage) ...[
            const SizedBox(height: 16),
            Text(tr('Image resize (optional)'), style: t.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, ctrl) in [
                  ('Width', _w),
                  ('Height', _h),
                  ('Quality', _q),
                ]) ...[
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: label),
                    ),
                  ),
                  if (label != 'Quality') const SizedBox(width: 10),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (link != null)
            CopyValue(label: tr('Link'), value: link)
          else
            Callout(tr('Enter a valid S3 endpoint to build the link.'),
                tone: Tone.neutral),
        ],
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(tr('Done'))),
      ],
    );
  }
}

// ============================================================ Move / copy

enum TransferMode { copy, move }

/// Asks for a destination; [run] receives (destBucket, destKeyOrPrefix, move).
Future<bool?> showMoveCopyDialog(
  BuildContext context, {
  required String bucket,
  required String sourceKey,
  required bool isFolder,
  required List<String> buckets,
  TransferMode mode = TransferMode.move,
  bool renameOnly = false,
  int? count,
  required Future<String> Function(String destBucket, String dest, bool move)
      run,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _MoveCopyDialog(
        bucket: bucket,
        sourceKey: sourceKey,
        isFolder: isFolder,
        buckets: buckets,
        mode: mode,
        renameOnly: renameOnly,
        count: count,
        run: run,
      ),
    );

class _MoveCopyDialog extends StatefulWidget {
  final String bucket, sourceKey;
  final bool isFolder, renameOnly;
  final List<String> buckets;
  final TransferMode mode;

  /// Set when moving a selection of [count] objects into a folder;
  /// [sourceKey] is then the current folder (default destination).
  final int? count;
  final Future<String> Function(String, String, bool) run;

  const _MoveCopyDialog({
    required this.bucket,
    required this.sourceKey,
    required this.isFolder,
    required this.buckets,
    required this.mode,
    required this.renameOnly,
    required this.run,
    this.count,
  });

  @override
  State<_MoveCopyDialog> createState() => _MoveCopyDialogState();
}

class _MoveCopyDialogState extends State<_MoveCopyDialog> {
  late TransferMode _mode = widget.mode;
  late String _destBucket = widget.bucket;
  late final TextEditingController _dest;
  bool _busy = false;
  String? _error;

  String get _parent {
    final k = widget.isFolder
        ? widget.sourceKey.substring(0, widget.sourceKey.length - 1)
        : widget.sourceKey;
    final i = k.lastIndexOf('/');
    return i < 0 ? '' : k.substring(0, i + 1);
  }

  String get _name {
    final k = widget.isFolder
        ? widget.sourceKey.substring(0, widget.sourceKey.length - 1)
        : widget.sourceKey;
    return k.split('/').last;
  }

  @override
  void initState() {
    super.initState();
    _dest = TextEditingController(
        text: widget.renameOnly ? _name : widget.sourceKey);
  }

  @override
  void dispose() {
    _dest.dispose();
    super.dispose();
  }

  String get _target {
    var v = _dest.text.trim();
    if (widget.renameOnly) v = '$_parent$v';
    if (widget.isFolder && v.isNotEmpty && !v.endsWith('/')) v = '$v/';
    return v;
  }

  Future<void> _submit() async {
    final target = _target;
    final multi = widget.count != null;
    if ((!multi && _dest.text.trim().isEmpty) || target.startsWith('/')) {
      setState(() => _error = 'Enter a destination key without a leading “/”');
      return;
    }
    if (multi) {
      if (target == widget.sourceKey && _destBucket == widget.bucket) {
        setState(() => _error = 'Pick a different folder or bucket');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final msg =
            await widget.run(_destBucket, target, _mode == TransferMode.move);
        if (!mounted) return;
        showToast(context, msg);
        Navigator.pop(context, true);
      } on ApiException catch (e) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    }
    if (widget.renameOnly && _dest.text.contains('/')) {
      setState(() => _error = 'A name can’t contain “/”');
      return;
    }
    if (target == widget.sourceKey && _destBucket == widget.bucket) {
      setState(() => _error = 'Destination is the same as the source');
      return;
    }
    if (widget.isFolder &&
        _destBucket == widget.bucket &&
        target.startsWith(widget.sourceKey)) {
      setState(() => _error = 'Can’t move a folder into itself');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg =
          await widget.run(_destBucket, target, _mode == TransferMode.move);
      if (!mounted) return;
      showToast(context, msg);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final what = widget.count != null
        ? tr('{n} objects', {'n': widget.count})
        : widget.isFolder
            ? tr('folder')
            : tr('object');
    return AppDialog(
      title: widget.renameOnly
          ? tr('Rename {what}', {'what': what})
          : tr(_mode == TransferMode.move ? 'Move {what}' : 'Copy {what}',
              {'what': what}),
      subtitle: widget.count != null
          ? tr('Copied on the server; nothing is downloaded.')
          : widget.isFolder
              ? tr('Every object under “{p}” is processed on the server.', {'p': widget.sourceKey})
              : null,
      icon: widget.renameOnly
          ? LucideIcons.pencil
          : _mode == TransferMode.move
              ? LucideIcons.folderInput
              : LucideIcons.copy,
      width: 520,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.renameOnly) ...[
            SegmentedButton<TransferMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: TransferMode.move,
                    icon: Icon(LucideIcons.folderInput, size: 14),
                    label: Text(tr('Move'))),
                ButtonSegment(
                    value: TransferMode.copy,
                    icon: Icon(LucideIcons.copy, size: 14),
                    label: Text(tr('Copy'))),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _destBucket,
              decoration: InputDecoration(labelText: tr('Destination bucket')),
              items: [
                for (final b in widget.buckets)
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: (b) => setState(() => _destBucket = b!),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _dest,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.renameOnly
                  ? tr('New name')
                  : widget.isFolder || widget.count != null
                      ? tr('Destination folder (empty = bucket root)')
                      : tr('Destination key'),
              prefixText: widget.renameOnly && _parent.isNotEmpty ? _parent : null,
            ),
            onSubmitted: (_) => _submit(),
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const ButtonSpinner()
              : Text(widget.renameOnly
                  ? tr('Rename')
                  : _mode == TransferMode.move
                      ? tr('Move')
                      : tr('Copy')),
        ),
      ],
    );
  }
}

// ============================================================ Metadata

Future<bool?> showMetadataDialog(
  BuildContext context, {
  required String objectKey,
  required String contentType,
  required Map<String, String> metadata,
  required bool versioned,
  required Future<void> Function(String contentType, Map<String, String> meta)
      save,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _MetadataDialog(
        objectKey: objectKey,
        contentType: contentType,
        metadata: metadata,
        versioned: versioned,
        save: save,
      ),
    );

class _MetadataDialog extends StatefulWidget {
  final String objectKey, contentType;
  final Map<String, String> metadata;
  final bool versioned;
  final Future<void> Function(String, Map<String, String>) save;

  const _MetadataDialog({
    required this.objectKey,
    required this.contentType,
    required this.metadata,
    required this.versioned,
    required this.save,
  });

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  late final _type = TextEditingController(text: widget.contentType);
  late final List<(TextEditingController, TextEditingController)> _rows = [
    for (final e in widget.metadata.entries)
      (TextEditingController(text: e.key), TextEditingController(text: e.value)),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _type.dispose();
    for (final (k, v) in _rows) {
      k.dispose();
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final meta = <String, String>{};
    for (final (k, v) in _rows) {
      final key = k.text.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(key)) {
        setState(() => _error =
            tr('Metadata keys may only contain letters, digits and “-” ({key})', {'key': key}));
        return;
      }
      meta[key] = v.text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(_type.text.trim(), meta);
      if (mounted) Navigator.pop(context, true);
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
      title: tr('Edit metadata'),
      subtitle: widget.objectKey,
      icon: LucideIcons.tags,
      width: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _type,
            decoration: InputDecoration(
                labelText: tr('Content-Type'), hintText: tr('application/octet-stream')),
          ),
          const SizedBox(height: 18),
          Text(tr('User metadata (x-amz-meta-*)'),
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _rows[i].$1,
                          decoration: InputDecoration(hintText: tr('key')))),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _rows[i].$2,
                          decoration: InputDecoration(hintText: tr('value')))),
                  IconButton(
                    tooltip: tr('Remove'),
                    icon: const Icon(LucideIcons.x, size: 15),
                    onPressed: () => setState(() => _rows.removeAt(i)),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _rows
                .add((TextEditingController(), TextEditingController()))),
            icon: const Icon(LucideIcons.plus, size: 15),
            label: Text(tr('Add field')),
          ),
          if (widget.versioned) ...[
            const SizedBox(height: 8),
            Callout(
                tr('The bucket is versioned: saving creates a new version of the '
                'object with the same content.'),
                tone: Tone.neutral),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
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
          child: _busy ? const ButtonSpinner() : Text(tr('Save')),
        ),
      ],
    );
  }
}
