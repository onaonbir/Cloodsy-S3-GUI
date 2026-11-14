import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../models/bucket.dart';
import '../../state/navigation_controller.dart';
import '../../state/server_controller.dart';
import '../dialogs/bucket_dialogs.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Create-bucket dialog → opens the new bucket.
Future<void> createBucketFlow(BuildContext context) async {
  final server = context.read<ServerController>();
  final nav = context.read<NavigationController>();
  final name = await showCreateBucketDialog(
      context, (n, dir) => server.createBucket(n, storageDir: dir));
  if (name != null && context.mounted) {
    showToast(context, tr('Bucket “{name}” created', {'name': name}));
    nav.go(BucketDestination(name));
  }
}

/// Delete with confirmation; offers a forced delete when the server refuses
/// because versions or delete markers remain. Returns true when deleted.
Future<bool> deleteBucketFlow(BuildContext context, String name) async {
  final server = context.read<ServerController>();
  final nav = context.read<NavigationController>();
  final ok = await confirm(
    context,
    title: tr('Delete bucket'),
    message: tr('Delete the bucket “{name}”? The server refuses if it still contains objects.', {'name': name}),
  );
  if (!ok || !context.mounted) return false;
  try {
    await server.deleteBucket(name);
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    final busy = e.message.startsWith('bucket is busy');
    if (!e.isConflict || busy) {
      showToast(context, e.message, error: true);
      return false;
    }
    final force = await confirm(
      context,
      title: tr('Bucket is not empty'),
      message: tr('Delete anyway removes every object, all versions and delete '
          'markers together with the bucket. This cannot be undone.'),
      detail: e.message,
      confirmLabel: tr('Delete everything'),
      typeToConfirm: name,
    );
    if (!force || !context.mounted) return false;
    try {
      await server.deleteBucket(name, force: true);
    } on ApiException catch (e2) {
      if (context.mounted) showToast(context, e2.message, error: true);
      return false;
    }
  }
  nav.forgetBucket(name);
  if (context.mounted) showToast(context, tr('Bucket “{name}” deleted', {'name': name}));
  return true;
}

enum _Sort { name, objects, size, created }

class BucketsScreen extends StatefulWidget {
  const BucketsScreen({super.key});

  @override
  State<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends State<BucketsScreen> {
  String _query = '';
  _Sort _sort = _Sort.name;
  bool _asc = true;

  void _setSort(_Sort s) => setState(() {
        if (_sort == s) {
          _asc = !_asc;
        } else {
          _sort = s;
          _asc = s == _Sort.name;
        }
      });

  List<Bucket> _visible(List<Bucket> all) {
    final q = _query.toLowerCase();
    final list = all.where((b) => b.name.contains(q)).toList();
    int cmp(Bucket a, Bucket b) => switch (_sort) {
          _Sort.name => a.name.compareTo(b.name),
          _Sort.objects => a.objects.compareTo(b.objects),
          _Sort.size => a.usageBytes.compareTo(b.usageBytes),
          _Sort.created => a.createdAt.compareTo(b.createdAt),
        };
    list.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerController>();
    final buckets = _visible(server.buckets);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    return PageScaffold(
      title: tr('Buckets'),
      subtitle: tr('{n} buckets · {size} stored', {'n': server.buckets.length, 'size': formatBytes(server.totalUsage)}),
      actions: [
        SearchField(
          hint: tr('Filter buckets'),
          width: narrow ? 180 : 240,
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        IconButton(
          tooltip: tr('Refresh'),
          onPressed: server.refresh,
          icon: server.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.refreshCw, size: 16),
        ),
        FilledButton.icon(
          onPressed: () => createBucketFlow(context),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text(tr('New bucket')),
        ),
      ],
      body: server.error != null && server.buckets.isEmpty
          ? ErrorState(server.error!, onRetry: server.refresh)
          : !server.loadedOnce
              ? const LoadingView()
              : server.buckets.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.package,
                      title: tr('No buckets yet'),
                      message:
                          tr('Buckets hold your objects. Create one, then add an access key to use it from any S3 client.'),
                      action: FilledButton.icon(
                        onPressed: () => createBucketFlow(context),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(tr('Create bucket')),
                      ),
                    )
                  : _Table(
                      buckets: buckets,
                      narrow: narrow,
                      sort: _sort,
                      asc: _asc,
                      onSort: _setSort,
                      emptyFilter: buckets.isEmpty,
                    ),
    );
  }
}

