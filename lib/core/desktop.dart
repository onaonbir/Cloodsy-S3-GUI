import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as na;

import '../models/server_status.dart';
import 'platform.dart';

/// Thin wrappers over OS integrations. Every call is best effort: a missing
/// notification service or file manager must never break the app.
class Desktop {
  Desktop._();

  static bool _notificationsReady = false;

  /// System notification (transfers finished, …).
  static void notify(String title, String body) {
    if (!isDesktop) return;
    try {
      final m = na.NotificationManager.instance;
      if (!m.isSupported()) return;
      if (!_notificationsReady) _notificationsReady = m.initialize();
      if (_notificationsReady) m.show(title, body, 'cloodsy-s3', '');
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }

  /// Taskbar/dock progress; null clears it.
  static void taskbarProgress(double? value) {
    if (!isDesktop) return;
    try {
      na.Application.instance.setProgressBar(value ?? -1);
    } catch (_) {}
  }

  static bool openUrl(String url) {
    try {
      return na.UrlOpener.instance.open(url).success;
    } catch (_) {
      return false;
    }
  }

  /// Opens a local file with its default application.
  static Future<bool> openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path]);
      } else {
        await Process.start('xdg-open', [path]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reveals a file (selected) in the system file manager.
  static Future<bool> showInFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', path]);
      } else {
        final dir = FileSystemEntity.isDirectorySync(path)
            ? path
            : File(path).parent.path;
        await Process.start('xdg-open', [dir]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Translates a path on the server into one this machine can open, when
  /// the server runs on the same computer (directly, or inside WSL while the
  /// GUI runs on Windows). Returns null for remote servers.
  static String? localPathFor(String serverPath, String serverUrl,
      HostInfo? host) {
    if (serverPath.isEmpty || host == null || !isDesktop) return null;
    final h = Uri.tryParse(serverUrl)?.host.toLowerCase() ?? '';
    final loopback = h == 'localhost' || h == '127.0.0.1' || h == '::1' ||
        h == '[::1]';
    final sameHostname = host.hostname.isNotEmpty &&
        host.hostname.toLowerCase() == Platform.localHostname.toLowerCase();

    if (Platform.isWindows && host.wslDistro.isNotEmpty) {
      // WSL2 is reachable through localhost or its own NAT address; either
      // way the distro's files are visible under \\wsl.localhost\<distro>.
      final isPrivate = loopback ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(h) ||
          h.endsWith('.local');
      if (!isPrivate) return null;
      return '\\\\wsl.localhost\\${host.wslDistro}${serverPath.replaceAll('/', '\\')}';
    }
    final sameOs = (Platform.isWindows && host.os == 'windows') ||
        (Platform.isMacOS && host.os == 'darwin') ||
        (Platform.isLinux && host.os == 'linux');
    if (sameOs && (loopback || sameHostname)) return serverPath;
    return null;
  }
}
