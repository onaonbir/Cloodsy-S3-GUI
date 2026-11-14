import 'package:flutter/foundation.dart';

import '../core/storage/stores.dart';

/// Small persisted UI preferences.
class PrefsController extends ChangeNotifier {
  final KeyValueStore _store;
  PrefsController(this._store);

  static const _kDownloadDir = 'last_download_dir';
  static const _kUploadDir = 'last_upload_dir';
  static const _kNotify = 'notifications';
  static const _kLocale = 'locale';
  static const _kSkippedGuiVersion = 'skipped_gui_version';

  String? get downloadDir => _store.getString(_kDownloadDir);
  String? get uploadDir => _store.getString(_kUploadDir);
  bool get notifications => _store.getString(_kNotify) != 'off';

  /// 'en', 'tr' or null (follow the system language).
  String? get locale => _store.getString(_kLocale);
  String? get skippedGuiVersion => _store.getString(_kSkippedGuiVersion);

  Future<void> setDownloadDir(String dir) => _set(_kDownloadDir, dir);
  Future<void> setUploadDir(String dir) => _set(_kUploadDir, dir);
  Future<void> setNotifications(bool on) => _set(_kNotify, on ? 'on' : 'off');
  Future<void> skipGuiVersion(String v) => _set(_kSkippedGuiVersion, v);

  Future<void> setLocale(String? code) async {
    if (code == null) {
      await _store.remove(_kLocale);
    } else {
      await _store.setString(_kLocale, code);
    }
    notifyListeners();
  }

  Future<void> _set(String k, String v) async {
    if (_store.getString(k) == v) return;
    await _store.setString(k, v);
    notifyListeners();
  }
}