class _Table extends StatelessWidget {
  final List<Bucket> buckets;
  final bool narrow;
  final _Sort sort;
  final bool asc;
  final ValueChanged<_Sort> onSort;
  final bool emptyFilter;

  const _Table({
    required this.buckets,
    required this.narrow,
    required this.sort,
    required this.asc,
    required this.onSort,
    required this.emptyFilter,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget head(String label, _Sort? s, {int flex = 1, bool end = false}) {
      final active = s != null && sort == s;
      final text = Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: active ? c.foreground : c.subtle));
      return Expanded(
        flex: flex,
        child: Align(
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: s == null
              ? text
              : InkWell(
                  borderRadius: AppRadius.smAll,
                  onTap: () => onSort(s),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        text,
                        if (active)
                          Icon(asc ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                              size: 12, color: c.foreground),
                      ],
                    ),
                  ),
                ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
            child: Row(
              children: [
                head('NAME', _Sort.name, flex: 4),
                if (!narrow) head('OBJECTS', _Sort.objects, flex: 2, end: true),
                head('SIZE', _Sort.size, flex: 2, end: true),
                if (!narrow) const SizedBox(width: 24),
                if (!narrow) head('QUOTA', null, flex: 3),
                if (!narrow) head('CREATED', _Sort.created, flex: 2),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          if (emptyFilter)
            EmptyState(
                compact: true,
                icon: LucideIcons.searchX,
                title: tr('No matching buckets'))
          else
            for (var i = 0; i < buckets.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _Row(bucket: buckets[i], narrow: narrow),
            ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Bucket bucket;
  final bool narrow;
  const _Row({required this.bucket, required this.narrow});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final nav = context.read<NavigationController>();
    final b = bucket;

    return InkWell(
      onTap: () => nav.go(BucketDestination(b.name)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  const IconBadge(LucideIcons.package, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (b.versioningEnabled)
                              Pill(tr('Versioned'),
                                  tone: Tone.primary,
                                  icon: LucideIcons.history),
                            if (b.publicRead)
                              Pill(tr('Public'),
                                  tone: Tone.warning, icon: LucideIcons.globe),
                            if (b.webdavEnabled)
                              Pill(tr('WebDAV'), icon: LucideIcons.hardDrive),
                            if (b.storageDir.isNotEmpty)
                              Pill(tr('Custom storage'),
                                  icon: LucideIcons.folderCog),
                            if (!b.versioningEnabled &&
                                !b.publicRead &&
                                !b.webdavEnabled &&
                                b.storageDir.isEmpty)
                              Text(tr('{n} access keys', {'n': b.credentials}),
                                  style: t.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!narrow)
              Expanded(
                flex: 2,
                child: Text(formatCount(b.objects),
                    textAlign: TextAlign.right, style: t.bodyLarge),
              ),
            Expanded(
              flex: 2,
              child: Text(formatBytes(b.usageBytes),
                  textAlign: TextAlign.right, style: t.bodyLarge),
            ),
            if (!narrow) const SizedBox(width: 24),
            if (!narrow)
              Expanded(
                flex: 3,
                child: b.hasQuota
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsageBar(b.quotaUsagePercent, height: 5),
                          const SizedBox(height: 4),
                          Text(
                              tr('{p}% of {size}', {'p': (b.quotaUsagePercent * 100).toStringAsFixed(0), 'size': formatBytes(b.quotaBytes)}),
                              style: t.bodySmall),
                        ],
                      )
                    : Text(tr('Unlimited'), style: t.bodyMedium?.copyWith(color: c.subtle)),
              ),
            if (!narrow)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(formatDate(b.createdAt), style: t.bodyMedium),
                ),
              ),
            SizedBox(
              width: 40,
              child: MoreMenu(
                children: [
                  for (final tab in BucketTab.values.take(3))
                    MenuItemButton(
                      onPressed: () => nav.go(BucketDestination(b.name, tab)),
                      child: Text(tr('Open {tab}', {'tab': tab.label.toLowerCase()})),
                    ),
                  const Divider(height: 9),
                  MenuItemButton(
                    leadingIcon:
                        Icon(LucideIcons.trash2, size: 16, color: c.danger),
                    onPressed: () => deleteBucketFlow(context, b.name),
                    child: Text(tr('Delete bucket'),
                        style: TextStyle(color: c.danger)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
