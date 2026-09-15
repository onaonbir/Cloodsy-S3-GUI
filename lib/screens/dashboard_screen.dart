import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bucket_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/stat_card.dart';
import '../widgets/bucket_card.dart' show BucketCard, formatBytes;
import '../widgets/empty_state.dart';
import '../widgets/dialogs/create_bucket_dialog.dart';
import 'bucket_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onBack;
  final String? serverName;
  final ValueChanged<String>? onOpenBucket;

  const DashboardScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.serverName,
    this.onOpenBucket,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final bp = context.read<BucketProvider>();
    await Future.wait([bp.fetchStatus(), bp.fetchBuckets()]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final bp = context.watch<BucketProvider>();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: widget.onBack != null
                  ? IconButton(
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: widget.onBack)
                  : null,
              title: Text(widget.serverName ?? 'Dashboard'),
              actions: _actions(auth, bp),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateBucket(context),
        tooltip: 'New Bucket',
        child: const Icon(LucideIcons.plus),
      ),
      body: Column(
        children: [
          // Embedded header
          if (widget.embedded)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          auth.username != null
                              ? 'Logged in as ${auth.username}'
                              : '',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (bp.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 20),
                    onPressed: _loadData,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Update banner
                  if (bp.updateAvailable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.download,
                              size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Server update available: v${bp.latestVersion} (current: v${bp.serverStatus?.version})',
                              style: const TextStyle(
                                  color: Color(0xFF92400E), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Stats row
                  _buildStats(context, bp),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Buckets',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${bp.buckets.length}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (bp.buckets.isEmpty && !bp.isLoading)
                    const EmptyState(
                      icon: LucideIcons.box,
                      title: 'No buckets yet',
                      subtitle: 'Create your first bucket to get started',
                    )
                  else
                    ...bp.buckets.map((bucket) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: BucketCard(
                            bucket: bucket,
                            onTap: () => _openBucket(context, bucket.name),
                            onDelete: () =>
                                _confirmDelete(context, bucket.name),
                          ),
                        )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, BucketProvider bp) {
    final totalObjects =
        bp.buckets.fold<int>(0, (sum, b) => sum + b.objects);
    final totalUsage =
        bp.buckets.fold<int>(0, (sum, b) => sum + b.usageBytes);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 160,
          child: StatCard(
            label: 'Status',
            value: bp.serverStatus?.isOk == true ? 'Online' : '...',
            icon: LucideIcons.circle,
            color: bp.serverStatus?.isOk == true
                ? const Color(0xFF22C55E)
                : Colors.grey,
          ),
        ),
        SizedBox(
          width: 160,
          child: StatCard(
            label: 'Buckets',
            value: '${bp.buckets.length}',
            icon: LucideIcons.box,
          ),
        ),
        SizedBox(
          width: 160,
          child: StatCard(
            label: 'Objects',
            value: '$totalObjects',
            icon: LucideIcons.fileText,
          ),
        ),
        SizedBox(
          width: 160,
          child: StatCard(
            label: 'Total Size',
            value: formatBytes(totalUsage),
            icon: LucideIcons.hardDrive,
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(AuthProvider auth, BucketProvider bp) {
    final tp = context.watch<ThemeProvider>();
    return [
      IconButton(
        icon: const Icon(LucideIcons.refreshCw, size: 20),
        onPressed: _loadData,
        tooltip: 'Refresh',
      ),
      Builder(builder: (ctx) {
        return IconButton(
          icon: Icon(tp.icon, size: 20),
          onPressed: () {
            final box = ctx.findRenderObject() as RenderBox;
            final pos = box.localToGlobal(box.size.center(Offset.zero));
            ThemeSwitcher.of(context).toggleTheme(
              pos, () => tp.setThemeMode(tp.nextMode(context)));
          },
          tooltip: 'Theme: ${tp.label}',
        );
      }),
    ];
  }

  void _openBucket(BuildContext context, String name) {
    if (widget.onOpenBucket != null) {
      widget.onOpenBucket!(name);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BucketDetailScreen(bucketName: name)),
      ).then((_) => _loadData());
    }
  }

  Future<void> _showCreateBucket(BuildContext context) async {
    final result = await showDialog<bool>(
        context: context, builder: (_) => const CreateBucketDialog());
    if (result == true) _loadData();
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bucket'),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final bp = context.read<BucketProvider>();
    var success = await bp.deleteBucket(name);
    if (!context.mounted) return;

    // 409 with a "not empty" message: objects, old versions or delete
    // markers remain. Offer a forced delete that removes them too. A 409
    // for a busy bucket (move/reprocess running) is just reported.
    final busy = bp.error?.startsWith('bucket is busy') ?? false;
    if (!success && bp.errorStatus == 409 && !busy) {
      final force = await _confirmForceDelete(context, name, bp.error);
      if (force != true || !context.mounted) return;
      success = await bp.deleteBucket(name, force: true);
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "'$name' deleted" : bp.error ?? 'Failed')));
  }

  Future<bool?> _confirmForceDelete(
      BuildContext context, String name, String? serverMessage) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bucket Not Empty'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("'$name' still contains objects, older object versions "
                  'or delete markers, so the server refused to remove it.'),
              if (serverMessage != null && serverMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(serverMessage,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace')),
              ],
              const SizedBox(height: 14),
              Text(
                'Delete anyway permanently removes every object, all '
                'versions and delete markers together with the bucket. '
                'This cannot be undone.',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete anyway'),
          ),
        ],
      ),
    );
  }
}
