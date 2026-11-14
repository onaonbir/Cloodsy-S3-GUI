import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/desktop.dart';
import '../../../core/format.dart';
import '../../../models/admin_extras.dart';
import '../../../models/s3_object.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/objects_controller.dart';
import '../../../state/server_controller.dart';
import '../../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'files_tab.dart' show fileIcon;
import '../../../core/i18n.dart';

const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'ico'};
const _textExts = {
  'txt', 'md', 'log', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml', 'toml',
  'ini', 'conf', 'env', 'js', 'mjs', 'ts', 'dart', 'go', 'py', 'rb', 'rs',
  'java', 'kt', 'c', 'h', 'cpp', 'cs', 'php', 'sh', 'ps1', 'sql', 'html',
  'htm', 'css', 'svg', 'srt', 'vtt',
};
const int _maxImageBytes = 25 * 1024 * 1024;
const int _maxTextBytes = 256 * 1024;
const int _maxPdfBytes = 60 * 1024 * 1024;

enum PreviewKind { image, text, pdf, media, none }

PreviewKind previewKind(S3Object o) {
  final ext = o.extension;
  final ct = o.contentType;
  if (_imageExts.contains(ext) || (ct.startsWith('image/') && ext != 'svg')) {
    return PreviewKind.image;
  }
  if (ext == 'pdf' || ct == 'application/pdf') return PreviewKind.pdf;
  if (_textExts.contains(ext) ||
      ct.startsWith('text/') ||
      ct.contains('json') ||
      ct.contains('xml')) {
    return PreviewKind.text;
  }
  if (ct.startsWith('video/') ||
      ct.startsWith('audio/') ||
      const {'mp4', 'mov', 'mkv', 'webm', 'avi', 'mp3', 'wav', 'flac', 'ogg', 'm4a'}
          .contains(ext)) {
    return PreviewKind.media;
  }
  return PreviewKind.none;
}

/// Callbacks into the file browser for actions that need its context
/// (download location, transfers, refresh after changes).
class ObjectActions {
  final void Function(S3Object o)? download;
  final void Function(S3Object o)? share;
  final void Function(S3Object o)? moveCopy;
  final void Function(S3Object o)? rename;
  final void Function(S3Object o, ObjectInfo? info)? editMetadata;
  final void Function(S3Object o)? versions;
  final void Function(S3Object o) delete;

  const ObjectActions({
    required this.delete,
    this.download,
    this.share,
    this.moveCopy,
    this.rename,
    this.editMetadata,
    this.versions,
  });
}

/// Right-hand details pane for one object: preview, where it lives on disk
/// and everything you can do with it.
class ObjectPanel extends StatefulWidget {
  final S3Object object;
  final ObjectActions actions;
  final VoidCallback onClose;

  const ObjectPanel({
    super.key,
    required this.object,
    required this.actions,
    required this.onClose,
  });

  @override
  State<ObjectPanel> createState() => _ObjectPanelState();
}

class _ObjectPanelState extends State<ObjectPanel> {
  ObjectInfo? _info;
  ApiException? _infoError;
  Uint8List? _bytes;
  String? _text;
  bool _textTruncated = false;
  bool _loadingPreview = false;
  String? _previewError;

