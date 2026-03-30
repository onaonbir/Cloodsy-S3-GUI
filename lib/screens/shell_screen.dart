import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/server_connection.dart';
import '../providers/server_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bucket_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/window_title_bar.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/empty_state.dart';
import '../widgets/dialogs/add_server_dialog.dart';
import 'dashboard_screen.dart';
import 'bucket_detail_screen.dart';
import 'admin_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  String? _connectingId;
  String? _activeServerId;
  bool _connected = false;
  String? _openBucketName;
  int _bucketTab = 0;
  bool _showAdmins = false;

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }
 
  bool get _isWide => MediaQuery.of(context).size.width >= 900;

  Future<void> _connectToServer(ServerConnection server) async {
    if (_connectingId != null) return;
    setState(() => _connectingId = server.id);

    final auth = context.read<AuthProvider>();
    final success = await auth.connectToServer(server);

    if (mounted) {
      setState(() {
        _connectingId = null;
        if (success) {
          _activeServerId = server.id;
          _connected = true;
          _openBucketName = null;
          _bucketTab = 0;
        }
      });
      if (success) {
        context.read<BucketProvider>().fetchBuckets();
        context.read<BucketProvider>().fetchStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Connection failed')),
        );
      }
    }
  }

  void _disconnect() {
    context.read<AuthProvider>().disconnect();
    setState(() {
      _activeServerId = null;
      _connected = false;
      _openBucketName = null;
      _bucketTab = 0;
      _showAdmins = false;
    });
  }

  void _openBucket(String name) {
    if (_isWide && _isDesktop) {
      setState(() {
        _openBucketName = name;
        _bucketTab = 0;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BucketDetailScreen(bucketName: name)),
      );
    }
  }

  void _closeBucket() {
    setState(() {
      _openBucketName = null;
      _bucketTab = 0;
      _showAdmins = false;
    });
    context.read<BucketProvider>().fetchBuckets();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<ServerProvider>();
    final activeServer = _activeServerId != null
        ? sp.servers.where((s) => s.id == _activeServerId).firstOrNull
        : null;

    if (_isWide && _isDesktop) {
      return _buildDesktopLayout(activeServer);
    }
    return _buildMobileLayout(activeServer);
  }

  Widget _buildDesktopLayout(ServerConnection? activeServer) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          WindowTitleBar(serverName: activeServer?.name),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: Row(
              children: [
                AppSidebar(
                  activeServerId: _activeServerId,
                  onServerTap: _connectToServer,
                  onDisconnect: _activeServerId != null ? _disconnect : null,
                  openBucketName: _openBucketName,
                  activeBucketTab: _bucketTab,
                  onBucketTabChanged: (i) => setState(() {
                    _bucketTab = i;
                    _showAdmins = false;
                  }),
                  onBucketClose: _closeBucket,
                  showAdmins: _showAdmins,
                  onAdminsTap: () => setState(() {
                    _showAdmins = true;
                    _openBucketName = null;
                  }),
                ),
                Expanded(child: _desktopContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopContent() {
    if (!_connected) return _buildWelcome();

    if (_showAdmins) {
      return const AdminScreen();
    }

    if (_openBucketName != null) {
      return BucketDetailScreen(
        key: ValueKey('$_openBucketName-$_bucketTab'),
        bucketName: _openBucketName!,
        embedded: true,
        initialTab: _bucketTab,
        onBack: _closeBucket,
      );
    }

    return DashboardScreen(
      embedded: true,
      onOpenBucket: _openBucket,
    );
  }

  Widget _buildMobileLayout(ServerConnection? activeServer) {
    final sp = context.watch<ServerProvider>();
    final tp = context.watch<ThemeProvider>();

    if (_connected) {
      return DashboardScreen(
        embedded: false,
        onBack: _disconnect,
        serverName: activeServer?.name,
        onOpenBucket: _openBucket,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloodsy S3'),
        actions: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context, builder: (_) => const AddServerDialog()),
        child: const Icon(LucideIcons.plus),
      ),
      body: sp.servers.isEmpty
          ? EmptyState(
              icon: LucideIcons.server,
              title: 'No servers',
              subtitle: 'Add a server to get started',
              action: FilledButton.icon(
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddServerDialog()),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add Server'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: sp.servers.map((server) {
                final isConnecting = _connectingId == server.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.server, size: 18),
                    ),
                    title: Text(server.name),
                    subtitle: Text(server.url,
                        style: Theme.of(context).textTheme.bodySmall),
                    trailing: isConnecting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.pencil, size: 16),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => AddServerDialog(existing: server),
                                ),
                                tooltip: 'Edit',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: Icon(LucideIcons.trash2,
                                    size: 16, color: Theme.of(context).colorScheme.error),
                                onPressed: () => _deleteMobileServer(context, sp, server),
                                tooltip: 'Delete',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                    onTap: isConnecting
                        ? null
                        : () => _connectToServer(server),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _deleteMobileServer(
      BuildContext context, ServerProvider sp, ServerConnection server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text("Remove '${server.name}'?"),
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
    if (confirmed == true) sp.deleteServer(server.id);
  }

  Widget _buildWelcome() {
    final theme = Theme.of(context);
    final sp = context.watch<ServerProvider>();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloud,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Select a server', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Choose a server from the sidebar to manage',
              style: theme.textTheme.bodySmall),
          if (sp.servers.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AddServerDialog()),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add Server'),
            ),
          ],
        ],
      ),
    );
  }
}
