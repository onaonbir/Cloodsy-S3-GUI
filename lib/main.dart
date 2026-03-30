import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/server_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/bucket_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/shell_screen.dart';
import 'services/app_storage.dart';
import 'theme/app_theme.dart';
import 'widgets/theme_switcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app storage (AppData/Roaming/OnaOnbir/Cloodsy S3/)
  await AppStorage.getInstance();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    final windowOptions = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: isDebug ? const Size(900, 600) : const Size(1280, 720),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Cloodsy S3',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const CloodyS3App());
}

class CloodyS3App extends StatelessWidget {
  const CloodyS3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => ServerProvider()..load()),
        ChangeNotifierProxyProvider<ServerProvider, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, sp, auth) {
            auth!.updateServerProvider(sp);
            return auth;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BucketProvider>(
          create: (_) => BucketProvider(),
          update: (_, auth, buckets) {
            buckets!.updateAuth(auth);
            return buckets;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Cloodsy S3',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            themeAnimationDuration: Duration.zero,
            builder: (context, child) {
              return ThemeSwitcher(child: child ?? const SizedBox());
            },
            home: const ShellScreen(),
          );
        },
      ),
    );
  }
}
