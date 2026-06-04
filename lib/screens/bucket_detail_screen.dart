import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/bucket_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/bucket_card.dart' show formatBytes;
import '../widgets/theme_switcher.dart';
import '../widgets/empty_state.dart';
import '../widgets/dialogs/create_credential_dialog.dart';
import '../widgets/dialogs/set_quota_dialog.dart';
import '../widgets/dialogs/set_storage_dialog.dart';
import '../widgets/dialogs/add_lifecycle_dialog.dart';
import '../widgets/dialogs/add_webhook_dialog.dart';
import '../models/s3_object.dart';

class BucketDetailScreen extends StatefulWidget {
  final String bucketName;
  final bool embedded;
  final int initialTab;
  final VoidCallback? onBack;

  const BucketDetailScreen({
    super.key,
    required this.bucketName,
    this.embedded = false,
    this.initialTab = 0,
    this.onBack,
  });

  @override
  State<BucketDetailScreen> createState() => _BucketDetailScreenState();
}

class _BucketDetailScreenState extends State<BucketDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 6, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void didUpdateWidget(BucketDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bucketName != widget.bucketName) {
      _loaded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final bp = context.read<BucketProvider>();
    await Future.wait([
      bp.fetchBucketDetail(widget.bucketName),
      bp.fetchCredentials(widget.bucketName),
      bp.fetchLifecycleRules(widget.bucketName),
      bp.fetchWebhooks(widget.bucketName),
    ]);
    if (mounted) setState(() => _loaded = true);
  }

  List<Widget> get _tabContents => [
        _OverviewTab(bucket: context.watch<BucketProvider>().selectedBucket),
        _FilesTab(bucketName: widget.bucketName),
        _CredentialsTab(bucketName: widget.bucketName),
        _SettingsTab(bucketName: widget.bucketName),
        _LifecycleTab(bucketName: widget.bucketName),
        _WebhooksTab(bucketName: widget.bucketName),
      ];

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final theme = Theme.of(context);

    // Embedded in desktop shell — sidebar has tabs, content is just the active tab
    if (widget.embedded) {
      if (!_loaded && bp.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final tabIndex = widget.initialTab.clamp(0, 5);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with bucket name
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                Text(widget.bucketName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ['Overview', 'Files', 'Credentials', 'Settings', 'Lifecycle', 'Webhooks'][tabIndex],
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(child: _tabContents[tabIndex]),
        ],
      );
    }

    // Standalone (mobile) — full Scaffold with tab bar
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.bucketName),
        actions: [
          if (bp.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
          Builder(builder: (ctx) {
            final tp = ctx.watch<ThemeProvider>();
            return IconButton(
              icon: Icon(tp.icon, size: 20),
              onPressed: () {
                final switcher = ThemeSwitcher.maybeOf(ctx);
                if (switcher != null) {
                  final box = ctx.findRenderObject() as RenderBox;
                  final pos = box.localToGlobal(box.size.center(Offset.zero));
                  switcher.toggleTheme(
                    pos, () => tp.setThemeMode(tp.nextMode(ctx)));
                } else {
                  tp.setThemeMode(tp.nextMode(ctx));
                }
              },
              tooltip: 'Theme: ${tp.label}',
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Files'),
            Tab(text: 'Credentials'),
            Tab(text: 'Settings'),
            Tab(text: 'Lifecycle'),
            Tab(text: 'Webhooks'),
          ],
        ),
      ),
      body: bp.isLoading && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabContents,
            ),
    );
  }
}

// ========================= Overview Tab =========================
class _OverviewTab extends StatelessWidget {
  final dynamic bucket;
  const _OverviewTab({required this.bucket});

