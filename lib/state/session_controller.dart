import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../models/server_connection.dart';
import 'servers_controller.dart';
import '../core/i18n.dart';

/// The admin session with one server: login, token reuse, silent renewal
/// before expiry, and recovery when the server revokes the token.
class SessionController extends ChangeNotifier {
  final ApiClient api;
  final ServersController _servers;

  SessionController(this._servers, {ApiClient? api})
      : api = api ?? ApiClient() {
    this.api.onUnauthorized = _handleUnauthorized;
  }

  String? _token;
  String? _username;
  String? _serverId;
  String? _connectingId;
  String? _error;
  DateTime? _expiresAt;
  Timer? _expiryTimer;
  bool _reloginInProgress = false;

  /// Bumped on every successful connect so screens can tell a fresh session
  /// (possibly to another server) from a silent token renewal.
  int _generation = 0;

  /// Renew this long before the server-side expiry so in-flight requests
  /// never race the deadline.
  static const Duration refreshMargin = Duration(seconds: 30);

  bool get isLoggedIn => _token != null;
  String? get username => _username;
  String? get serverId => _serverId;
  ServerConnection? get server => _servers.byId(_serverId);
  String? get connectingId => _connectingId;
  bool get isConnecting => _connectingId != null;
  int get generation => _generation;
  DateTime? get expiresAt => _expiresAt;

  /// Why the last connect failed or the session was dropped. Cleared by the
  /// next connect attempt or [clearError].
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> connect(ServerConnection server) async {
    if (_connectingId != null) return false;
    if (isLoggedIn) await disconnect();
    _connectingId = server.id;
    _error = null;
    api.baseUrl = server.url;
    api.token = null;
    notifyListeners();

    try {
      // Reuse a saved token unless we already know it has expired.
      final savedToken = await _servers.token(server.id);
      final savedExpiry = await _servers.tokenExpiry(server.id);
      final usable = savedToken != null &&
          (savedExpiry == null ||
              savedExpiry.isAfter(DateTime.now().add(refreshMargin)));
      if (usable) {
        api.token = savedToken;
        try {
          await api.get('/status');
          _activate(server.id, savedToken, server.username, savedExpiry);
          return true;
        } on ApiException catch (e) {
          api.token = null;
          // Anything but "token rejected" (TLS, unreachable, 5xx) would fail
          // the password login the same way, so report it now.
          if (!e.isUnauthorized) {
            _error = e.message;
            return false;
          }
          await _servers.clearToken(server.id);
        }
      }

      final password = await _servers.password(server.id);
      if (password == null || password.isEmpty) {
        _error = tr('No saved password for this server. Edit it and try again.');
        return false;
      }
      final ok = await _login(server.id, server.username, password);
      return ok;
    } finally {
      _connectingId = null;
      notifyListeners();
    }
  }

  Future<bool> _login(String serverId, String username, String password) async {
    try {
      final r = await api.post('/login',
          body: {'username': username, 'password': password});
      final token = r['token'] as String?;
      if (token == null || token.isEmpty) {
        _error = 'Server returned no session token';
        return false;
      }
      final expiry = parseExpiry(r);
      await _servers.saveToken(serverId, token, expiresAt: expiry);
      _activate(serverId, token, r['username'] as String? ?? username, expiry);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    }
  }

  void _activate(
      String serverId, String token, String username, DateTime? expiry) {
    final sameSession = _serverId == serverId && _token != null;
    _serverId = serverId;
    _token = token;
    _username = username;
    _expiresAt = expiry;
    api.token = token;
    if (!sameSession) _generation++;
    _scheduleExpiry();
    notifyListeners();
  }

  /// Reads `expires_in` (seconds, preferred: immune to clock skew) or
  /// `expires_at` (RFC 3339) from the login response.
  static DateTime? parseExpiry(Map<String, dynamic> r, {DateTime? now}) {
    final expiresIn = r['expires_in'];
    if (expiresIn is num && expiresIn > 0) {
      return (now ?? DateTime.now()).add(Duration(seconds: expiresIn.toInt()));
    }
    final expiresAt = r['expires_at'];
    if (expiresAt is String) return DateTime.tryParse(expiresAt)?.toLocal();
    return null;
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final exp = _expiresAt;
    if (exp == null) return;
    var delay = exp.difference(DateTime.now()) - refreshMargin;
    if (delay.isNegative) delay = Duration.zero;
    _expiryTimer = Timer(delay, () async {
      if (_token == null) return;
      if (!await _relogin()) _drop(tr('Session expired. Please reconnect.'));
    });
  }

  void _handleUnauthorized() {
    // A re-login that is already running resolves or drops on its own.
    if (_connectingId != null || _reloginInProgress || _token == null) return;
    _relogin().then((ok) {
      if (!ok) _drop(tr('Session expired. Please reconnect.'));
    });
  }

  /// Silently renews the session with the stored password.
  Future<bool> _relogin() async {
    final id = _serverId, user = _username;
    if (id == null || user == null || _reloginInProgress) return false;
    _reloginInProgress = true;
    try {
      final pw = await _servers.password(id);
      if (pw == null) return false;
      return await _login(id, user, pw);
    } finally {
      _reloginInProgress = false;
    }
  }

  /// Call after this admin's own password was changed: the server revokes
  /// every session of the user, so store the new password and log in again
  /// before the next request fails.
  Future<void> ownPasswordChanged(String newPassword) async {
    final id = _serverId, user = _username;
    if (id == null || user == null) return;
    await _servers.setPassword(id, newPassword);
    _reloginInProgress = true;
    try {
      if (!await _login(id, user, newPassword)) {
        _drop(_error ?? 'Please reconnect with the new password.');
      }
    } finally {
      _reloginInProgress = false;
    }
  }

  Future<void> disconnect() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final id = _serverId;
    if (_token != null) {
      try {
        await api.post('/logout');
      } catch (_) {}
    }
    if (id != null) await _servers.clearToken(id);
    _reset();
    _error = null;
    notifyListeners();
  }

  void _drop(String reason) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final id = _serverId;
    if (id != null) _servers.clearToken(id);
    _reset();
    _error = reason;
    notifyListeners();
  }

  void _reset() {
    _token = null;
    _username = null;
    _serverId = null;
    _expiresAt = null;
    api.token = null;
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    api.dispose();
    super.dispose();
  }
}
