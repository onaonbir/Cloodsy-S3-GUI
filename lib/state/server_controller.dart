import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api/api_client.dart';
import '../core/format.dart';
import '../models/bucket.dart';
import '../models/server_status.dart';
import 'safe_notifier.dart';

/// Server-wide data for the connected session: status and the bucket list.
/// Recreated for every new session (see `SessionScope`).
class ServerController extends LoadState {
  final ApiClient _api;
  final http.Client? _github;
  final bool checkForUpdates;

  ServerController(this._api,
      {http.Client? githubClient, this.checkForUpdates = true})
      : _github = githubClient;

  ServerStatus? _status;
  List<Bucket> _buckets = const [];
  String? _latestVersion;

  ServerStatus? get status => _status;
  List<Bucket> get buckets => _buckets;
  String? get latestVersion => _latestVersion;

  Bucket? bucket(String name) =>
      _buckets.where((b) => b.name == name).firstOrNull;

  int get totalObjects => _buckets.fold(0, (s, b) => s + b.objects);
  int get totalUsage => _buckets.fold(0, (s, b) => s + b.usageBytes);

  bool get updateAvailable {
    final current = _status?.version ?? '';
    final latest = _latestVersion;
    if (current.isEmpty || latest == null || current == 'dev') return false;
    return compareVersions(current, latest) < 0;
  }

  /// WebDAV mount base URL derived from the connected host and the server's
  /// WebDAV listen port, or null when WebDAV is off.
  String? get webdavMountUrl {
    final st = _status;
    if (st == null || !st.webdavEnabled) return null;
    final host = Uri.tryParse(_api.baseUrl)?.host ?? '';
    final listen = st.webdavListen;
    final port = listen.contains(':') ? listen.split(':').last : listen;
    if (host.isEmpty || port.isEmpty) return null;
    final scheme = (st.tls?.webdav ?? false) ? 'https' : 'http';
    return '$scheme://$host:$port/';
  }

  /// Base URL of the S3 API for links: the server entry's override, else
  /// the admin host with the S3 listener's port and scheme.
  String? s3Endpoint(String overrideUrl) {
    if (overrideUrl.isNotEmpty) return overrideUrl;
    final s3 = _status?.s3;
    final admin = Uri.tryParse(_api.baseUrl);
    if (s3 == null || admin == null || admin.host.isEmpty) return null;
    final port = s3.port.isEmpty ? '' : ':${s3.port}';
    final host = admin.host.contains(':') ? '[${admin.host}]' : admin.host;
    return '${s3.tls ? 'https' : 'http'}://$host$port';
  }

  /// Admin API base URL of this session (for local path mapping).
  String get adminUrl => _api.baseUrl;

  Future<void> refresh() => runLoad(() async {
        final results = await Future.wait([
          _api.get('/status'),
          _api.get('/buckets'),
        ]);
        _status = ServerStatus.fromJson(results[0]);
        _buckets = ((results[1]['buckets'] as List?) ?? const [])
            .map((b) => Bucket.fromJson(b as Map<String, dynamic>))
            .toList();
        if (checkForUpdates && _latestVersion == null) _checkLatestVersion();
      });

  Future<void> refreshBuckets() async {
    try {
      final data = await _api.get('/buckets');
      _buckets = ((data['buckets'] as List?) ?? const [])
          .map((b) => Bucket.fromJson(b as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on ApiException {
      // Keep the current list; the screen that asked shows its own error.
    }
  }

  /// Replaces one bucket in the list after a detail screen re-fetched it.
  void updateBucket(Bucket b) {
    final i = _buckets.indexWhere((x) => x.name == b.name);
    if (i < 0) return;
    _buckets = [..._buckets]..[i] = b;
    notifyListeners();
  }

  static const githubRepo = 'onaonbir/Cloodsy-S3';

  Future<void> _checkLatestVersion() async {
    final client = _github ?? http.Client();
    try {
      final resp = await client
          .get(Uri.parse(
              'https://api.github.com/repos/$githubRepo/releases/latest'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final tag = (jsonDecode(resp.body) as Map)['tag_name'] as String? ?? '';
        if (tag.isNotEmpty) {
          _latestVersion = tag.replaceFirst('v', '');
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline or rate-limited: no update banner, nothing else to do.
    } finally {
      if (_github == null) client.close();
    }
  }

  // --- Bucket lifecycle ---

  Future<void> createBucket(String name, {String storageDir = ''}) async {
    await _api.post('/buckets', body: {
      'name': name,
      if (storageDir.isNotEmpty) 'storage_dir': storageDir,
    });
    await refreshBuckets();
  }

  /// Deletes a bucket. The server answers 409 while objects, versions or
  /// delete markers remain; [force] removes everything with the bucket.
  Future<void> deleteBucket(String name, {bool force = false}) async {
    await _api.delete('/buckets/${ApiClient.seg(name)}',
        query: force ? {'force': 'true'} : null,
        timeout: force ? ApiClient.longTimeout : null);
    _buckets = _buckets.where((b) => b.name != name).toList();
    notifyListeners();
  }
}
