import 'package:flutter/foundation.dart';

import '../core/storage/stores.dart';
import '../models/server_connection.dart';

/// Saved server connections. Metadata lives in the settings file; passwords
/// and session tokens live in the OS keychain.
class ServersController extends ChangeNotifier {
  static const _keyServers = 'servers_list';

  final KeyValueStore _store;
  final SecretStore _secrets;

  List<ServerConnection> _servers = [];
  List<ServerConnection> get servers => List.unmodifiable(_servers);

  ServersController(this._store, this._secrets) {
    final json = _store.getString(_keyServers);
    if (json != null && json.isNotEmpty) {
      try {
        _servers = ServerConnection.decodeList(json);
      } catch (e) {
        debugPrint('ServersController: unreadable server list: $e');
      }
    }
  }

  ServerConnection? byId(String? id) =>
      id == null ? null : _servers.where((s) => s.id == id).firstOrNull;

  Future<void> _persist() =>
      _store.setString(_keyServers, ServerConnection.encodeList(_servers));

  Future<void> add(ServerConnection server, String password) async {
    _servers = [..._servers, server];
    await _secrets.write(_pw(server.id), password);
    await _persist();
    notifyListeners();
  }

  /// Updates connection details; [password] null keeps the stored one.
  /// Changing URL or username invalidates the saved session token.
  Future<void> update(ServerConnection server, {String? password}) async {
    final idx = _servers.indexWhere((s) => s.id == server.id);
    if (idx < 0) return;
    final old = _servers[idx];
    _servers = [..._servers]..[idx] = server;
    if (password != null) await _secrets.write(_pw(server.id), password);
    if (old.url != server.url || old.username != server.username) {
      await clearToken(server.id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _servers = _servers.where((s) => s.id != id).toList();
    await _secrets.delete(_pw(id));
    await clearToken(id);
    await _persist();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [..._servers];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    _servers = list;
    await _persist();
    notifyListeners();
  }

  Future<String?> password(String id) => _secrets.read(_pw(id));
  Future<void> setPassword(String id, String password) =>
      _secrets.write(_pw(id), password);

  Future<String?> token(String id) => _secrets.read('token_$id');

  Future<DateTime?> tokenExpiry(String id) async {
    final raw = await _secrets.read('token_exp_$id');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveToken(String id, String token, {DateTime? expiresAt}) async {
    await _secrets.write('token_$id', token);
    if (expiresAt != null) {
      await _secrets.write('token_exp_$id', expiresAt.toIso8601String());
    } else {
      await _secrets.delete('token_exp_$id');
    }
  }

  Future<void> clearToken(String id) async {
    await _secrets.delete('token_$id');
    await _secrets.delete('token_exp_$id');
  }

  static String _pw(String id) => 'pw_$id';
}