  @override
  Widget build(BuildContext context) {
    if (bucket == null) return const SizedBox();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 500;
            final rows = [
              _RowData('Name', bucket.name),
              _RowData('ID', '${bucket.id}'),
              _RowData('Created', bucket.createdAt),
              _RowData('Objects', '${bucket.objects}'),
              _RowData('Usage', formatBytes(bucket.usageBytes)),
              _RowData('Quota', bucket.quotaBytes > 0
                  ? formatBytes(bucket.quotaBytes) : 'Unlimited'),
              _RowData('Versioning', bucket.versioningDisplay),
              _RowData('Storage', bucket.storagePath ??
                  (bucket.storageDir.isNotEmpty
                      ? '${bucket.storageDir} (custom)' : 'Default')),
              _RowData('Credentials', '${bucket.credentials}'),
            ];

            if (wide) {
              // Two-column layout
              return Column(
                children: [
                  for (int i = 0; i < rows.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: _row(theme, rows[i])),
                          if (i + 1 < rows.length)
                            Expanded(child: _row(theme, rows[i + 1]))
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                ],
              );
            }
            return Column(children: rows.map((r) => _row(theme, r)).toList());
          }),
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, _RowData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(data.label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(data.value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _RowData {
  final String label, value;
  _RowData(this.label, this.value);
}

// ========================= Credentials Tab =========================
class _CredentialsTab extends StatefulWidget {
  final String bucketName;
  const _CredentialsTab({required this.bucketName});

  @override
  State<_CredentialsTab> createState() => _CredentialsTabState();
}

class _CredentialsTabState extends State<_CredentialsTab> {
  final Set<int> _visibleSecrets = {};

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _createCredential(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: bp.credentials.isEmpty
          ? const EmptyState(
              icon: LucideIcons.key,
              title: 'No credentials',
              subtitle: 'Create an access key to connect via S3 SDK',
            )
          : LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 600;
              return ListView.builder(
                padding: EdgeInsets.all(wide ? 20 : 16),
                itemCount: bp.credentials.length,
                itemBuilder: (context, index) {
                  final cred = bp.credentials[index];
                  final showSecret = _visibleSecrets.contains(cred.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(LucideIcons.trash2,
                                size: 18, color: theme.colorScheme.error),
                            onPressed: () =>
                                _deleteCredential(context, cred.accessKey),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete',
                          ),
                        ),
                        Padding(
                      padding: EdgeInsets.all(wide ? 18 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              if (cred.name.isNotEmpty) ...[
                                Flexible(
                                  child: Text(cred.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cred.isReadOnly
                                      ? theme.colorScheme.tertiary
                                          .withValues(alpha: 0.1)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(cred.permission,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: cred.isReadOnly
                                          ? theme.colorScheme.tertiary
                                          : theme.colorScheme.onSurface,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Keys — side by side on wide, stacked on narrow
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _keyField(context, 'Access Key',
                                    cred.accessKey, cred.accessKey)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _keyField(
                                    context,
                                    'Secret Key',
                                    showSecret
                                        ? (cred.secretKey ?? '—')
                                        : '\u2022' * 32,
                                    cred.secretKey ?? '',
                                    toggleIcon: _toggleBtn(cred.id, showSecret),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _keyField(context, 'Access Key', cred.accessKey,
                                cred.accessKey),
                            const SizedBox(height: 8),
                            _keyField(
                              context,
                              'Secret Key',
                              showSecret
                                  ? (cred.secretKey ?? '—')
                                  : '\u2022' * 32,
                              cred.secretKey ?? '',
                              toggleIcon: _toggleBtn(cred.id, showSecret),
                            ),
                          ],
                        ],
                      ),
                    ),
                      ],
                    ),
                  );
                },
              );
            }),
    );
  }

  Widget _toggleBtn(int credId, bool showSecret) {
    return IconButton(
      icon: Icon(
          showSecret ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 15),
      onPressed: () => setState(() {
        showSecret
            ? _visibleSecrets.remove(credId)
            : _visibleSecrets.add(credId);
      }),
      visualDensity: VisualDensity.compact,
      tooltip: showSecret ? 'Hide' : 'Show',
    );
  }

  Widget _keyField(BuildContext ctx, String label, String display,
      String copyValue,
      {Widget? toggleIcon}) {
    final theme = Theme.of(ctx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(display,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            if (toggleIcon != null) toggleIcon,
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 14),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text('$label copied')));
              },
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createCredential(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateCredentialDialog(bucketName: widget.bucketName),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credential created')),
      );
    }
  }

  Future<void> _deleteCredential(BuildContext ctx, String accessKey) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Credential'),
        content: Text('Delete access key $accessKey?'),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctx.mounted) {
      await ctx
          .read<BucketProvider>()
          .deleteCredential(accessKey, widget.bucketName);
    }
  }
}

