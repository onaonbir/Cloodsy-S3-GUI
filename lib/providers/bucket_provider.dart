import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bucket.dart';
import '../models/credential.dart';
import '../models/lifecycle_rule.dart';
import '../models/webhook.dart';
import '../models/admin_user.dart';
import '../models/s3_object.dart';
import '../models/server_status.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';

class BucketProvider extends ChangeNotifier {
  ApiClient? _api;

  List<Bucket> _buckets = [];
  bool _isLoading = false;
  String? _error;

  // Detail state
  Bucket? _selectedBucket;
  List<Credential> _credentials = [];
  List<LifecycleRule> _lifecycleRules = [];
  List<Webhook> _webhooks = [];
  ServerStatus? _serverStatus;

  List<Bucket> get buckets => _buckets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Bucket? get selectedBucket => _selectedBucket;
  List<Credential> get credentials => _credentials;
  List<LifecycleRule> get lifecycleRules => _lifecycleRules;
  List<Webhook> get webhooks => _webhooks;
  ServerStatus? get serverStatus => _serverStatus;
  String? _latestVersion;
  String? get latestVersion => _latestVersion;

  bool get updateAvailable {
    if (_serverStatus == null || _latestVersion == null) return false;
    if (_serverStatus!.version.isEmpty) return false;
    return _compareVersions(_serverStatus!.version, _latestVersion!) < 0;
  }

  void updateAuth(AuthProvider auth) {
    _api = auth.api;
  }

  // --- Status ---

  Future<void> fetchStatus() async {
    try {
      final data = await _api!.get('/status');
      _serverStatus = ServerStatus.fromJson(data);
      notifyListeners();
      // Check GitHub for latest version in background
      _checkLatestVersion();
    } catch (_) {}
  }

  static const _githubRepo = 'onaonbir/Cloodsy-S3';

