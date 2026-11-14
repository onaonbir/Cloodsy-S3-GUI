import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/platform.dart';
import 'core/storage/stores.dart';
import 'state/gui_update_controller.dart';
import 'state/prefs_controller.dart';
import 'state/servers_controller.dart';
import 'state/session_controller.dart';
import 'state/theme_controller.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/shell/app_shell.dart';
import 'ui/shell/title_bar.dart';
import 'ui/theme/app_theme.dart';
import 'core/i18n.dart';

const String appVersion = '2.0.0';

/// App-wide switches that differ between the real app and tests.
class AppOptions {
  /// Ask GitHub for the latest server release (dashboard update banner).
  final bool checkForUpdates;
  const AppOptions({this.checkForUpdates = true});
}

class CloodsyApp extends StatelessWidget {
  final KeyValueStore store;
  final SecretStore secrets;

  /// Injected in tests to fake the server.
  final ApiClient? api;

  /// Desktop window chrome (custom title bar). Off in tests.
  final bool desktopChrome;
  final AppOptions options;

  const CloodsyApp({
    super.key,
    required this.store,
    required this.secrets,
    this.api,
    bool? desktopChrome,
    this.options = const AppOptions(checkForUpdates: false),
  }) : desktopChrome = desktopChrome ?? false;

  factory CloodsyApp.production({
    required KeyValueStore store,
    required SecretStore secrets,
  }) =>
      CloodsyApp(
        store: store,
        secrets: secrets,
        desktopChrome: useCustomTitleBar,
        options: const AppOptions(),
      );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: options),
        ChangeNotifierProvider(create: (_) => PrefsController(store)),
        ChangeNotifierProvider(create: (_) {
          final u = GuiUpdateController(appVersion);
          if (options.checkForUpdates) u.check();
          return u;
        }),
        ChangeNotifierProvider(create: (_) => ThemeController(store)),
        ChangeNotifierProvider(create: (_) => ServersController(store, secrets)),
        ChangeNotifierProvider(
          create: (c) =>
              SessionController(c.read<ServersController>(), api: api),
        ),
      ],
      child: Consumer2<ThemeController, PrefsController>(
        builder: (context, theme, prefs, _) => MaterialApp(
          builder: (context, child) => _LocaleRebuilder(
              code: _syncLocale(prefs.locale), child: child!),
          title: tr('Cloodsy S3'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          themeAnimationDuration: const Duration(milliseconds: 250),
          home: _Root(desktopChrome: desktopChrome),
        ),
      ),
    );
  }
}

String _syncLocale(String? preferred) {
  I18n.setLocale(preferred);
  return I18n.code;
}

/// After a language switch, rebuilds every widget once so all tr() calls
/// re-run, without recreating any state.
class _LocaleRebuilder extends StatefulWidget {
  final String code;
  final Widget child;
  const _LocaleRebuilder({required this.code, required this.child});

  @override
  State<_LocaleRebuilder> createState() => _LocaleRebuilderState();
}

class _LocaleRebuilderState extends State<_LocaleRebuilder> {
  @override
  void didUpdateWidget(_LocaleRebuilder old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) I18n.rebuildAll(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the server picker or the connected shell, and cleans up when a
/// session ends on its own (expired, revoked).
class _Root extends StatefulWidget {
  final bool desktopChrome;
  const _Root({required this.desktopChrome});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final SessionController _session;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionController>();
    _session.addListener(_onSession);
  }

  void _onSession() {
    final now = _session.isLoggedIn;
    if (_wasLoggedIn && !now) {
      // Close dialogs/menus that belonged to the finished session.
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    _wasLoggedIn = now;
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final content = session.isLoggedIn
        ? SessionScope(
            key: ValueKey('session:${session.generation}'),
            child: const AppShell(),
          )
        : const WelcomeScreen();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.desktopChrome) const TitleBar(),
          Expanded(child: content),
        ],
      ),
    );
  }
}
