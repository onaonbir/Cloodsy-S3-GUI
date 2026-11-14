import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/platform.dart';
import '../../../models/admin_extras.dart';
import '../../../models/s3_object.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/objects_controller.dart';
import '../../../state/prefs_controller.dart';
import '../../../state/server_controller.dart';
import '../../../state/session_controller.dart';
import '../../../state/transfers_controller.dart';
import '../../dialogs/object_dialogs.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'object_panel.dart';
import 'versions_dialog.dart';
import '../../../core/i18n.dart';

class FilesTab extends StatefulWidget {
  const FilesTab({super.key});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  StreamSubscription<Transfer>? _uploads;
  Timer? _refreshDebounce;
  bool _dragging = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _listFocus = FocusNode(debugLabel: 'files');
  S3Object? _focused;

  ObjectsController get _ctrl => context.read<ObjectsController>();

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<ObjectsController>();
    // The first load notifies listeners synchronously; it must not run
    // while this widget is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ctrl.loadedOnce && !ctrl.loading) ctrl.open('');
    });
    _search.text = ctrl.searchQuery.isNotEmpty ? ctrl.searchQuery : ctrl.filter;
    // Refresh the listing when uploads into the visible folder finish.
    _uploads = context.read<TransfersController>().uploaded.listen((t) {
      if (t.bucket != ctrl.bucket || !t.key.startsWith(ctrl.prefix)) return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 600), () {
        if (mounted) ctrl.refresh();
      });
    });
  }

  @override
  void dispose() {
    _uploads?.cancel();
    _refreshDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  void _open(String prefix) {
    _search.clear();
    setState(() => _focused = null);
    _ctrl.open(prefix);
  }

  void _focus(S3Object? o) {
    setState(() => _focused = o);
    _listFocus.requestFocus();
  }

  // ------------------------------------------------------------ Uploads

  Future<void> _pickAndUpload() async {
    final prefs = context.read<PrefsController>();
    final files = await openFiles(initialDirectory: prefs.uploadDir);
    if (files.isEmpty || !mounted) return;
    prefs.setUploadDir(p.dirname(files.first.path));
    _queueUploads({for (final f in files) File(f.path): f.name});
  }

  Future<void> _pickFolderAndUpload() async {
    final prefs = context.read<PrefsController>();
    final dir = await getDirectoryPath(
        initialDirectory: prefs.uploadDir, confirmButtonText: tr('Upload'));
    if (dir == null || !mounted) return;
    prefs.setUploadDir(p.dirname(dir));
    await _uploadPaths([dir]);
  }

  /// [files]: local file → path relative to the current folder.
  void _queueUploads(Map<File, String> files) {
    if (files.isEmpty) return;
    final ctrl = _ctrl;
    context.read<TransfersController>().upload(ctrl.bucket, {
      for (final e in files.entries)
        e.key: '${ctrl.prefix}${e.value.replaceAll(r'\', '/')}',
    });
  }

  Future<void> _uploadPaths(List<String> paths) async {
    final files = <File, String>{};
    for (final path in paths) {
      if (await FileSystemEntity.isDirectory(path)) {
        final root = p.dirname(path);
        await for (final e in Directory(path).list(recursive: true)) {
          if (e is File) files[e] = p.relative(e.path, from: root);
        }
      } else {
        files[File(path)] = p.basename(path);
      }
    }
    if (!mounted) return;
    if (files.length > 200) {
      final ok = await confirm(context,
          title: tr('Upload {n} files?', {'n': files.length}),
          message: 'They will be uploaded into “/${_ctrl.prefix}”.',
          confirmLabel: tr('Upload'),
          destructive: false);
      if (!ok) return;
    }
    _queueUploads(files);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    await _uploadPaths(details.files.map((f) => f.path).toList());
  }

  Future<void> _newFolder() async {
    final name = await promptText(
      context,
      title: tr('New folder'),
      label: tr('Folder name'),
      confirmLabel: tr('Create'),
      icon: LucideIcons.folderPlus,
      validator: (v) => v.contains('/') ? 'Use a single name without “/”' : null,
    );
    if (name == null || !mounted) return;
    await runAction(context, () => _ctrl.createFolder(name),
        success: tr('Folder “{name}” created', {'name': name}));
  }

  // ------------------------------------------------------------ Downloads

  Future<void> _download(S3Object o, {String? versionId}) async {
    final prefs = context.read<PrefsController>();
    final loc = await getSaveLocation(
        suggestedName: o.fileName, initialDirectory: prefs.downloadDir);
    if (loc == null || !mounted) return;
    prefs.setDownloadDir(p.dirname(loc.path));
    context.read<TransfersController>().download(
        _ctrl.bucket, o.key, File(loc.path),
        versionId: versionId, size: o.size);
  }

  Future<void> _downloadSelected(List<S3Object> objs) async {
    final prefs = context.read<PrefsController>();
    final dir = await getDirectoryPath(
        initialDirectory: prefs.downloadDir,
        confirmButtonText: tr('Download here'));
    if (dir == null || !mounted) return;
    prefs.setDownloadDir(dir);
    final transfers = context.read<TransfersController>();
    final used = <String>{};
    for (final o in objs) {
      final name = o.fileName;
      var target = p.join(dir, name);
      var n = 1;
      while (used.contains(target) || File(target).existsSync()) {
        final ext = p.extension(name);
        target = p.join(dir, '${p.basenameWithoutExtension(name)} ($n)$ext');
        n++;
      }
      used.add(target);
      transfers.download(_ctrl.bucket, o.key, File(target), size: o.size);
    }
    _ctrl.clearSelection();
  }

  // ------------------------------------------------------------ Object ops

  List<String> get _bucketNames =>
      context.read<ServerController>().buckets.map((b) => b.name).toList();

  void _share(S3Object o) {
    final server = context.read<ServerController>();
    final session = context.read<SessionController>();
    final bucket = context.read<BucketController>();
    showShareDialog(
      context,
      bucket: _ctrl.bucket,
      objectKey: o.key,
      endpoint: server.s3Endpoint(session.server?.s3Url ?? ''),
      publicRead: bucket.bucket?.publicRead ?? false,
      credentials: bucket.credentials,
      region: server.status?.s3?.region ?? 'us-east-1',
    );
  }

  Future<String> _copyRun(String srcKey, String destBucket, String dest,
      bool move) async {
    await _ctrl.copy(srcKey, dest, destBucket: destBucket, move: move);
    if (move && _focused?.key == srcKey) setState(() => _focused = null);
    return tr(move ? 'Moved to {dest}' : 'Copied to {dest}',
        {'dest': '${destBucket == _ctrl.bucket ? '' : '$destBucket/'}$dest'});
  }

  void _rename(S3Object o) => showMoveCopyDialog(
        context,
        bucket: _ctrl.bucket,
        sourceKey: o.key,
        isFolder: false,
        buckets: _bucketNames,
        renameOnly: true,
        run: (b, d, m) => _copyRun(o.key, b, d, true),
      );

  void _moveCopy(S3Object o) => showMoveCopyDialog(
        context,
        bucket: _ctrl.bucket,
        sourceKey: o.key,
        isFolder: false,
        buckets: _bucketNames,
        run: (b, d, m) => _copyRun(o.key, b, d, m),
      );

  Future<String> _folderRun(
      String src, String destBucket, String dest, bool move) async {
    final r = await _ctrl.copyPrefix(src, dest, destBucket: destBucket, move: move);
    if (r.failed > 0) {
      throw ApiException(
          500, tr('{ok} done, {failed} failed', {'ok': r.copied, 'failed': r.failed}));
    }
    return tr(move ? '{n} objects moved' : '{n} objects copied', {'n': r.copied});
  }

  void _renameFolder(String prefix) => showMoveCopyDialog(
        context,
        bucket: _ctrl.bucket,
        sourceKey: prefix,
        isFolder: true,
        buckets: _bucketNames,
        renameOnly: true,
        run: (b, d, m) => _folderRun(prefix, b, d, true),
      );

  void _moveCopyFolder(String prefix) => showMoveCopyDialog(
        context,
        bucket: _ctrl.bucket,
        sourceKey: prefix,
        isFolder: true,
        buckets: _bucketNames,
        run: (b, d, m) => _folderRun(prefix, b, d, m),
      );

  void _moveCopySelected() {
    final keys = _ctrl.selected.toList();
    showMoveCopyDialog(
      context,
      bucket: _ctrl.bucket,
      sourceKey: _ctrl.prefix,
      isFolder: true,
      count: keys.length,
      buckets: _bucketNames,
      run: (destBucket, dest, move) async {
        var failed = 0;
        String? lastError;
        for (final k in keys) {
          try {
            await _ctrl.copy(k, '$dest${k.split('/').last}',
                destBucket: destBucket, move: move);
          } on ApiException catch (e) {
            failed++;
            lastError = e.message;
          }
        }
        if (failed > 0) {
          throw ApiException(500,
              tr('{failed} of {total} failed', {'failed': failed, 'total': keys.length}) +
                  (lastError != null ? ': $lastError' : ''));
        }
        _ctrl.clearSelection();
        return tr(move ? '{n} objects moved' : '{n} objects copied', {'n': keys.length});
      },
    );
  }

  Future<void> _editMetadata(S3Object o, ObjectInfo? info) async {
    var i = info;
    if (i == null) {
      final ok = await runAction(context, () async => i = await _ctrl.info(o.key));
      if (!ok || !mounted) return;
    }
    final versioned =
        context.read<BucketController>().bucket?.versioningEnabled ?? false;
    final saved = await showMetadataDialog(
      context,
      objectKey: o.key,
      contentType: i!.contentType,
      metadata: i!.metadata,
      versioned: versioned,
      save: (ct, meta) =>
          _ctrl.updateMetadata(o.key, contentType: ct, metadata: meta),
    );
    if (saved == true && mounted) {
      showToast(context, tr('Metadata saved'));
      // Re-focus the refreshed object so the panel reloads its info.
      final fresh = _ctrl.objects.where((x) => x.key == o.key).firstOrNull;
      setState(() => _focused = fresh ?? _focused);
    }
  }

  Future<void> _folderSize(String prefix) async {
    ({int objects, int bytes})? r;
    final ok = await runAction(context, () async => r = await _ctrl.prefixStats(prefix));
    if (!ok || !mounted || r == null) return;
    final name = prefix.isEmpty ? _ctrl.bucket : _ctrl.folderName(prefix);
    showToast(context,
        tr('{name}: {n} objects, {size}', {'name': name, 'n': formatCount(r!.objects), 'size': formatBytes(r!.bytes)}));
  }

  void _versions(S3Object o) {
    final status = context.read<ServerController>().status;
    showVersionsDialog(context, _ctrl, o,
        onDownload: (status?.canDownload ?? false)
            ? (v) => _download(o, versionId: v.versionId)
            : null);
  }

  // ------------------------------------------------------------ Deletes

  Future<void> _delete(S3Object o) async {
    final ok = await confirm(context,
        title: tr('Delete object'),
        message: tr('Permanently delete “{name}” including all of its versions?', {'name': o.fileName}),
        detail: o.key);
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await _ctrl.deleteObject(o.key);
      await _ctrl.refresh();
    }, success: tr('“{name}” deleted', {'name': o.fileName}));
    if (done && _focused?.key == o.key) setState(() => _focused = null);
  }

  Future<void> _deleteSelected() async {
    final keys = _ctrl.selected.toList();
    if (keys.isEmpty) {
      if (_focused != null) await _delete(_focused!);
      return;
    }
    final ok = await confirm(context,
        title: tr('Delete {n} objects', {'n': keys.length}),
        message: tr('Permanently delete the selected objects including all of '
            'their versions?'));
    if (!ok || !mounted) return;
    final r = await _ctrl.deleteKeys(keys);
    if (!mounted) return;
    if (keys.contains(_focused?.key)) setState(() => _focused = null);
    if (r.failed.isEmpty) {
      showToast(context, tr('{n} objects deleted', {'n': keys.length}));
    } else {
      showToast(
          context,
          tr('{failed} of {total} could not be deleted', {'failed': r.failed.length, 'total': keys.length}) +
              (r.error != null ? ': ${r.error}' : ''),
          error: true);
    }
  }

  Future<void> _deleteFolder(String prefix) async {
    final name = _ctrl.folderName(prefix);
    final ok = await confirm(context,
        title: tr('Delete folder'),
        message: tr('Delete “{name}” and everything inside it? All object versions under this folder are removed.', {'name': name}),
        typeToConfirm: name);
    if (!ok || !mounted) return;
    try {
      final r = await _ctrl.deleteFolder(prefix);
      if (!mounted) return;
      showToast(
          context,
          r.failed > 0
              ? tr('{ok} deleted, {failed} failed (see server log)', {'ok': r.deleted, 'failed': r.failed})
              : tr('Folder “{name}” deleted ({n} objects)', {'name': name, 'n': r.deleted}),
          error: r.failed > 0);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  // ------------------------------------------------------------ Keyboard

  List<S3Object> get _visibleObjects =>
      _ctrl.searchQuery.isNotEmpty ? _ctrl.searchResults : _ctrl.objects;

  void _moveFocus(int delta) {
    final list = _visibleObjects;
    if (list.isEmpty) return;
    final i = _focused == null ? -1 : list.indexWhere((o) => o.key == _focused!.key);
    final next = (i + delta).clamp(0, list.length - 1);
    setState(() => _focused = list[next]);
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(ServerController server) {
    final st = server.status;
    return {
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
          _ctrl.selectAllVisible(true),
      const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
          _ctrl.selectAllVisible(true),
      const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_ctrl.selected.isNotEmpty) {
          _ctrl.clearSelection();
        } else if (_ctrl.searchQuery.isNotEmpty) {
          _search.clear();
          _ctrl.clearSearch();
        } else {
          setState(() => _focused = null);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          _searchFocus.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.f5): _ctrl.refresh,
      const SingleActivator(LogicalKeyboardKey.backspace): _ctrl.up,
      const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _ctrl.up,
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveFocus(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveFocus(-1),
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (_focused != null) _ctrl.toggleSelected(_focused!.key);
      },
      if (st?.canCopy ?? false)
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (_focused != null) _rename(_focused!);
        },
      if (st?.canUpload ?? false)
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _pickAndUpload,
      if (st?.canDownload ?? false)
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_focused != null) _download(_focused!);
        },
    };
  }

  // ------------------------------------------------------------ Build

  ObjectActions _actions(ServerController server) {
    final st = server.status;
    return ObjectActions(
      delete: _delete,
      download: (st?.canDownload ?? false) ? _download : null,
      share: _share,
      rename: (st?.canCopy ?? false) ? _rename : null,
      moveCopy: (st?.canCopy ?? false) ? _moveCopy : null,
      editMetadata: (st?.canEditMetadata ?? false) ? _editMetadata : null,
      versions: (st?.canListVersions ?? false) ? _versions : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ObjectsController>();
    final server = context.watch<ServerController>();
    final status = server.status;
    final canUpload = status?.canUpload ?? false;
    final canDownload = status?.canDownload ?? false;
    final actions = _actions(server);
    final width = MediaQuery.sizeOf(context).width;
    final sidePanel = width >= 1180;

    // Drop the panel when its object left the listing (deleted, moved).
    final focused = _focused;
    final focusedVisible = focused != null &&
        _visibleObjects.any((o) => o.key == focused.key);

    void onFocus(S3Object o) {
      if (sidePanel) {
        _focus(o);
      } else {
        _showPanelDialog(o, actions);
      }
    }

    final list = _FileList(
      focusedKey: focusedVisible ? focused.key : null,
      onOpen: _open,
      onFocus: onFocus,
      actions: actions,
      onDeleteFolder: _deleteFolder,
      onRenameFolder: (status?.canCopy ?? false) ? _renameFolder : null,
      onMoveCopyFolder: (status?.canCopy ?? false) ? _moveCopyFolder : null,
      onFolderSize: (status?.canPrefixStats ?? false) ? _folderSize : null,
      onUpload: canUpload ? _pickAndUpload : null,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          search: _search,
          searchFocus: _searchFocus,
          canSearch: status?.canSearch ?? false,
          onOpen: _open,
          onUpload: canUpload ? _pickAndUpload : null,
          onUploadFolder: canUpload ? _pickFolderAndUpload : null,
          onNewFolder: canUpload ? _newFolder : null,
          onFolderInfo: (status?.canPrefixStats ?? false)
              ? () => _folderSize(ctrl.prefix)
              : null,
          onDownloadSelected: canDownload
              ? () => _downloadSelected(_visibleObjects
                  .where((o) => ctrl.selected.contains(o.key))
                  .toList())
              : null,
          onMoveSelected: (status?.canCopy ?? false) ? _moveCopySelected : null,
          onDeleteSelected: _deleteSelected,
        ),
        if (status != null && status.features.isEmpty) ...[
          const SizedBox(height: 10),
          Callout(
            tr('Upload and download need Cloodsy S3 with the object API '
            '(newer than this server). Browsing and deleting still work.'),
            tone: Tone.neutral,
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shortcuts only apply while the listing has focus, so typing
              // in the search box (Backspace, Space, arrows) stays typing.
              Expanded(
                child: Focus(
                  focusNode: _listFocus,
                  autofocus: true,
                  child: CallbackShortcuts(
                      bindings: _shortcuts(server), child: list),
                ),
              ),
              if (sidePanel && focusedVisible) ...[
                const SizedBox(width: 14),
                SizedBox(
                  width: 380,
                  child: ObjectPanel(
                    key: ValueKey(focused.key),
                    object: _visibleObjects
                        .firstWhere((o) => o.key == focused.key),
                    actions: actions,
                    onClose: () => setState(() => _focused = null),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final keyed = body;

    if (!isDesktop || !canUpload) return keyed;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: Stack(
        children: [
          keyed,
          if (_dragging)
            Positioned.fill(child: _DropOverlay(prefix: ctrl.prefix)),
        ],
      ),
    );
  }

  /// Narrow windows: the details pane opens as a dialog. Dialogs live on
  /// the root navigator, so the bucket-scoped controllers are re-provided.
  void _showPanelDialog(S3Object o, ObjectActions actions) {
    final objects = context.read<ObjectsController>();
    final bucket = context.read<BucketController>();
    showDialog(
      context: context,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: objects),
          ChangeNotifierProvider.value(value: bucket),
        ],
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 460,
            height: 640,
            child: ObjectPanel(
              object: o,
              actions: actions,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  final String prefix;
  const _DropOverlay({required this.prefix});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: c.primary, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cloudUpload, size: 36, color: c.primary),
              const SizedBox(height: 10),
              Text(tr('Drop to upload'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(tr('into /{p}', {'p': prefix}),
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController search;
  final FocusNode searchFocus;
  final bool canSearch;
  final ValueChanged<String> onOpen;
  final VoidCallback? onUpload;
  final VoidCallback? onUploadFolder;
  final VoidCallback? onNewFolder;
  final VoidCallback? onFolderInfo;
  final VoidCallback? onDownloadSelected;
  final VoidCallback? onMoveSelected;
  final VoidCallback onDeleteSelected;

  const _Toolbar({
    required this.search,
    required this.searchFocus,
    required this.canSearch,
    required this.onOpen,
    required this.onUpload,
    required this.onUploadFolder,
    required this.onNewFolder,
    required this.onFolderInfo,
    required this.onDownloadSelected,
    required this.onMoveSelected,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = context.watch<ObjectsController>();
    final segs = ctrl.segments;
    final selected = ctrl.selected.length;

    final crumbs = <Widget>[
      _Crumb(
        label: ctrl.bucket,
        icon: LucideIcons.package,
        active: segs.isEmpty,
        onTap: () => onOpen(''),
      ),
      for (var i = 0; i < segs.length; i++) ...[
        Icon(LucideIcons.chevronRight, size: 14, color: c.subtle),
        _Crumb(
          label: segs[i],
          active: i == segs.length - 1,
          onTap: () => onOpen('${segs.sublist(0, i + 1).join('/')}/'),
        ),
      ],
    ];

    final searchField = SizedBox(
      width: 260,
      height: 36,
      child: TextField(
        controller: search,
        focusNode: searchFocus,
        style: Theme.of(context).textTheme.bodyLarge,
        onChanged: (v) {
          ctrl.setFilter(v);
          if (v.isEmpty && ctrl.searchQuery.isNotEmpty) ctrl.clearSearch();
        },
        onSubmitted: canSearch ? ctrl.search : null,
        decoration: InputDecoration(
          hintText: canSearch
              ? tr('Filter · Enter searches all subfolders')
              : tr('Filter this folder'),
          prefixIcon: const Icon(LucideIcons.search, size: 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: tr('Clear'),
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () {
                    search.clear();
                    ctrl.setFilter('');
                    ctrl.clearSearch();
                  },
                ),
        ),
      ),
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: crumbs),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: selected > 0
              ? [
                  Text(tr('{n} selected', {'n': selected}),
                      style: Theme.of(context).textTheme.labelLarge),
                  TextButton(
                      onPressed: ctrl.clearSelection,
                      child: Text(tr('Clear'))),
                  if (onDownloadSelected != null)
                    OutlinedButton.icon(
                      onPressed: onDownloadSelected,
                      icon: const Icon(LucideIcons.download, size: 15),
                      label: Text(tr('Download')),
                    ),
                  if (onMoveSelected != null)
                    OutlinedButton.icon(
                      onPressed: onMoveSelected,
                      icon: const Icon(LucideIcons.folderInput, size: 15),
                      label: Text(tr('Move / copy')),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: c.danger,
                        foregroundColor: Colors.white),
                    onPressed: onDeleteSelected,
                    icon: const Icon(LucideIcons.trash2, size: 15),
                    label: Text(tr('Delete')),
                  ),
                ]
              : [
                  searchField,
                  IconButton(
                    tooltip: tr('Refresh (F5)'),
                    onPressed: ctrl.loading ? null : ctrl.refresh,
                    icon: ctrl.loading
                        ? const ButtonSpinner()
                        : const Icon(LucideIcons.refreshCw, size: 16),
                  ),
                  if (onFolderInfo != null)
                    IconButton(
                      tooltip: tr('Size of this folder'),
                      onPressed: onFolderInfo,
                      icon: const Icon(LucideIcons.chartPie, size: 16),
                    ),
                  if (onNewFolder != null)
                    OutlinedButton.icon(
                      onPressed: onNewFolder,
                      icon: const Icon(LucideIcons.folderPlus, size: 15),
                      label: Text(tr('New folder')),
                    ),
                  if (onUpload != null)
                    _UploadButton(
                        onFiles: onUpload!, onFolder: onUploadFolder),
                ],
        ),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onFiles;
  final VoidCallback? onFolder;
  const _UploadButton({required this.onFiles, this.onFolder});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(AppRadius.md))),
          ),
          onPressed: onFiles,
          icon: const Icon(LucideIcons.upload, size: 15),
          label: Text(tr('Upload')),
        ),
        const SizedBox(width: 1),
        MenuAnchor(
          style: const MenuStyle(
            alignment: AlignmentDirectional.bottomEnd,
            minimumSize: WidgetStatePropertyAll(Size(190, 0)),
          ),
          alignmentOffset: const Offset(-190, 4),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(LucideIcons.files, size: 16),
              shortcut: const SingleActivator(LogicalKeyboardKey.keyU,
                  control: true),
              onPressed: onFiles,
              child: Text(tr('Upload files…')),
            ),
            if (onFolder != null)
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.folderUp, size: 16),
                onPressed: onFolder,
                child: Text(tr('Upload folder…')),
              ),
          ],
          builder: (context, menu, _) => FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(32, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(AppRadius.md))),
            ),
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            child: const Icon(LucideIcons.chevronDown, size: 15),
          ),
        ),
      ],
    );
  }
}