// ========================= Settings Tab =========================
class _SettingsTab extends StatelessWidget {
  final String bucketName;
  const _SettingsTab({required this.bucketName});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final bucket = bp.selectedBucket;
    if (bucket == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 500;
        final tiles = [
          _tile(context,
              icon: LucideIcons.gauge,
              title: 'Quota',
              subtitle: bucket.quotaBytes > 0
                  ? formatBytes(bucket.quotaBytes)
                  : 'Unlimited',
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => SetQuotaDialog(bucketName: bucketName))),
          _tile(context,
              icon: LucideIcons.folder,
              title: 'Storage Directory',
              subtitle: bucket.storageDir.isNotEmpty
                  ? '${bucket.storageDir} (custom)'
                  : 'Default',
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => SetStorageDialog(bucketName: bucketName))),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.gitBranch),
              title: const Text('Versioning'),
              subtitle: Text(bucket.versioningDisplay),
              trailing: Switch(
                value: bucket.versioning == 'Enabled',
                onChanged: (enabled) {
                  bp.setVersioning(
                      bucketName, enabled ? 'Enabled' : 'Suspended');
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.globe),
              title: const Text('Public Read'),
              subtitle: Text(bucket.publicRead
                  ? 'Anonymous GET allowed'
                  : 'Signed access only'),
              trailing: Switch(
                value: bucket.publicRead,
                onChanged: (enabled) {
                  bp.setPublicRead(bucketName, enabled);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.hardDrive),
              title: const Text('WebDAV Access'),
              subtitle: Text(bucket.webdavEnabled
                  ? 'Mountable via WebDAV'
                  : 'WebDAV disabled'),
              trailing: Switch(
                value: bucket.webdavEnabled,
                onChanged: (enabled) {
                  bp.setWebdavEnabled(bucketName, enabled);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Image Optimization'),
              subtitle: const Text('Regenerate optimized variants'),
              trailing: FilledButton(
                onPressed: () async {
                  final ok = await bp.reprocessImages(bucketName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'Reprocessing started'
                          : 'Reprocess failed'),
                    ));
                  }
                },
                child: const Text('Reprocess'),
              ),
            ),
          ),
          if (bucket.webdavEnabled && bp.webdavMountUrl != null)
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons.link),
                title: const Text('WebDAV Mount'),
                subtitle: Text(
                    '${bp.webdavMountUrl}\nUser: access key  ·  Password: secret key'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(LucideIcons.copy),
                  tooltip: 'Copy mount URL',
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: bp.webdavMountUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mount URL copied')),
                    );
                  },
                ),
              ),
            ),
        ];

        if (wide) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tiles
                .map((t) => SizedBox(width: constraints.maxWidth / 2 - 12, child: t))
                .toList(),
          );
        }
        return Column(
          children: tiles.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8), child: t)).toList(),
        );
      }),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: onTap,
      ),
    );
  }
}

