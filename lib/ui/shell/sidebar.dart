import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/server_connection.dart';
import '../../state/gui_update_controller.dart';
import '../../state/navigation_controller.dart';
import '../../state/server_controller.dart';
import '../../state/servers_controller.dart';
import '../../state/session_controller.dart';
import '../../state/transfers_controller.dart';
import '../dialogs/server_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

IconData bucketTabIcon(BucketTab t) => switch (t) {
  BucketTab.overview => LucideIcons.layoutDashboard,
  BucketTab.files => LucideIcons.folderOpen,
  BucketTab.access => LucideIcons.keyRound,
  BucketTab.settings => LucideIcons.slidersHorizontal,
  BucketTab.lifecycle => LucideIcons.timer,
  BucketTab.webhooks => LucideIcons.webhook,
};

/// Persistent navigation. Every destination is always one click away.
class Sidebar extends StatelessWidget {
  /// Called after a navigation tap (closes the drawer on narrow layouts).
  final VoidCallback? onNavigate;
  final VoidCallback? onTransfersTap;
  final VoidCallback? onSearch;

  const Sidebar({
    super.key,
    this.onNavigate,
    this.onTransfersTap,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.watch<NavigationController>();
    final server = context.watch<ServerController>();
    final servers = context.watch<ServersController>();
    final updates = context.watch<GuiUpdateController>();
    final status = server.status;
    final current = nav.current;
    final openBucket = nav.openBucket;

    void go(Destination d) {
      nav.go(d);
      onNavigate?.call();
    }

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 12, 10, 6),
            child: ServerSwitcher(),
          ),
          if (onSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
              child: _SearchButton(onTap: onSearch!),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              children: [
                _NavItem(
                  icon: LucideIcons.layoutGrid,
                  label: tr('Dashboard'),
                  selected: current is DashboardDestination,
                  onTap: () => go(const DashboardDestination()),
                ),
                _NavItem(
                  icon: LucideIcons.package,
                  label: tr('Buckets'),
                  trailing: server.buckets.isEmpty
                      ? null
                      : '${server.buckets.length}',
                  selected: current is BucketsDestination,
                  onTap: () => go(const BucketsDestination()),
                ),
                if (openBucket != null)
                  _NavItem(
                    icon: LucideIcons.cornerDownRight,
                    label: openBucket,
                    indent: true,
                    selected: true,
                    onTap: () => go(
                      BucketDestination(
                        openBucket,
                        (current as BucketDestination).tab,
                      ),
                    ),
                    onClose: () => go(const BucketsDestination()),
                  ),
                _SectionLabel(tr('Server')),
                _NavItem(
                  icon: LucideIcons.users,
                  label: tr('Admin users'),
                  selected: current is AdminsDestination,
                  onTap: () => go(const AdminsDestination()),
                ),
                for (final (page, icon, enabled) in [
                  (
                    ServerPage.sessions,
                    LucideIcons.monitorSmartphone,
                    status?.canSessions ?? false,
                  ),
                  (
                    ServerPage.logs,
                    LucideIcons.scrollText,
                    status?.canLogs ?? false,
                  ),
                  (
                    ServerPage.metrics,
                    LucideIcons.chartColumn,
                    status?.canMetrics ?? false,
                  ),
                  (
                    ServerPage.maintenance,
                    LucideIcons.stethoscope,
                    status?.canMaintenance ?? false,
                  ),
                  (
                    ServerPage.config,
                    LucideIcons.fileCog,
                    status?.canConfig ?? false,
                  ),
                ])
                  if (enabled)
                    _NavItem(
                      icon: icon,
                      label: page.label,
                      selected:
                          current is ServerPageDestination &&
                          current.page == page,
                      onTap: () => go(ServerPageDestination(page)),
                    ),
                _SectionLabel(tr('App')),
                if (servers.servers.length > 1)
                  _NavItem(
                    icon: LucideIcons.layers,
                    label: ServerPage.servers.label,
                    selected:
                        current is ServerPageDestination &&
                        current.page == ServerPage.servers,
                    onTap: () =>
                        go(const ServerPageDestination(ServerPage.servers)),
                  ),
                _NavItem(
                  icon: LucideIcons.settings,
                  label: tr('Settings'),
                  trailing: updates.available ? '●' : null,
                  selected: current is SettingsDestination,
                  onTap: () => go(const SettingsDestination()),
                ),
              ],
            ),
          ),
          _TransfersIndicator(onTap: onTransfersTap),
          const _AccountFooter(),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 14, color: c.subtle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Search…'),
                  style: t.bodyMedium?.copyWith(color: c.subtle),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: c.hover,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  'Ctrl K',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10.5,
                    color: c.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool indent;
  final String? trailing;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = false,
    this.trailing,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(left: indent ? 14 : 0, bottom: 2),
      child: Material(
        color: selected ? c.selected : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          hoverColor: c.hover,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: indent ? 15 : 17,
                  color: selected ? c.primary : c.muted,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      fontSize: indent ? 13 : 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? c.foreground : c.muted,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: t.labelMedium?.copyWith(color: c.subtle),
                  ),
                if (onClose != null)
                  _TinyIconButton(
                    icon: LucideIcons.x,
                    tooltip: tr('Close bucket'),
                    onTap: onClose!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      iconSize: 13,
      style: IconButton.styleFrom(minimumSize: const Size(24, 24)),
      icon: Icon(icon),
      onPressed: onTap,
    ),
  );
}