  Future<void> _checkLatestVersion() async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/releases/latest'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final tag = data['tag_name'] as String? ?? '';
        _latestVersion = tag.replaceFirst('v', '');
        notifyListeners();
      }
    } catch (_) {}
  }

  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }

  // --- Bucket CRUD ---

  Future<void> fetchBuckets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api!.get('/buckets');
      final list = data['buckets'] as List;
      _buckets = list.map((b) => Bucket.fromJson(b)).toList();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBucketDetail(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api!.get('/buckets/$name');
      _selectedBucket = Bucket.fromJson(data);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createBucket(String name, {String storageDir = ''}) async {
    try {
      await _api!.post('/buckets', {
        'name': name,
        if (storageDir.isNotEmpty) 'storage_dir': storageDir,
      });
      await fetchBuckets();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBucket(String name) async {
    try {
      await _api!.delete('/buckets/$name');
      _buckets.removeWhere((b) => b.name == name);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Quota ---

  Future<bool> setQuota(String name, int quotaBytes) async {
    try {
      await _api!.put('/buckets/$name/quota', {'quota_bytes': quotaBytes});
      await fetchBucketDetail(name);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Storage ---

  Future<bool> setStorage(String name, String storageDir) async {
    try {
      await _api!.put('/buckets/$name/storage', {'storage_dir': storageDir});
      await fetchBucketDetail(name);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Versioning ---

  Future<bool> setVersioning(String name, String state) async {
    try {
      await _api!.put('/buckets/$name/versioning', {'versioning': state});
      await fetchBucketDetail(name);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Credentials ---

  Future<void> fetchCredentials(String bucketName) async {
    try {
      final data = await _api!.get('/buckets/$bucketName/credentials');
      final list = data['credentials'] as List;
      _credentials = list.map((c) => Credential.fromJson(c)).toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<Credential?> createCredential(
      String bucketName, String name, String permission) async {
    try {
      final data = await _api!.post('/buckets/$bucketName/credentials', {
        'name': name,
        'permission': permission,
      });
      final cred = Credential.fromJson(data);
      await fetchCredentials(bucketName);
      return cred;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCredential(String accessKey, String bucketName) async {
    try {
      await _api!.delete('/credentials/$accessKey');
      await fetchCredentials(bucketName);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Lifecycle ---

  Future<void> fetchLifecycleRules(String bucketName) async {
    try {
      final data = await _api!.get('/buckets/$bucketName/lifecycle');
      final list = data['rules'] as List;
      _lifecycleRules = list.map((r) => LifecycleRule.fromJson(r)).toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> addLifecycleRule(
      String bucketName, String name, String prefix, int days) async {
    try {
      await _api!.post('/buckets/$bucketName/lifecycle', {
        'name': name,
        'prefix': prefix,
        'expiration_days': days,
      });
      await fetchLifecycleRules(bucketName);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLifecycleRules(String bucketName,
      {String? prefix}) async {
    try {
      final path = prefix != null
          ? '/buckets/$bucketName/lifecycle?prefix=$prefix'
          : '/buckets/$bucketName/lifecycle';
      await _api!.delete(path);
      await fetchLifecycleRules(bucketName);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Webhooks ---

  Future<void> fetchWebhooks(String bucketName) async {
    try {
      final data = await _api!.get('/buckets/$bucketName/webhooks');
      final list = data['webhooks'] as List;
      _webhooks = list.map((w) => Webhook.fromJson(w)).toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> addWebhook(String bucketName, String name, String url,
      {String events = '*', String secret = ''}) async {
    try {
      await _api!.post('/buckets/$bucketName/webhooks', {
        'name': name,
        'url': url,
        'event_types': events,
        'secret': secret,
      });
      await fetchWebhooks(bucketName);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWebhook(int id, String bucketName) async {
    try {
      await _api!.delete('/webhooks/$id');
      await fetchWebhooks(bucketName);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Objects (File Manager) ---

  ObjectListResult? _objectList;
  bool _objectsLoading = false;

  ObjectListResult? get objectList => _objectList;
  bool get objectsLoading => _objectsLoading;

  Future<void> fetchObjects(String bucketName,
      {String prefix = '', String marker = ''}) async {
    _objectsLoading = true;
    notifyListeners();

    try {
      final params = <String, String>{
        'prefix': prefix,
        'delimiter': '/',
        'max-keys': '200',
      };
      if (marker.isNotEmpty) params['marker'] = marker;

      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final data = await _api!.get('/buckets/$bucketName/objects?$query');
      _objectList = ObjectListResult.fromJson(data);
      _objectsLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _objectsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteObject(String bucketName, String key) async {
    try {
      await _api!.delete('/buckets/$bucketName/objects/${Uri.encodeFull(key)}');
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePrefix(String bucketName, String prefix) async {
    try {
      await _api!.post('/buckets/$bucketName/objects/delete-prefix', {
        'prefix': prefix,
      });
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Admin Users ---

  List<AdminUser> _admins = [];
  List<AdminUser> get admins => _admins;

  Future<void> fetchAdmins() async {
    try {
      final data = await _api!.get('/admins');
      final list = data['admins'] as List;
      _admins = list.map((a) => AdminUser.fromJson(a)).toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Returns the created admin's password (shown once).
  Future<Map<String, dynamic>?> createAdmin(String username, String password) async {
    try {
      final body = <String, dynamic>{'username': username};
      if (password.isNotEmpty) body['password'] = password;
      final data = await _api!.post('/admins', body);
      await fetchAdmins();
      return data;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteAdmin(String username) async {
    try {
      await _api!.delete('/admins/$username');
      await fetchAdmins();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Returns the new password (shown once).
  Future<Map<String, dynamic>?> resetAdminPassword(String username, String password) async {
    try {
      final body = <String, dynamic>{};
      if (password.isNotEmpty) body['password'] = password;
      final data = await _api!.put('/admins/$username/password', body);
      return data;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
