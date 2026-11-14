import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app.dart' show AppOptions;
import '../../state/navigation_controller.dart';
import '../../state/prefs_controller.dart';
import '../../state/server_controller.dart';
import '../../state/session_controller.dart';
import '../../state/transfers_controller.dart';
import '../screens/admins_screen.dart';
import '../screens/bucket/bucket_screen.dart';
import '../screens/buckets_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/server_pages.dart';
import '../screens/settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'sidebar.dart';
import 'command_palette.dart';
import 'title_bar.dart';
import 'transfers_panel.dart';
import '../../core/i18n.dart';

/// Per-session state. Rebuilt (and the old one disposed, cancelling its
/// transfers) whenever a new session starts, so nothing from one server
/// leaks into another.
class SessionScope extends StatelessWidget {
  final Widget child;
  const SessionScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SessionController>().api;
    final options = context.read<AppOptions>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationController()),
        ChangeNotifierProvider(
            create: (_) => ServerController(api,
                checkForUpdates: options.checkForUpdates)
              ..refresh()),
        ChangeNotifierProxyProvider2<ServerController, PrefsController,
            TransfersController>(
          create: (_) => TransfersController(api),
          update: (_, server, prefs, transfers) => transfers!
            ..multipart = server.status?.canMultipart ?? false
            ..notifications = prefs.notifications,
        ),
      ],
      child: child,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _transfersOpen = false;
  int _lastTransferCount = 0;

  Widget _content(Destination d) => switch (d) {
        DashboardDestination() => const DashboardScreen(),
        BucketsDestination() => const BucketsScreen(),
        BucketDestination(:final bucket, :final tab) =>
          BucketScreen(key: ValueKey('bucket:$bucket'), bucket: bucket, tab: tab),
        AdminsDestination() => const AdminsScreen(),
        ServerPageDestination(:final page) =>
          KeyedSubtree(key: ValueKey(page), child: serverPage(page)),
        SettingsDestination() => const SettingsScreen(),
      };

  String _title(Destination d) => switch (d) {
        DashboardDestination() => 'Dashboard',
        BucketsDestination() => 'Buckets',
        BucketDestination(:final bucket) => bucket,
        AdminsDestination() => 'Admin users',
        ServerPageDestination(:final page) => page.label,
        SettingsDestination() => 'Settings',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.watch<NavigationController>();
    final transfers = context.watch<TransfersController>();
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.sidebar;

    // Pop the transfers panel open whenever new transfers are queued.
    final count = transfers.items.length;
    if (count > _lastTransferCount) _transfersOpen = true;
    _lastTransferCount = count;

    final body = Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppDuration.normal,
            switchInCurve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey(switch (nav.current) {
                BucketDestination() => 'bucket:${nav.openBucket}',
                ServerPageDestination(:final page) => 'page:$page',
                _ => nav.current.runtimeType,
              }),
              child: _content(nav.current),
            ),
          ),
        ),
        if (_transfersOpen && transfers.hasItems)
          Positioned(
            right: 20,
            bottom: 20,
            child: TransfersPanel(
                onClose: () => setState(() => _transfersOpen = false)),
          ),
      ],
    );

    // App-wide shortcuts; the Focus keeps them working when no field has
    // focus (screens with their own focus, like Files, sit below it).
    Widget withShortcuts(Widget child) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                showCommandPalette(context),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                showCommandPalette(context),
          },
          child: Focus(autofocus: true, child: child),
        );

    if (wide) {
      return withShortcuts(Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(
            onTransfersTap: () =>
                setState(() => _transfersOpen = !_transfersOpen),
            onSearch: () => showCommandPalette(context),
          ),
          Expanded(child: ColoredBox(color: c.background, child: body)),
        ],
      ));
    }

    return withShortcuts(Scaffold(
      key: _scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.menu, size: 20),
          onPressed: () => _scaffold.currentState?.openDrawer(),
        ),
        title: Text(_title(nav.current)),
        actions: [
          IconButton(
            tooltip: '${tr('Command palette')} (Ctrl+K)',
            icon: const Icon(LucideIcons.search, size: 18),
            onPressed: () => showCommandPalette(context),
          ),
          if (nav.current is! DashboardDestination)
            IconButton(
              tooltip: tr('Back'),
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              onPressed: nav.back,
            ),
          const ThemeToggleButton(),
          const SizedBox(width: 6),
        ],
      ),
      drawer: Drawer(
        width: 252,
        child: Sidebar(
          onNavigate: () => Navigator.of(context).maybePop(),
          onTransfersTap: () {
            Navigator.of(context).maybePop();
            setState(() => _transfersOpen = true);
          },
        ),
      ),
      body: body,
    ));
  }
}
