import 'package:flutter/foundation.dart';
import '../models/server_connection.dart';
import '../services/api_client.dart';
import '../providers/server_provider.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
  ServerProvider? _serverProvider;

  String? _token;
  String? _username;
  String? _serverId;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  String? get username => _username;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    api.onUnauthorized = _handleUnauthorized;
  }

  void updateServerProvider(ServerProvider sp) {
    _serverProvider = sp;
  }

  Future<bool> connectToServer(ServerConnection server) async {
    _isLoading = true;
    _error = null;
    _serverId = server.id;
    api.baseUrl = server.url;
    notifyListeners();

    // Try saved token first
    final savedToken = await _serverProvider?.getToken(server.id);
    if (savedToken != null) {
      _token = savedToken;
      api.token = savedToken;
      try {
        await api.get('/status');
        _username = server.username;
        _isLoading = false;
        _serverProvider?.setActiveServer(server);
        notifyListeners();
        return true;
      } catch (_) {
        _token = null;
        api.token = null;
      }
    }

    // Token invalid or missing — login with password
    final password = await _serverProvider?.getPassword(server.id);
    if (password != null) {
      final success = await _doLogin(server.username, password);
      _isLoading = false;
      if (success) {
        _serverProvider?.setActiveServer(server);
      }
      notifyListeners();
      return success;
    }

    _error = 'No saved credentials';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> _doLogin(String username, String password) async {
    try {
      final response = await api.post('/login', {
        'username': username,
        'password': password,
      });

      _token = response['token'] as String;
      _username = response['username'] as String;
      api.token = _token;

      if (_serverId != null) {
        await _serverProvider?.saveToken(_serverId!, _token!);
      }

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Connection failed: $e';
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_token != null) {
      try {
        await api.post('/logout');
      } catch (_) {}
    }
    if (_serverId != null) {
      await _serverProvider?.clearToken(_serverId!);
    }
    _token = null;
    _username = null;
    _serverId = null;
    api.token = null;
    api.baseUrl = '';
    _serverProvider?.setActiveServer(null);
    notifyListeners();
  }

  void _handleUnauthorized() {
    // Try re-login silently
    if (_serverId != null && _username != null) {
      _serverProvider?.getPassword(_serverId!).then((pw) {
        if (pw != null) {
          _doLogin(_username!, pw);
          return;
        }
        _forceDisconnect();
      });
      return;
    }
    _forceDisconnect();
  }

  void _forceDisconnect() {
    _token = null;
    _username = null;
    api.token = null;
    _serverProvider?.setActiveServer(null);
    notifyListeners();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
