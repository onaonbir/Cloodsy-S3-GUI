import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/server_connection.dart';
import '../services/app_storage.dart';

class ServerProvider extends ChangeNotifier {
  static const _keyServers = 'servers_list';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  List<ServerConnection> _servers = [];
  ServerConnection? _activeServer;

  List<ServerConnection> get servers => _servers;
  ServerConnection? get activeServer => _activeServer;

  Future<void> load() async {
    final storage = await AppStorage.getInstance();
    final json = storage.getString(_keyServers);
    if (json != null && json.isNotEmpty) {
      _servers = ServerConnection.decodeList(json);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final storage = await AppStorage.getInstance();
    await storage.setString(_keyServers, ServerConnection.encodeList(_servers));
  }

  Future<void> addServer(ServerConnection server, String password) async {
    _servers.add(server);
    await _secureStorage.write(key: 'pw_${server.id}', value: password);
    await _persist();
    notifyListeners();
  }

  Future<void> updateServer(
      ServerConnection server, String? password) async {
    final idx = _servers.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      _servers[idx] = server;
      if (password != null) {
        await _secureStorage.write(key: 'pw_${server.id}', value: password);
      }
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    await _secureStorage.delete(key: 'pw_$id');
    await _secureStorage.delete(key: 'token_$id');
    await _secureStorage.delete(key: 'token_exp_$id');
    if (_activeServer?.id == id) _activeServer = null;
    await _persist();
    notifyListeners();
  }

  Future<String?> getPassword(String serverId) async {
    return _secureStorage.read(key: 'pw_$serverId');
  }

  Future<String?> getToken(String serverId) async {
    return _secureStorage.read(key: 'token_$serverId');
  }

  /// Server-reported expiry of the saved token, or null when unknown.
  Future<DateTime?> getTokenExpiry(String serverId) async {
    final raw = await _secureStorage.read(key: 'token_exp_$serverId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveToken(String serverId, String token,
      {DateTime? expiresAt}) async {
    await _secureStorage.write(key: 'token_$serverId', value: token);
    if (expiresAt != null) {
      await _secureStorage.write(
          key: 'token_exp_$serverId', value: expiresAt.toIso8601String());
    } else {
      await _secureStorage.delete(key: 'token_exp_$serverId');
    }
  }

  Future<void> clearToken(String serverId) async {
    await _secureStorage.delete(key: 'token_$serverId');
    await _secureStorage.delete(key: 'token_exp_$serverId');
  }

  void setActiveServer(ServerConnection? server) {
    _activeServer = server;
    notifyListeners();
  }
}
