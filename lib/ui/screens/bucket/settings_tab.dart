import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/server_controller.dart';
import '../../dialogs/bucket_dialogs.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../buckets_screen.dart' show deleteBucketFlow;
import '../../../core/i18n.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final server = context.watch<ServerController>();
    final b = ctrl.bucket!;
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: tr('Access & features'),
          icon: LucideIcons.toggleRight,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            children: [
              _ToggleRow(
                icon: LucideIcons.history,
                title: tr('Versioning'),
                subtitle: b.versioningEnabled
                    ? tr('Every overwrite and delete keeps the previous version.')
                    : b.versioning == 'Suspended'
                        ? tr('Suspended: existing versions are kept, new writes '
                            'replace the current object.')
                        : tr('Overwrites and deletes are permanent.'),
                value: b.versioningEnabled,
                confirmOff: b.versioningEnabled
                    ? tr('Suspend versioning? Existing versions are kept, but '
                        'new overwrites replace the current object.')
                    : null,
                onChanged: ctrl.setVersioning,
              ),
              _ToggleRow(
                icon: LucideIcons.globe,
                title: tr('Public read'),
                subtitle: b.publicRead
                    ? tr('Anyone with the URL can download objects.')
                    : tr('Requests must be signed with an access key.'),
                value: b.publicRead,
                warnOn: true,
                confirmOn: tr('Make every object in “{b}” readable without authentication?', {'b': b.name}),
                onChanged: ctrl.setPublicRead,
              ),
              _ToggleRow(
                icon: LucideIcons.hardDrive,
                title: tr('WebDAV access'),
                subtitle: !(server.status?.webdavEnabled ?? false)
                    ? tr('WebDAV is disabled on this server (webdav.enabled).')
                    : b.webdavEnabled
                        ? tr('Mountable as a network drive with an access key.')
                        : tr('Not mountable over WebDAV.'),
                value: b.webdavEnabled,
                onChanged: ctrl.setWebdav,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: tr('Storage'),
          icon: LucideIcons.database,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            children: [
              _ActionRow(
                icon: LucideIcons.gauge,
                title: tr('Quota'),
                subtitle: b.hasQuota
                    ? tr('{used} of {total} used', {'used': formatBytes(b.usageBytes), 'total': formatBytes(b.quotaBytes)})
                    : tr('Unlimited'),
                action: 'Change',
                onTap: () => showQuotaDialog(context,
                    current: b.quotaBytes, apply: ctrl.setQuota),
              ),
              _ActionRow(
                icon: LucideIcons.folderCog,
                title: tr('Storage directory'),
                subtitle: b.storageDir.isNotEmpty
                    ? b.storageDir
                    : tr('Default data directory'),
                action: 'Move',
                onTap: () => showStorageDialog(context,
                    current: b.storageDir, apply: ctrl.setStorage),
              ),
              _ActionRow(
                icon: LucideIcons.image,
                title: tr('Image variants'),
                subtitle: tr('Regenerate optimized image variants for every '
                    'object (runs in the background).'),
                action: 'Reprocess',
                onTap: () async {
                  try {
                    await ctrl.reprocessImages();
                    if (context.mounted) {
                      showToast(context, tr('Reprocessing started'));
                    }
                  } on ApiException catch (e) {
                    if (!context.mounted) return;
                    final msg = e.isConflict
                        ? (e.message.contains('reprocess')
                            ? tr('Reprocessing is already running')
                            : tr('Bucket is busy: {what}', {'what': e.message.split(': ').last}))
                        : e.message;
                    showToast(context, msg, error: true);
                  }
                },
              ),
            ],
          ),
        ),
        if (server.status?.canMultipart ?? false) ...[
          const SizedBox(height: 16),
          const _IncompleteUploads(),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.danger.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Delete bucket'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(tr('Removes the bucket and its access keys, rules and '
                        'webhooks.'),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger.withValues(alpha: 0.5))),
                onPressed: () => deleteBucketFlow(context, b.name),
                child: Text(tr('Delete bucket…')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Multipart uploads that were started but never completed or aborted.
/// Their parts take disk space but are invisible in the file browser.
class _IncompleteUploads extends StatefulWidget {
  const _IncompleteUploads();

  @override
  State<_IncompleteUploads> createState() => _IncompleteUploadsState();
}

class _IncompleteUploadsState extends State<_IncompleteUploads> {
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<BucketController>().loadUploads();
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final uploads = ctrl.uploads;
    final bytes = uploads.fold<int>(0, (s, u) => s + u.bytes);

    return Panel(
      title: tr('Incomplete uploads'),
      subtitle: uploads.isEmpty
          ? null
          : tr('{n} uploads holding {size}', {'n': uploads.length, 'size': formatBytes(bytes)}),
      icon: LucideIcons.fileUp,
      actions: [
        IconButton(
          tooltip: tr('Refresh'),
          icon: const Icon(LucideIcons.refreshCw, size: 15),
          onPressed: _load,
        ),
        if (uploads.isNotEmpty)
          MoreMenu(children: [
            MenuItemButton(
              onPressed: () => _abortAll(context, olderThanDays: 7),
              child: Text(tr('Abort older than 7 days')),
            ),
            MenuItemButton(
              onPressed: () => _abortAll(context),
              child: Text(tr('Abort all'), style: TextStyle(color: c.danger)),
            ),
          ]),
      ],
      child: _error != null
          ? Callout(_error!.message, tone: Tone.danger)
          : !ctrl.uploadsLoaded
              ? const LinearProgressIndicator(minHeight: 2)
              : uploads.isEmpty
                  ? Text(tr('None. Every multipart upload was completed or '
                      'cleaned up.'), style: t.bodyMedium)
                  : Column(
                      children: [
                        for (final u in uploads.take(50))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(u.key,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontFamily: AppFonts.mono,
                                              fontSize: 12.5,
                                              color: c.foreground)),
                                      Text(
                                          tr('Started {when} · {n} parts · {size}', {'when': formatRelative(u.initiated), 'n': u.parts, 'size': formatBytes(u.bytes)}),
                                          style: t.bodySmall),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => runAction(context,
                                      () => ctrl.abortUpload(u.uploadId),
                                      success: 'Upload aborted'),
                                  child: Text(tr('Abort')),
                                ),
                              ],
                            ),
                          ),
                        if (uploads.length > 50)
                          Text(tr('…and {n} more', {'n': uploads.length - 50}),
                              style: t.bodySmall),
                      ],
                    ),
    );
  }

  Future<void> _abortAll(BuildContext context, {int? olderThanDays}) async {
    final ok = await confirm(context,
        title: tr('Abort uploads'),
        message: olderThanDays == null
            ? tr('Abort every incomplete upload in this bucket? Clients still '
                'uploading will fail.')
            : tr('Abort incomplete uploads started more than {n} days ago?', {'n': olderThanDays}),
        confirmLabel: tr('Abort'));
    if (!ok || !context.mounted) return;
    final ctrl = context.read<BucketController>();
    int? n;
    final done = await runAction(context,
        () async => n = await ctrl.abortUploads(olderThanDays: olderThanDays));
    if (done && context.mounted) {
      showToast(context, tr('{n} uploads aborted', {'n': n}));
    }
  }
}

class _ToggleRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool warnOn;
  final String? confirmOn;
  final String? confirmOff;
  final Future<void> Function(bool) onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.warnOn = false,
    this.confirmOn,
    this.confirmOff,
  });

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    final question = v ? widget.confirmOn : widget.confirmOff;
    if (question != null) {
      final ok = await confirm(context,
          title: widget.title,
          message: question,
          confirmLabel: v ? 'Enable' : 'Disable',
          destructive: v ? widget.warnOn : true);
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    await runAction(context, () => widget.onChanged(v),
        success: tr(v ? '{what} enabled' : '{what} disabled', {'what': widget.title}));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(widget.icon,
          size: 18,
          color: widget.value && widget.warnOn ? c.warning : c.muted),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: _busy
          ? const Padding(
              padding: EdgeInsets.only(right: 14), child: ButtonSpinner())
          : Switch(value: widget.value, onChanged: _toggle),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 18),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: OutlinedButton(onPressed: onTap, child: Text(action)),
    );
  }
}
