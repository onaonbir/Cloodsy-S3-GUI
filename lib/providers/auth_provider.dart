import 'dart:async';
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

  /// Absolute session expiry reported by the server at login.
  DateTime? _expiresAt;
  Timer? _expiryTimer;

  /// Set when the session was dropped without the user asking for it
  /// (expired, revoked, re-login failed) so the shell can explain why.
  bool _sessionExpired = false;

  bool _connecting = false;
  bool _reloginInProgress = false;

  /// Refresh this long before the server-side expiry so in-flight requests
  /// never race the deadline.
  static const Duration _refreshMargin = Duration(seconds: 30);

  String? get token => _token;
  String? get username => _username;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get expiresAt => _expiresAt;
  bool get sessionExpired => _sessionExpired;

  AuthProvider() {
    api.onUnauthorized = _handleUnauthorized;
  }

  void updateServerProvider(ServerProvider sp) {
    _serverProvider = sp;
  }

  Future<bool> connectToServer(ServerConnection server) async {
    _isLoading = true;
    _error = null;
    _sessionExpired = false;
    _serverId = server.id;
    _connecting = true;
    api.baseUrl = server.url;
    notifyListeners();

    try {
      // Try saved token first, unless we already know it has expired.
      final savedToken = await _serverProvider?.getToken(server.id);
      final savedExpiry = await _serverProvider?.getTokenExpiry(server.id);
      final tokenUsable = savedToken != null &&
          (savedExpiry == null ||
              savedExpiry.isAfter(DateTime.now().add(_refreshMargin)));
      if (tokenUsable) {
        _token = savedToken;
        api.token = savedToken;
        try {
          await api.get('/status');
          _username = server.username;
          _expiresAt = savedExpiry;
          _scheduleExpiry();
          _isLoading = false;
          _serverProvider?.setActiveServer(server);
          notifyListeners();
          return true;
        } on ApiException catch (e) {
          _token = null;
          api.token = null;
          // Anything other than "token rejected" (TLS, unreachable, 5xx)
          // will fail the password login the same way — report it now.
          if (!e.isUnauthorized) {
            _error = e.message;
            _isLoading = false;
            notifyListeners();
            return false;
          }
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
    } finally {
      _connecting = false;
    }
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
      _expiresAt = _parseExpiry(response);
      _sessionExpired = false;
      _scheduleExpiry();

      if (_serverId != null) {
        await _serverProvider?.saveToken(_serverId!, _token!,
            expiresAt: _expiresAt);
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

  /// Reads `expires_in` (seconds, preferred: immune to clock skew) or
  /// `expires_at` (RFC 3339) from the login response.
  static DateTime? _parseExpiry(Map<String, dynamic> response) {
    final expiresIn = response['expires_in'];
    if (expiresIn is num && expiresIn > 0) {
      return DateTime.now().add(Duration(seconds: expiresIn.toInt()));
    }
    final expiresAt = response['expires_at'];
    if (expiresAt is String) {
      return DateTime.tryParse(expiresAt)?.toLocal();
    }
    return null;
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final exp = _expiresAt;
    if (exp == null) return;
    var delay = exp.difference(DateTime.now()) - _refreshMargin;
    if (delay.isNegative) delay = Duration.zero;
    _expiryTimer = Timer(delay, _onSessionExpiring);
  }

  /// Fired shortly before the server drops the session: renew it with the
  /// stored password, or send the user back to the server list.
  Future<void> _onSessionExpiring() async {
    if (_token == null) return;
    final ok = await _tryReLogin();
    if (!ok) _forceDisconnect('Session expired. Please reconnect.');
  }

  Future<void> disconnect() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
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
    _expiresAt = null;
    _sessionExpired = false;
    api.token = null;
    api.baseUrl = '';
    _serverProvider?.setActiveServer(null);
    notifyListeners();
  }

  void _handleUnauthorized() {
    // connectToServer handles its own 401 (stale saved token); a re-login
    // that is already running will resolve or disconnect on its own.
    if (_connecting || _reloginInProgress || _token == null) return;
    _tryReLogin().then((ok) {
      if (!ok) _forceDisconnect('Session expired. Please reconnect.');
    });
  }

  /// Silently renews the session with the stored password. Returns false
  /// when there is no password or the server rejected it.
  Future<bool> _tryReLogin() async {
    if (_serverId == null || _username == null) return false;
    if (_reloginInProgress) return false;
    _reloginInProgress = true;
    try {
      final pw = await _serverProvider?.getPassword(_serverId!);
      if (pw == null) return false;
      return await _doLogin(_username!, pw);
    } finally {
      _reloginInProgress = false;
    }
  }

  void _forceDisconnect(String reason) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_serverId != null) {
      _serverProvider?.clearToken(_serverId!);
    }
    _token = null;
    _username = null;
    _expiresAt = null;
    _sessionExpired = true;
    _error = reason;
    api.token = null;
    _serverProvider?.setActiveServer(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    api.dispose();
    super.dispose();
  }
}