/// Current server with a menu to switch, add or disconnect.
class ServerSwitcher extends StatelessWidget {
  const ServerSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final session = context.watch<SessionController>();
    final servers = context.watch<ServersController>();
    final status = context.watch<ServerController>().status;
    final current = session.server;

    Future<void> switchTo(ServerConnection s) async {
      final ok = await session.connect(s);
      if (!ok && context.mounted && session.error != null) {
        showToast(context, session.error!, error: true);
      }
    }

    final host = Uri.tryParse(current?.url ?? '');
    final address = host == null
        ? ''
        : '${host.host}${host.hasPort ? ':${host.port}' : ''}';

    // The menu is as wide as the switcher itself (sidebar width minus
    // padding), and long names wrap instead of being cut with "…".
    const menuWidth = 232.0;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
      ),
      menuChildren: [
        for (final s in servers.servers)
          MenuItemButton(
            leadingIcon: Icon(
              s.id == current?.id
                  ? LucideIcons.circleCheck
                  : LucideIcons.server,
              size: 16,
              color: s.id == current?.id ? c.success : null,
            ),
            // The current server stays readable (not greyed out); picking
            // it again just closes the menu.
            onPressed: s.id == current?.id ? () {} : () => switchTo(s),
            child: Text(
              s.name,
              softWrap: true,
              style: s.id == current?.id
                  ? TextStyle(fontWeight: FontWeight.w600, color: c.foreground)
                  : null,
            ),
          ),
        const Divider(height: 9),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.plus, size: 16),
          onPressed: () async {
            final s = await showServerDialog(context);
            if (s != null) await switchTo(s);
          },
          child: Text(tr('Add server…')),
        ),
        if (current != null)
          MenuItemButton(
            leadingIcon: const Icon(LucideIcons.pencil, size: 16),
            onPressed: () => showServerDialog(context, existing: current),
            child: Text(tr('Edit this server…')),
          ),
        MenuItemButton(
          leadingIcon: Icon(LucideIcons.logOut, size: 16, color: c.danger),
          onPressed: session.disconnect,
          child: Text(tr('Disconnect'), style: TextStyle(color: c.danger)),
        ),
      ],
      // Compact: name + one status line; the address is in the tooltip
      // (and on the Settings page).
      builder: (context, menu, _) => Tooltip(
        message: address,
        child: Material(
          color: c.card,
          borderRadius: AppRadius.lgAll,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: c.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(LucideIcons.server, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current?.name ?? '—',
                          softWrap: true,
                          style: t.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status?.isOk == true
                                    ? c.success
                                    : c.subtle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status == null
                                    ? tr('Connecting…')
                                    : status.isOk
                                    ? (status.version.isNotEmpty
                                          ? '${tr('Online')} · v${status.version}'
                                          : tr('Online'))
                                    : status.status,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: t.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(
                      LucideIcons.chevronsUpDown,
                      size: 15,
                      color: c.subtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransfersIndicator extends StatelessWidget {
  final VoidCallback? onTap;
  const _TransfersIndicator({this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final transfers = context.watch<TransfersController>();
    if (!transfers.hasItems) return const SizedBox.shrink();
    final active = transfers.activeCount;
    final failed = transfers.items
        .where((x) => x.status == TransferStatus.failed)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Material(
        color: c.card,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      active > 0
                          ? LucideIcons.arrowDownUp
                          : failed > 0
                          ? LucideIcons.circleAlert
                          : LucideIcons.circleCheck,
                      size: 15,
                      color: active > 0
                          ? c.primary
                          : failed > 0
                          ? c.danger
                          : c.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        active > 0
                            ? tr('{n} transfers running', {'n': active})
                            : failed > 0
                            ? tr('{n} transfers failed', {'n': failed})
                            : tr('Transfers complete'),
                        style: t.labelMedium?.copyWith(color: c.foreground),
                      ),
                    ),
                  ],
                ),
                if (active > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: transfers.overallProgress,
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountFooter extends StatelessWidget {
  const _AccountFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final session = context.watch<SessionController>();
    final user = session.username ?? '';
    final exp = session.expiresAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: c.primarySoft,
            child: Text(
              user.isEmpty ? '?' : user.characters.first.toUpperCase(),
              style: t.labelLarge?.copyWith(color: c.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user, softWrap: true, style: t.titleSmall),
                Text(
                  exp == null
                      ? tr('Signed in')
                      : tr('Renews {t}', {
                          't': formatDateTime(exp.toUtc().toIso8601String()),
                        }),
                  softWrap: true,
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Disconnect'),
            icon: const Icon(LucideIcons.logOut, size: 16),
            onPressed: session.disconnect,
          ),
        ],
      ),
    );
  }
}
