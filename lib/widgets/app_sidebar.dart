import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/server_connection.dart';
import '../providers/server_provider.dart';
import '../providers/theme_provider.dart';
import 'dialogs/add_server_dialog.dart';
import 'theme_switcher.dart';

class AppSidebar extends StatelessWidget {
  final String? activeServerId;
  final ValueChanged<ServerConnection> onServerTap;
  final VoidCallback? onDisconnect;

  // Bucket detail mode
  final String? openBucketName;
  final int activeBucketTab;
  final ValueChanged<int>? onBucketTabChanged;
  final VoidCallback? onBucketClose;

  // Settings mode
  final bool showAdmins;
  final VoidCallback? onAdminsTap;

  const AppSidebar({
    super.key,
    this.activeServerId,
    required this.onServerTap,
    this.onDisconnect,
    this.openBucketName,
    this.activeBucketTab = 0,
    this.onBucketTabChanged,
    this.onBucketClose,
    this.showAdmins = false,
    this.onAdminsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sp = context.watch<ServerProvider>();

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bucket navigation (when a bucket is open)
          if (openBucketName != null) ...[
            _BucketNav(
              bucketName: openBucketName!,
              activeTab: activeBucketTab,
              onTabChanged: onBucketTabChanged,
              onBack: onBucketClose,
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],

          // Servers header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Text('SERVERS',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    )),
                const Spacer(),
                _IconBtn(
                  icon: LucideIcons.plus,
                  tooltip: 'Add Server',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddServerDialog(),
                  ),
                ),
              ],
            ),
          ),

          // Server list (scrollable)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: sp.servers.map((server) {
                final isActive = server.id == activeServerId;
                return _ServerItem(
                  server: server,
                  isActive: isActive,
                  onTap: () => onServerTap(server),
                  onEdit: () => showDialog(
                    context: context,
                    builder: (_) => AddServerDialog(existing: server),
                  ),
                  onDelete: () => _confirmDelete(context, sp, server),
                );
              }).toList(),
            ),
          ),

          // Bottom section (always visible)
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          if (activeServerId != null && onAdminsTap != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text('SETTINGS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _NavItem(
                icon: LucideIcons.shield,
                label: 'Admin Users',
                isActive: showAdmins,
                onTap: () => onAdminsTap?.call(),
              ),
            ),
          ],
          Builder(builder: (context) {
            final tp = context.watch<ThemeProvider>();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _ThemeToggle(
                icon: tp.icon,
                label: tp.label,
                onTapWithPosition: (globalPos) {
                  ThemeSwitcher.of(context).toggleTheme(
                    globalPos,
                    () => tp.setThemeMode(tp.nextMode(context)),
                  );
                },
              ),
            );
          }),
          if (activeServerId != null && onDisconnect != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: _NavItem(
                icon: LucideIcons.logOut,
                label: 'Disconnect',
                isActive: false,
                onTap: onDisconnect!,
                isDestructive: true,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
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
}

// ========================= Bucket Nav =========================
class _BucketNav extends StatelessWidget {
  final String bucketName;
  final int activeTab;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onBack;

  const _BucketNav({
    required this.bucketName,
    required this.activeTab,
    this.onTabChanged,
    this.onBack,
  });

  static final _tabs = [
    (LucideIcons.info, 'Overview'),
    (LucideIcons.folderOpen, 'Files'),
    (LucideIcons.key, 'Credentials'),
    (LucideIcons.settings, 'Settings'),
    (LucideIcons.timer, 'Lifecycle'),
    (LucideIcons.webhook, 'Webhooks'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + bucket name
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                onPressed: onBack,
                tooltip: 'Back to dashboard',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  bucketName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Nav items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: List.generate(_tabs.length, (i) {
              final (icon, label) = _tabs[i];
              final isActive = activeTab == i;
              return _NavItem(
                icon: icon,
                label: label,
                isActive: isActive,
                onTap: () => onTabChanged?.call(i),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ========================= Nav Item =========================
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isDestructive
        ? theme.colorScheme.error
        : widget.isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : _hovering
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  inherit: true,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isDestructive
                      ? theme.colorScheme.error
                      : widget.isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================= Server Item =========================
class _ServerItem extends StatefulWidget {
  final ServerConnection server;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerItem({
    required this.server,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ServerItem> createState() => _ServerItemState();
}

class _ServerItemState extends State<_ServerItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : _hovering
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? const Color(0xFF22C55E)
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.server.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      widget.server.url
                          .replaceAll('http://', '')
                          .replaceAll('https://', ''),
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_hovering) ...[
                _IconBtn(
                    icon: LucideIcons.pencil,
                    tooltip: 'Edit',
                    size: 14,
                    onPressed: widget.onEdit),
                _IconBtn(
                    icon: LucideIcons.x,
                    tooltip: 'Delete',
                    size: 14,
                    onPressed: widget.onDelete),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onPressed;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.size = 16,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ThemeToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  final ValueChanged<Offset>? onTapWithPosition;

  const _ThemeToggle({
    required this.icon,
    required this.label,
    this.onTapWithPosition,
  });

  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (details) {
          widget.onTapWithPosition?.call(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hovering
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Theme',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w400)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(widget.label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