class _Crumb extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;
  const _Crumb(
      {required this.label,
      required this.active,
      required this.onTap,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: active ? c.foreground : c.muted,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500);
    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: active ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? c.primary : c.muted),
              const SizedBox(width: 6),
            ],
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  final String? focusedKey;
  final ValueChanged<String> onOpen;
  final ValueChanged<S3Object> onFocus;
  final ObjectActions actions;
  final void Function(String) onDeleteFolder;
  final void Function(String)? onRenameFolder;
  final void Function(String)? onMoveCopyFolder;
  final void Function(String)? onFolderSize;
  final VoidCallback? onUpload;

  const _FileList({
    required this.focusedKey,
    required this.onOpen,
    required this.onFocus,
    required this.actions,
    required this.onDeleteFolder,
    required this.onRenameFolder,
    required this.onMoveCopyFolder,
    required this.onFolderSize,
    required this.onUpload,
  });

  List<Widget> _objectMenu(BuildContext context, S3Object o) {
    final c = context.colors;
    final a = actions;
    return [
      MenuItemButton(
        leadingIcon: const Icon(LucideIcons.panelRight, size: 16),
        onPressed: () => onFocus(o),
        child: Text(tr('Details')),
      ),
      if (a.download != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.download, size: 16),
          onPressed: () => a.download!(o),
          child: Text(tr('Download')),
        ),
      if (a.share != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.link, size: 16),
          onPressed: () => a.share!(o),
          child: Text(tr('Share link…')),
        ),
      if (a.rename != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.pencil, size: 16),
          shortcut: const SingleActivator(LogicalKeyboardKey.f2),
          onPressed: () => a.rename!(o),
          child: Text(tr('Rename…')),
        ),
      if (a.moveCopy != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.folderInput, size: 16),
          onPressed: () => a.moveCopy!(o),
          child: Text(tr('Move / copy…')),
        ),
      if (a.editMetadata != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.tags, size: 16),
          onPressed: () => a.editMetadata!(o, null),
          child: Text(tr('Edit metadata…')),
        ),
      if (a.versions != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.history, size: 16),
          onPressed: () => a.versions!(o),
          child: Text(tr('Versions…')),
        ),
      MenuItemButton(
        leadingIcon: const Icon(LucideIcons.copy, size: 16),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: o.key));
          showToast(context, tr('Key copied'));
        },
        child: Text(tr('Copy key')),
      ),
      const Divider(height: 9),
      MenuItemButton(
        leadingIcon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
        shortcut: const SingleActivator(LogicalKeyboardKey.delete),
        onPressed: () => a.delete(o),
        child: Text(tr('Delete…'), style: TextStyle(color: c.danger)),
      ),
    ];
  }

  List<Widget> _folderMenu(BuildContext context, String f) {
    final c = context.colors;
    return [
      MenuItemButton(
        leadingIcon: const Icon(LucideIcons.folderOpen, size: 16),
        onPressed: () => onOpen(f),
        child: Text(tr('Open')),
      ),
      if (onRenameFolder != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.pencil, size: 16),
          onPressed: () => onRenameFolder!(f),
          child: Text(tr('Rename…')),
        ),
      if (onMoveCopyFolder != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.folderInput, size: 16),
          onPressed: () => onMoveCopyFolder!(f),
          child: Text(tr('Move / copy…')),
        ),
      if (onFolderSize != null)
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.chartPie, size: 16),
          onPressed: () => onFolderSize!(f),
          child: Text(tr('Calculate size')),
        ),
      MenuItemButton(
        leadingIcon: const Icon(LucideIcons.copy, size: 16),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: f));
          showToast(context, tr('Prefix copied'));
        },
        child: Text(tr('Copy prefix')),
      ),
      const Divider(height: 9),
      MenuItemButton(
        leadingIcon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
        onPressed: () => onDeleteFolder(f),
        child: Text(tr('Delete folder…'), style: TextStyle(color: c.danger)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final ctrl = context.watch<ObjectsController>();
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final searching = ctrl.searchQuery.isNotEmpty;

    if (!ctrl.loadedOnce) return const LoadingView();
    if (ctrl.error != null && ctrl.isEmpty && !searching) {
      return ErrorState(ctrl.error!, onRetry: ctrl.refresh);
    }

    final folders = searching ? const <String>[] : ctrl.folders;
    final objects = searching ? ctrl.searchResults : ctrl.objects;
    final allSelected = objects.isNotEmpty &&
        objects.every((o) => ctrl.selected.contains(o.key));

    Widget sortHead(String label, ObjectSort s, {bool end = false, int flex = 1}) {
      final active = ctrl.sort == s && !searching;
      return Expanded(
        flex: flex,
        child: Align(
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: searching ? null : () => ctrl.setSort(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: t.labelMedium?.copyWith(
                        color: active ? c.foreground : c.subtle)),
                if (active)
                  Icon(ctrl.ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                      size: 12, color: c.foreground),
              ]),
            ),
          ),
        ),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allSelected,
              onChanged: objects.isEmpty
                  ? null
                  : (v) => ctrl.selectAllVisible(v ?? false),
            ),
          ),
          const SizedBox(width: 30),
          sortHead(searching ? 'KEY' : 'NAME', ObjectSort.name, flex: 6),
          sortHead('SIZE', ObjectSort.size, end: true, flex: 2),
          if (!narrow) const SizedBox(width: 24),
          if (!narrow) sortHead('MODIFIED', ObjectSort.modified, flex: 3),
          const SizedBox(width: 44),
        ],
      ),
    );

    Widget content;
    if (searching && ctrl.searching && objects.isEmpty) {
      content = const LoadingView();
    } else if (folders.isEmpty && objects.isEmpty) {
      content = EmptyState(
        icon: searching || ctrl.filter.isNotEmpty
            ? LucideIcons.searchX
            : LucideIcons.folderOpen,
        title: searching
            ? tr('No objects match “{q}”', {'q': ctrl.searchQuery})
            : ctrl.filter.isNotEmpty
                ? tr('Nothing matches “{q}”', {'q': ctrl.filter})
                : tr('This folder is empty'),
        message: searching
            ? tr('Searched every key under /{p}.', {'p': ctrl.prefix})
            : ctrl.filter.isNotEmpty
                ? tr('Press Enter to search all subfolders.')
                : onUpload != null
                    ? (isDesktop
                        ? tr('Drop files or folders here, or use Upload.')
                        : tr('Use Upload to add files.'))
                    : null,
        action: !searching && ctrl.filter.isEmpty && onUpload != null
            ? FilledButton.icon(
                onPressed: onUpload,
                icon: const Icon(LucideIcons.upload, size: 15),
                label: Text(tr('Upload files')),
              )
            : null,
      );
    } else {
      final rows = <Widget>[
        if (searching)
          Container(
            color: c.primarySoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(LucideIcons.search, size: 14, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('{n} results for “{q}” in /{p}', {
                      'n': '${objects.length}${ctrl.searchHasMore ? '+' : ''}',
                      'q': ctrl.searchQuery,
                      'p': ctrl.prefix,
                    }),
                    style: t.labelLarge,
                  ),
                ),
                TextButton(
                    onPressed: ctrl.clearSearch,
                    child: Text(tr('Back to folder'))),
              ],
            ),
          ),
        if (!searching && ctrl.prefix.isNotEmpty && ctrl.filter.isEmpty)
          _Row(
            icon: LucideIcons.cornerLeftUp,
            iconColor: c.subtle,
            name: '..',
            onTap: ctrl.up,
            narrow: narrow,
          ),
        for (final f in folders)
          _Row(
            icon: LucideIcons.folder,
            iconColor: const Color(0xFF5B9DF5),
            name: ctrl.folderName(f),
            bold: true,
            onTap: () => onOpen(f),
            narrow: narrow,
            menu: _folderMenu(context, f),
          ),
        for (final o in objects)
          _Row(
            icon: fileIcon(o.extension),
            iconColor: c.muted,
            name: searching ? o.key.substring(ctrl.prefix.length) : o.fileName,
            size: formatBytes(o.size),
            modified: formatDateTime(o.lastModified),
            modifiedTooltip: formatRelative(o.lastModified),
            selected: ctrl.selected.contains(o.key),
            focused: o.key == focusedKey,
            onSelect: (v) => ctrl.toggleSelected(o.key, v),
            onTap: () {
              final keys = HardwareKeyboard.instance;
              if (keys.isControlPressed || keys.isMetaPressed) {
                ctrl.toggleSelected(o.key);
              } else {
                onFocus(o);
              }
            },
            onDoubleTap:
                actions.download == null ? null : () => actions.download!(o),
            narrow: narrow,
            menu: _objectMenu(context, o),
          ),
      ];

      final hasMore = searching ? ctrl.searchHasMore : ctrl.hasMore;
      final loadingMore = searching ? ctrl.searching : ctrl.loadingMore;
      content = ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: rows.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
        itemBuilder: (context, i) {
          if (i < rows.length) return rows[i];
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: loadingMore
                    ? null
                    : searching
                        ? () => ctrl.search(ctrl.searchQuery, more: true)
                        : ctrl.loadMore,
                icon: loadingMore
                    ? const ButtonSpinner()
                    : const Icon(LucideIcons.chevronsDown, size: 15),
                label: Text(loadingMore ? 'Loading…' : 'Load more'),
              ),
            ),
          );
        },
      );
    }

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
          header,
          Divider(height: 1, color: c.border),
          if ((ctrl.loading && ctrl.loadedOnce) ||
              (searching && ctrl.searching && objects.isNotEmpty))
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(child: content),
        ],
      ),
    );
  }
}

