import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Encrypted file-based app storage.
/// Windows:  AppData\Roaming\OnaOnbir\Cloodsy S3\
/// macOS:    ~/Library/Application Support/com.onaonbir.cloodsys3/
/// Linux:    ~/.local/share/cloodsy-s3/
class AppStorage {
  static AppStorage? _instance;
  late final String _basePath;
  final Map<String, dynamic> _cache = {};
  static const _settingsFile = 'settings.dat';
  static const _keyFile = '.key';

  late final Uint8List _encKey;

  AppStorage._();

  static Future<AppStorage> getInstance() async {
    if (_instance != null) return _instance!;
    _instance = AppStorage._();
    await _instance!._init();
    return _instance!;
  }

  Future<void> _init() async {
    final appSupport = await getApplicationSupportDirectory();
    _basePath = appSupport.path;
    await Directory(_basePath).create(recursive: true);

    // Load or generate encryption key
    _encKey = await _loadOrCreateKey();

    // Load settings
    final file = File(p.join(_basePath, _settingsFile));
    if (await file.exists()) {
      try {
        final encrypted = await file.readAsBytes();
        final decrypted = _xorCrypt(encrypted, _encKey);
        final content = utf8.decode(decrypted);
        _cache.addAll(jsonDecode(content) as Map<String, dynamic>);
      } catch (_) {
        // Corrupted file, start fresh
      }
    }
  }

  Future<Uint8List> _loadOrCreateKey() async {
    final keyFile = File(p.join(_basePath, _keyFile));
    if (await keyFile.exists()) {
      return keyFile.readAsBytes();
    }
    // Generate 64-byte random key
    final random = Random.secure();
    final key = Uint8List.fromList(
        List.generate(64, (_) => random.nextInt(256)));
    await keyFile.writeAsBytes(key);
    return key;
  }

  /// Simple XOR-based encryption with key stretching.
  /// Not military-grade but prevents casual reading of the settings file.
  Uint8List _xorCrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length] ^ ((i * 7 + 13) & 0xFF);
    }
    return result;
  }

  /// Get the base storage path
  String get basePath => _basePath;

  // --- String operations ---

  String? getString(String key) => _cache[key] as String?;

  Future<void> setString(String key, String value) async {
    _cache[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    _cache.remove(key);
    await _save();
  }

  // --- Save to disk (encrypted) ---

  Future<void> _save() async {
    final json = jsonEncode(_cache);
    final bytes = utf8.encode(json);
    final encrypted = _xorCrypt(Uint8List.fromList(bytes), _encKey);
    final file = File(p.join(_basePath, _settingsFile));
    await file.writeAsBytes(encrypted);
  }
}