// ========================= Lifecycle Tab =========================
class _LifecycleTab extends StatelessWidget {
  final String bucketName;
  const _LifecycleTab({required this.bucketName});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => showDialog(
            context: context,
            builder: (_) => AddLifecycleDialog(bucketName: bucketName)),
        child: const Icon(LucideIcons.plus),
      ),
      body: bp.lifecycleRules.isEmpty
          ? const EmptyState(
              icon: LucideIcons.timer,
              title: 'No lifecycle rules',
              subtitle: 'Add rules to auto-expire objects',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: bp.lifecycleRules.length,
              itemBuilder: (context, index) {
                final rule = bp.lifecycleRules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(LucideIcons.timer),
                    title: Text(rule.displayName),
                    subtitle: Text(
                        '${rule.expirationDays} days / Prefix: ${rule.prefixDisplay}'),
                    trailing: IconButton(
                      icon: Icon(LucideIcons.trash2,
                          size: 18, color: theme.colorScheme.error),
                      onPressed: () => bp.deleteLifecycleRules(bucketName,
                          prefix: rule.prefix),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ========================= Webhooks Tab =========================
class _WebhooksTab extends StatelessWidget {
  final String bucketName;
  const _WebhooksTab({required this.bucketName});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => showDialog(
            context: context,
            builder: (_) => AddWebhookDialog(bucketName: bucketName)),
        child: const Icon(LucideIcons.plus),
      ),
      body: bp.webhooks.isEmpty
          ? const EmptyState(
              icon: LucideIcons.webhook,
              title: 'No webhooks',
              subtitle: 'Add webhooks for event notifications',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: bp.webhooks.length,
              itemBuilder: (context, index) {
                final hook = bp.webhooks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(LucideIcons.webhook,
                        color: hook.active
                            ? const Color(0xFF22C55E)
                            : theme.colorScheme.outline),
                    title: Text(hook.displayName,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(hook.name.isNotEmpty
                        ? '${hook.url}\nEvents: ${hook.eventTypes}'
                        : 'Events: ${hook.eventTypes}'),
                    isThreeLine: hook.name.isNotEmpty,
                    trailing: IconButton(
                      icon: Icon(LucideIcons.trash2,
                          size: 18, color: theme.colorScheme.error),
                      onPressed: () => bp.deleteWebhook(hook.id, bucketName),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ========================= Files Tab =========================
class _FilesTab extends StatefulWidget {
  final String bucketName;
  const _FilesTab({required this.bucketName});

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  String _prefix = '';
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context.read<BucketProvider>().fetchObjects(widget.bucketName, prefix: _prefix);
  }

  void _navigateTo(String prefix) {
    setState(() {
      _prefix = prefix;
      _selected.clear();
    });
    _load();
  }

  List<String> get _breadcrumbs {
    if (_prefix.isEmpty) return [];
    return _prefix.split('/').where((p) => p.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final theme = Theme.of(context);
    final result = bp.objectList;
    final loading = bp.objectsLoading;

    return Column(
      children: [
        // Breadcrumb bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Breadcrumb
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _crumb(context, 'Root', '', _prefix.isEmpty),
                      ..._breadcrumbs.asMap().entries.map((entry) {
                        final i = entry.key;
                        final part = entry.value;
                        final isLast = i == _breadcrumbs.length - 1;
                        final target =
                            '${_breadcrumbs.sublist(0, i + 1).join('/')}/';
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(LucideIcons.chevronRight,
                                  size: 16, color: theme.colorScheme.outline),
                            ),
                            _crumb(context, part, target, isLast),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (_selected.isNotEmpty) ...[
                IconButton(
                  onPressed: _deleteSelected,
                  icon: Icon(LucideIcons.trash2,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete ${_selected.length} files',
                ),
              ],
              IconButton(
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        // Table
        Expanded(child: _buildTable(context, result, loading, theme)),
      ],
    );
  }

  Widget _crumb(BuildContext ctx, String label, String target, bool isActive) {
    final theme = Theme.of(ctx);
    return InkWell(
      onTap: isActive ? null : () => _navigateTo(target),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.primary,
            )),
      ),
    );
  }

  Widget _buildTable(BuildContext context, ObjectListResult? result,
      bool loading, ThemeData theme) {
    if (result == null && loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final folders = result?.prefixes ?? [];
    final files = result?.objects ?? [];

    if (folders.isEmpty && files.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.folderOpen,
        title: 'Empty',
        subtitle: 'No files in this location',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(44),   // checkbox / icon
          1: FlexColumnWidth(4),     // name
          2: FixedColumnWidth(100),  // size
          3: FixedColumnWidth(90),   // type
          4: FixedColumnWidth(110),  // date
          5: FixedColumnWidth(48),   // actions
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            children: [
              const SizedBox(height: 44),
              _hdr('Name'),
              _hdr('Size', align: TextAlign.right),
              _hdr('Type'),
              _hdr('Modified'),
              const SizedBox(),
            ],
          ),
          // Folders
          ...folders.map((p) {
            final name = p.substring(_prefix.length);
            return TableRow(
              decoration: _rowBorder(theme),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Icon(LucideIcons.folder, size: 22, color: Color(0xFF3B82F6)),
                ),
                InkWell(
                  onTap: () => _navigateTo(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(name,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500)),
                  ),
                ),
                Text('—', style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right),
                Text('Folder', style: theme.textTheme.bodyMedium),
                const Text(''),
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      size: 18, color: theme.colorScheme.error),
                  onPressed: () => _confirmDeleteFolder(context, p, name),
                  tooltip: 'Delete folder',
                ),
              ],
            );
          }),
          // Files
          ...files.map((obj) {
            final sel = _selected.contains(obj.key);
            return TableRow(
              decoration: BoxDecoration(
                color: sel
                    ? theme.colorScheme.primary.withValues(alpha: 0.04)
                    : null,
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5))),
              ),
              children: [
                Checkbox(
                  value: sel,
                  onChanged: (v) => setState(() {
                    v == true
                        ? _selected.add(obj.key)
                        : _selected.remove(obj.key);
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(_fileIcon(obj.extension),
                          size: 20, color: theme.colorScheme.outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(obj.fileName,
                            style: theme.textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                Text(formatBytes(obj.size),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right),
                Text(_shortType(obj.contentType),
                    style: theme.textTheme.bodyMedium),
                Text(_shortDate(obj.lastModified),
                    style: theme.textTheme.bodyMedium),
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      size: 18, color: theme.colorScheme.error),
                  onPressed: () => _confirmDelete(context, obj.key),
                  tooltip: 'Delete',
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _rowBorder(ThemeData theme) => BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      );

  Widget _hdr(String text, {TextAlign align = TextAlign.left}) {
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            textAlign: align,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
    });
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'svg':
        return LucideIcons.image;
      case 'pdf':
        return LucideIcons.fileText;
      case 'mp4': case 'mov': case 'avi': case 'mkv':
        return LucideIcons.video;
      case 'mp3': case 'wav': case 'flac': case 'ogg':
        return LucideIcons.music;
      case 'zip': case 'tar': case 'gz': case 'rar': case '7z':
        return LucideIcons.fileArchive;
      case 'json': case 'xml': case 'yaml': case 'yml':
        return LucideIcons.fileCode;
      case 'txt': case 'md': case 'log':
        return LucideIcons.fileText;
      default:
        return LucideIcons.file;
    }
  }

  String _shortType(String ct) {
    if (ct.isEmpty) return '—';
    final slash = ct.indexOf('/');
    return slash > 0 ? ct.substring(0, slash) : ct;
  }

  String _shortDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Object'),
        content: Text('Delete "$key"?'),
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
    if (confirmed == true && context.mounted) {
      final success =
          await context.read<BucketProvider>().deleteObject(widget.bucketName, key);
      if (success && context.mounted) {
        setState(() => _selected.remove(key));
        _load();
      }
    }
  }

  Future<void> _confirmDeleteFolder(
      BuildContext context, String prefix, String folderName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content:
            Text('Delete folder "$folderName" and all its contents?'),
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
    if (confirmed == true && context.mounted) {
      final success = await context
          .read<BucketProvider>()
          .deletePrefix(widget.bucketName, prefix);
      if (success && context.mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$folderName" deleted')),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Objects'),
        content: Text('Delete ${_selected.length} selected objects?'),
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
    if (confirmed == true && mounted) {
      final bp = context.read<BucketProvider>();
      for (final key in _selected.toList()) {
        await bp.deleteObject(widget.bucketName, key);
      }
      setState(() => _selected.clear());
      _load();
    }
  }
}
