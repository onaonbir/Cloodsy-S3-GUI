import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../state/navigation_controller.dart';
import '../../state/server_controller.dart';
import '../../state/servers_controller.dart';
import '../../state/session_controller.dart';
import '../../state/theme_controller.dart';
import '../screens/buckets_screen.dart' show createBucketFlow;
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'sidebar.dart' show bucketTabIcon;

class _Command {
  final IconData icon;
  final String title;
  final String group;
  final String? hint;
  final VoidCallback run;
  const _Command(this.icon, this.title, this.group, this.run, {this.hint});
}

/// Ctrl+K: type to jump to any page, bucket or action.
Future<void> showCommandPalette(BuildContext context) {
  final nav = context.read<NavigationController>();
  final server = context.read<ServerController>();
  final servers = context.read<ServersController>();
  final session = context.read<SessionController>();
  final theme = context.read<ThemeController>();
  final status = server.status;
  final brightness = Theme.of(context).brightness;
  final goTo = tr('Go to');

  final commands = <_Command>[
    _Command(LucideIcons.layoutGrid, tr('Dashboard'), goTo,
        () => nav.go(const DashboardDestination())),
    _Command(LucideIcons.package, tr('Buckets'), goTo,
        () => nav.go(const BucketsDestination())),
    _Command(LucideIcons.users, tr('Admin users'), goTo,
        () => nav.go(const AdminsDestination())),
    for (final (page, icon, on) in [
      (ServerPage.sessions, LucideIcons.monitorSmartphone, status?.canSessions),
      (ServerPage.logs, LucideIcons.scrollText, status?.canLogs),
      (ServerPage.metrics, LucideIcons.chartColumn, status?.canMetrics),
      (ServerPage.maintenance, LucideIcons.stethoscope, status?.canMaintenance),
      (ServerPage.config, LucideIcons.fileCog, status?.canConfig),
      (ServerPage.servers, LucideIcons.layers, servers.servers.length > 1),
    ])
      if (on ?? false)
        _Command(icon, page.label, goTo,
            () => nav.go(ServerPageDestination(page))),
    _Command(LucideIcons.settings, tr('Settings'), goTo,
        () => nav.go(const SettingsDestination())),
    if (nav.openBucket != null)
      for (final t in BucketTab.values)
        _Command(bucketTabIcon(t), '${nav.openBucket} › ${t.label}', goTo,
            () => nav.go(BucketDestination(nav.openBucket!, t))),
    for (final b in server.buckets)
      _Command(LucideIcons.package, b.name, tr('Open bucket'),
          () => nav.go(BucketDestination(b.name)),
          hint: '${tr('Files')} · ${tr('Settings')}'),
    _Command(LucideIcons.plus, tr('New bucket'), tr('Actions'),
        () => createBucketFlow(context)),
    _Command(
        brightness == Brightness.dark ? LucideIcons.sun : LucideIcons.moon,
        tr('Toggle light/dark theme'),
        tr('Actions'),
        () => theme.toggle(brightness)),
    for (final s in servers.servers)
      if (s.id != session.serverId)
        _Command(LucideIcons.server, tr('Switch to {name}', {'name': s.name}),
            tr('Actions'), () => session.connect(s)),
    _Command(LucideIcons.logOut, tr('Disconnect'), tr('Actions'),
        session.disconnect),
  ];

  return showDialog(
    context: context,
    barrierColor: Colors.black38,
    builder: (_) => _Palette(commands: commands),
  );
}

class _Palette extends StatefulWidget {
  final List<_Command> commands;
  const _Palette({required this.commands});

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _index = 0;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Every typed word must appear in the title (any order).
  List<_Command> get _matches {
    final words = _query.text.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return widget.commands;
    return widget.commands.where((c) {
      final hay = '${c.title} ${c.group}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  void _run(_Command c) {
    Navigator.pop(context);
    c.run();
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _index = (_index + delta) % count);
    if (_index < 0) _index += count;
    const rowH = 44.0;
    final target = _index * rowH;
    if (_scroll.hasClients) {
      final pos = _scroll.position;
      if (target < pos.pixels) {
        _scroll.jumpTo(target);
      } else if (target + rowH > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo(target + rowH - pos.viewportDimension);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final matches = _matches;
    if (_index >= matches.length) _index = 0;

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: c.card,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1, matches.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(-1, matches.length),
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (matches.isNotEmpty) _run(matches[_index]);
                  },
                },
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: (_) => setState(() => _index = 0),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: tr('Type a page, bucket or action…'),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(tr('No matches'),
                            textAlign: TextAlign.center, style: t.bodyMedium),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemExtent: 44,
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final cmd = matches[i];
                          final sel = i == _index;
                          return InkWell(
                            onTap: () => _run(cmd),
                            onHover: (h) {
                              if (h && _index != i) setState(() => _index = i);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: sel ? c.selected : null,
                                borderRadius: AppRadius.mdAll,
                              ),
                              child: Row(
                                children: [
                                  Icon(cmd.icon,
                                      size: 16,
                                      color: sel ? c.primary : c.muted),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(cmd.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.bodyLarge),
                                  ),
                                  Text(cmd.group, style: t.bodySmall),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border))),
                child: Text('↑ ↓  ·  Enter  ·  Esc',
                    style: t.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
