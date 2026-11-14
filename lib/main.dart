import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform.dart';
import 'core/storage/app_storage.dart';
import 'core/storage/stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();

  // Settings file (AppData/Roaming/OnaOnbir/Cloodsy S3/ on Windows).
  final storage = await AppStorage.getInstance();

  if (isDesktop) {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.title = 'Cloodsy S3';
      if (useCustomTitleBar) window.titleBarStyle = TitleBarStyle.hidden;
      window.minimumSize = const Size(960, 620).toNative();
      window.setSize(const Size(1320, 840).toNative(), false);
      window.center();
      window.show();
      window.focus();
    }
  }

  runApp(CloodsyApp.production(
    store: AppKeyValueStore(storage),
    secrets: SecureSecretStore(),
  ));
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (pkg, file) in [
      ('Plus Jakarta Sans', 'assets/fonts/OFL-PlusJakartaSans.txt'),
      ('JetBrains Mono', 'assets/fonts/OFL-JetBrainsMono.txt'),
    ]) {
      try {
        yield LicenseEntryWithLineBreaks([pkg], await rootBundle.loadString(file));
      } catch (_) {}
    }
  });
}