IconData fileIcon(String ext) => switch (ext) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'svg' || 'avif' || 'bmp' || 'ico' =>
        LucideIcons.fileImage,
      'pdf' || 'txt' || 'md' || 'log' || 'rtf' || 'doc' || 'docx' => LucideIcons.fileText,
      'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' => LucideIcons.fileVideo,
      'mp3' || 'wav' || 'flac' || 'ogg' || 'm4a' => LucideIcons.fileAudio,
      'zip' || 'tar' || 'gz' || 'rar' || '7z' || 'bz2' || 'xz' => LucideIcons.fileArchive,
      'json' || 'xml' || 'yaml' || 'yml' || 'js' || 'ts' || 'dart' || 'go' || 'py' ||
      'html' || 'css' || 'sh' => LucideIcons.fileCode,
      'csv' || 'xls' || 'xlsx' => LucideIcons.fileSpreadsheet,
      _ => LucideIcons.file,
    };

/// One listing row with a "⋯" menu and the same menu on right-click.
class _Row extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String? size;
  final String? modified;
  final String? modifiedTooltip;
  final bool bold;
  final bool? selected;
  final bool focused;
  final ValueChanged<bool?>? onSelect;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final List<Widget> menu;
  final bool narrow;

  const _Row({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.onTap,
    required this.narrow,
    this.size,
    this.modified,
    this.modifiedTooltip,
    this.bold = false,
    this.selected,
    this.focused = false,
    this.onSelect,
    this.onDoubleTap,
    this.menu = const [],
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  final _context = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final w = widget;

    final row = Material(
      color: w.selected == true || w.focused ? c.selected : Colors.transparent,
      child: InkWell(
        onTap: w.onTap,
        onDoubleTap: w.onDoubleTap,
        onSecondaryTapDown: w.menu.isEmpty
            ? null
            : (d) => _context.open(position: d.localPosition),
        child: Container(
          decoration: w.focused
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: c.primary, width: 2)))
              : null,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: w.selected == null
                      ? null
                      : Checkbox(value: w.selected, onChanged: w.onSelect),
                ),
                SizedBox(
                    width: 30, child: Icon(w.icon, size: 18, color: w.iconColor)),
                Expanded(
                  flex: 6,
                  child: Text(w.name,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(
                          fontWeight:
                              w.bold ? FontWeight.w600 : FontWeight.w400)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(w.size ?? '',
                      textAlign: TextAlign.right, style: t.bodyMedium),
                ),
                if (!w.narrow) const SizedBox(width: 24),
                if (!w.narrow)
                  Expanded(
                    flex: 3,
                    child: w.modified == null
                        ? const SizedBox()
                        : Tooltip(
                            message: w.modifiedTooltip ?? '',
                            child: Text(w.modified!, style: t.bodyMedium),
                          ),
                  ),
                SizedBox(
                  width: 44,
                  child: w.menu.isEmpty
                      ? null
                      : MoreMenu(
                          tooltip: tr('Actions'), iconSize: 16, children: w.menu),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (w.menu.isEmpty) return row;
    return MenuAnchor(
      controller: _context,
      style: const MenuStyle(
          minimumSize: WidgetStatePropertyAll(Size(MoreMenu.width, 0))),
      menuChildren: w.menu,
      child: row,
    );
  }
}
