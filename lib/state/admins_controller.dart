import '../core/api/api_client.dart';
import '../models/admin_user.dart';
import 'safe_notifier.dart';

/// Result of creating an admin or resetting a password: the server returns
/// the password once (generated or as given).
typedef PasswordResult = ({String username, String password, bool generated});

class AdminsController extends LoadState {
  final ApiClient _api;
  AdminsController(this._api);

  List<AdminUser> _admins = const [];
  List<AdminUser> get admins => _admins;

  Future<void> load() => runLoad(() async {
        final data = await _api.get('/admins');
        _admins = ((data['admins'] as List?) ?? const [])
            .map((a) => AdminUser.fromJson(a as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.username.compareTo(b.username));
      });

  static PasswordResult _result(Map<String, dynamic> d, String username,
          String requested) =>
      (
        username: d['username'] as String? ?? username,
        password: d['password'] as String? ?? requested,
        generated: d['auto_generated'] == true,
      );

  /// [password] empty → the server generates one.
  Future<PasswordResult> create(String username, String password) async {
    final d = await _api.post('/admins', body: {
      'username': username,
      if (password.isNotEmpty) 'password': password,
    });
    await load();
    return _result(d, username, password);
  }

  Future<void> delete(String username) async {
    await _api.delete('/admins/${ApiClient.seg(username)}');
    await load();
  }

  Future<PasswordResult> resetPassword(String username, String password) async {
    final d = await _api.put('/admins/${ApiClient.seg(username)}/password',
        body: {if (password.isNotEmpty) 'password': password});
    return _result(d, username, password);
  }
}