  S3Object get o => widget.object;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ObjectPanel old) {
    super.didUpdateWidget(old);
    if (old.object.key != o.key || old.object.etag != o.etag) _load();
  }

  Future<void> _load() async {
    final status = context.read<ServerController>().status;
    final ctrl = context.read<ObjectsController>();
    setState(() {
      _info = null;
      _infoError = null;
      _bytes = null;
      _text = null;
      _previewError = null;
    });
    if (status?.canObjectInfo ?? false) {
      ctrl.info(o.key).then((i) {
        if (mounted && widget.object.key == i.key) setState(() => _info = i);
      }, onError: (Object e) {
        if (mounted && e is ApiException) setState(() => _infoError = e);
      });
    }
    if (!(status?.canDownload ?? false)) return;
    final kind = previewKind(o);
    final key = o.key;
    try {
      if (kind == PreviewKind.image && o.size <= _maxImageBytes) {
        setState(() => _loadingPreview = true);
        final r = await ctrl.readBytes(key);
        if (!mounted || widget.object.key != key) return;
        setState(() => _bytes = Uint8List.fromList(r.bytes));
      } else if (kind == PreviewKind.text) {
        setState(() => _loadingPreview = true);
        final r = await ctrl.readBytes(key,
            maxBytes: _maxTextBytes, rangeSupported: status!.canRange);
        if (!mounted || widget.object.key != key) return;
        var text = utf8.decode(r.bytes, allowMalformed: true);
        final truncated = o.size > r.bytes.length;
        if (!truncated && (o.extension == 'json' || o.contentType.contains('json'))) {
          try {
            text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
          } catch (_) {}
        }
        setState(() {
          _text = text;
          _textTruncated = truncated;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _previewError = e.message);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  String? _localPath(String serverPath) {
    final server = context.read<ServerController>();
    return Desktop.localPathFor(
        serverPath, server.adminUrl, server.status?.host);
  }

  /// Opens the object in the default app. Always through a temp copy with
  /// the real file name: the stored file carries the server's ".cloodsys3ext"
  /// suffix, so opening it in place would pick the wrong application.
  Future<void> _openExternally() async {
    final ctrl = context.read<ObjectsController>();
    final tmp = await getTemporaryDirectory();
    final dest = File(p.join(tmp.path, 'cloodsy-preview', o.fileName));
    await dest.parent.create(recursive: true);
    if (!mounted) return;
    final api = context.read<SessionController>().api;
    final ok = await runAction(context, () async {
      await api.downloadToFile(
          '/buckets/${ApiClient.seg(ctrl.bucket)}/object', dest,
          query: {'key': o.key});
      await Desktop.openFile(dest.path);
    });
    if (!ok) return;
  }

  Future<void> _openPdf() async {
    final ctrl = context.read<ObjectsController>();
    Uint8List? bytes;
    final ok = await runAction(context, () async {
      bytes = Uint8List.fromList((await ctrl.readBytes(o.key)).bytes);
    });
    if (!ok || !mounted || bytes == null) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.fileText),
              title: Text(o.fileName),
              trailing: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Divider(height: 1),
            Expanded(
                child: PdfViewer.data(bytes!, sourceName: o.key)),
          ],
        ),
      ),
    );
  }

  void _openImageFull() {
    final bytes = _bytes;
    if (bytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 8,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                style: IconButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final status = context.watch<ServerController>().status;
    final bucket = context.watch<BucketController>().bucket;
    final a = widget.actions;
    final info = _info;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
            child: Row(
              children: [
                Icon(fileIcon(o.extension), size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(o.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall),
                ),
                IconButton(
                  tooltip: tr('Close (Esc)'),
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _preview(context, status?.canDownload ?? false),
                const SizedBox(height: 14),
                // Actions
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (a.download != null)
                      _ActionChip(LucideIcons.download, tr('Download'),
                          () => a.download!(o), primary: true),
                    if (a.share != null)
                      _ActionChip(LucideIcons.link, tr('Share'), () => a.share!(o)),
                    if (a.rename != null)
                      _ActionChip(LucideIcons.pencil, tr('Rename'), () => a.rename!(o)),
                    if (a.moveCopy != null)
                      _ActionChip(LucideIcons.folderInput, tr('Move / copy'),
                          () => a.moveCopy!(o)),
                    if (a.editMetadata != null)
                      _ActionChip(LucideIcons.tags, tr('Metadata'),
                          () => a.editMetadata!(o, info)),
                    if (a.versions != null)
                      _ActionChip(LucideIcons.history, tr('Versions'),
                          () => a.versions!(o)),
                    _ActionChip(LucideIcons.trash2, tr('Delete'), () => a.delete(o),
                        danger: true),
                  ],
                ),
                const SizedBox(height: 18),
                _section(context, tr('Object')),
                InfoRow.text(tr('Size'),
                    '${formatBytes(o.size)} (${formatCount(o.size)} B)'),
                InfoRow.text(tr('Type'),
                    (info?.contentType ?? o.contentType).isEmpty
                        ? '—'
                        : info?.contentType ?? o.contentType,
                    mono: true),
                InfoRow.text(tr('Modified'),
                    '${formatDateTime(o.lastModified)} · ${formatRelative(o.lastModified)}'),
                InfoRow.text(tr('ETag'), o.etag.isEmpty ? '—' : o.etag, mono: true),
                if (info != null && info.versionId.isNotEmpty)
                  InfoRow.text(tr('Version'), info.versionId, mono: true),
                const SizedBox(height: 10),
                CopyValue(label: tr('Key'), value: o.key),
                const SizedBox(height: 10),
                CopyValue(
                    label: tr('S3 URI'), value: 's3://${bucket?.name ?? ''}/${o.key}'),
                const SizedBox(height: 18),
                _section(context, tr('On disk')),
                if (!(status?.canObjectInfo ?? false))
                  Text(tr('Update the server to see where this object is stored.'),
                      style: t.bodySmall)
                else if (_infoError != null)
                  Callout(_infoError!.message, tone: Tone.danger)
                else if (info == null)
                  const LinearProgressIndicator(minHeight: 2)
                else ...[
                  _DiskPath(
                      label: tr('File'),
                      path: info.diskPath,
                      local: _localPath(info.diskPath)),
                  if (info.variant?.exists == true) ...[
                    const SizedBox(height: 10),
                    _DiskPath(
                        label: tr('Optimized variant · {size}', {'size': formatBytes(info.variant!.size)}),
                        path: info.variant!.diskPath,
                        local: _localPath(info.variant!.diskPath)),
                  ],
                  if (info.versions.length > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                        tr('{n} versions are kept; see Versions for each file.', {'n': info.versions.length}),
                        style: t.bodySmall),
                  ],
                ],
                if (info != null && info.metadata.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _section(context, tr('Metadata')),
                  for (final e in info.metadata.entries)
                    InfoRow.text(e.key, e.value, mono: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
      );

  Widget _preview(BuildContext context, bool canDownload) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final kind = previewKind(o);

    Widget frame(Widget child, {double? height}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );

    Widget placeholder(IconData icon, String text, {Widget? action}) => frame(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30, color: c.subtle),
                const SizedBox(height: 8),
                Text(text, style: t.bodySmall, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 10), action],
              ],
            ),
          ),
          height: 150,
        );

    if (!canDownload) {
      return placeholder(fileIcon(o.extension), 'Preview needs a newer server');
    }
    if (_loadingPreview) return frame(const LoadingView(), height: 150);
    if (_previewError != null) {
      return placeholder(LucideIcons.circleAlert, _previewError!);
    }
    switch (kind) {
      case PreviewKind.image:
        if (_bytes == null) {
          return placeholder(LucideIcons.image,
              tr('Too large to preview ({size})', {'size': formatBytes(o.size)}),
              action: OutlinedButton(
                  onPressed: _openExternally, child: Text(tr('Open'))));
        }
        return GestureDetector(
          onTap: _openImageFull,
          child: MouseRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: frame(
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Image.memory(_bytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(tr('Not a decodable image')),
                        )),
              ),
            ),
          ),
        );
      case PreviewKind.text:
        if (_text == null) return placeholder(LucideIcons.fileText, '');
        return frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _text!,
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11.5,
                        height: 1.45,
                        color: c.foreground),
                  ),
                ),
              ),
              if (_textTruncated)
                Container(
                  color: c.hover,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                      tr('Showing the first {size}', {'size': formatBytes(_maxTextBytes)}),
                      style: t.bodySmall),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _text!));
                    showToast(context, tr('Text copied'));
                  },
                  icon: const Icon(LucideIcons.copy, size: 14),
                  label: Text(tr('Copy')),
                ),
              ),
            ],
          ),
        );
      case PreviewKind.pdf:
        return placeholder(
          LucideIcons.fileText,
          'PDF document',
          action: FilledButton.icon(
            onPressed: o.size <= _maxPdfBytes ? _openPdf : _openExternally,
            icon: const Icon(LucideIcons.eye, size: 15),
            label: Text(o.size <= _maxPdfBytes ? 'Preview' : 'Open'),
          ),
        );
      case PreviewKind.media:
        return placeholder(
          o.contentType.startsWith('audio') ? LucideIcons.music : LucideIcons.video,
          'Plays in your default media player',
          action: FilledButton.icon(
            onPressed: _openExternally,
            icon: const Icon(LucideIcons.play, size: 15),
            label: Text(tr('Open')),
          ),
        );
      case PreviewKind.none:
        return placeholder(fileIcon(o.extension), 'No preview for this type',
            action: OutlinedButton(
                onPressed: _openExternally,
                child: Text(tr('Open with default app'))));
    }
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  const _ActionChip(this.icon, this.label, this.onTap,
      {this.primary = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: danger
          ? OutlinedButton.styleFrom(
              foregroundColor: c.danger,
              side: BorderSide(color: c.danger.withValues(alpha: 0.4)))
          : null,
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
    );
  }
}

/// A server-side path with copy, and "show in folder" / "open" when the
/// server runs on this machine.
class _DiskPath extends StatelessWidget {
  final String label;
  final String path;
  final String? local;
  const _DiskPath({required this.label, required this.path, this.local});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Text(tr('No file (the current version is a delete marker).'),
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CopyValue(label: label, value: path),
        if (local != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: () async {
                  if (!await Desktop.showInFolder(local!) && context.mounted) {
                    showToast(context, tr('Could not open the file manager'),
                        error: true);
                  }
                },
                icon: const Icon(LucideIcons.folderSearch, size: 15),
                label: Text(tr('Show in folder')),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: local!));
                  showToast(context, tr('Local path copied'));
                },
                icon: const Icon(LucideIcons.clipboardCopy, size: 15),
                label: Text(tr('Copy local path')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
