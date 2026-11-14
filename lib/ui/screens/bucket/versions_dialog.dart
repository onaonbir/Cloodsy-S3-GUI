import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../models/s3_object.dart';
import '../../../state/objects_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

Future<void> showVersionsDialog(
  BuildContext context,
  ObjectsController ctrl,
  S3Object object, {
  void Function(ObjectVersion)? onDownload,
}) =>
    showDialog(
      context: context,
      builder: (_) =>
          _VersionsDialog(ctrl: ctrl, object: object, onDownload: onDownload),
    );

class _VersionsDialog extends StatefulWidget {
  final ObjectsController ctrl;
  final S3Object object;
  final void Function(ObjectVersion)? onDownload;

  const _VersionsDialog(
      {required this.ctrl, required this.object, this.onDownload});

  @override
  State<_VersionsDialog> createState() => _VersionsDialogState();
}

class _VersionsDialogState extends State<_VersionsDialog> {
  List<ObjectVersion>? _versions;
  ApiException? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await widget.ctrl.versions(widget.object.key);
      if (mounted) setState(() => _versions = v);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _delete(ObjectVersion v) async {
    final ok = await confirm(context,
        title: tr('Delete version'),
        message: v.isDeleteMarker
            ? tr('Remove this delete marker? The previous version becomes the '
                'current one again.')
            : tr('Permanently delete this version? This cannot be undone.'),
        detail: v.versionId);
    if (!ok || !mounted) return;
    final done = await runAction(
        context,
        () => widget.ctrl
            .deleteObject(widget.object.key, versionId: v.versionId),
        success: v.isDeleteMarker ? 'Delete marker removed' : 'Version deleted');
    if (done) {
      _changed = true;
      await _load();
    }
  }

  @override
  void dispose() {
    if (_changed) widget.ctrl.refresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final versions = _versions;

    Widget body;
    if (_error != null) {
      body = Callout(_error!.message, tone: Tone.danger);
    } else if (versions == null) {
      body = const LoadingView();
    } else if (versions.isEmpty) {
      body = Text(tr('No versions recorded.'), style: t.bodyMedium);
    } else {
      body = Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < versions.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _VersionRow(
                v: versions[i],
                onDownload: widget.onDownload == null || versions[i].isDeleteMarker
                    ? null
                    : () => widget.onDownload!(versions[i]),
                onDelete: () => _delete(versions[i]),
              ),
            ],
          ],
        ),
      );
    }

    return AppDialog(
      title: tr('Versions'),
      subtitle: widget.object.key,
      icon: LucideIcons.history,
      width: 620,
      content: body,
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(tr('Close'))),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  final ObjectVersion v;
  final VoidCallback? onDownload;
  final VoidCallback onDelete;

  const _VersionRow(
      {required this.v, required this.onDownload, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Icon(v.isDeleteMarker ? LucideIcons.fileX : LucideIcons.file,
              size: 18, color: v.isDeleteMarker ? c.warning : c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        v.isNullVersion ? 'null (unversioned)' : v.versionId,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 12,
                            color: c.foreground),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (v.isLatest) Pill(tr('Current'), tone: Tone.success),
                    if (v.isDeleteMarker) ...[
                      const SizedBox(width: 6),
                      Pill(tr('Delete marker'), tone: Tone.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  v.isDeleteMarker
                      ? formatDateTime(v.lastModified)
                      : '${formatBytes(v.size)} · ${formatDateTime(v.lastModified)}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Copy version id'),
            icon: const Icon(LucideIcons.copy, size: 15),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: v.versionId));
              showToast(context, tr('Version id copied'));
            },
          ),
          if (onDownload != null)
            IconButton(
              tooltip: tr('Download this version'),
              icon: const Icon(LucideIcons.download, size: 15),
              onPressed: onDownload,
            ),
          IconButton(
            tooltip: tr('Delete version'),
            icon: Icon(LucideIcons.trash2, size: 15, color: c.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
