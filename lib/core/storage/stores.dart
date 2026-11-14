import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_storage.dart';

/// Plain settings (theme, server list). Backed by [AppStorage] in the app
/// and by [MemoryKeyValueStore] in tests.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Secrets (saved passwords, session tokens). Backed by the OS keychain via
/// flutter_secure_storage in the app.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class AppKeyValueStore implements KeyValueStore {
  final AppStorage _storage;
  AppKeyValueStore(this._storage);

  @override
  String? getString(String key) => _storage.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      _storage.setString(key, value);
  @override
  Future<void> remove(String key) => _storage.remove(key);
}

class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;
  SecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values;
  MemoryKeyValueStore([Map<String, String>? initial])
      : values = {...?initial};

  @override
  String? getString(String key) => values[key];
  @override
  Future<void> setString(String key, String value) async =>
      values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values;
  MemorySecretStore([Map<String, String>? initial])
      : values = {...?initial};

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}
