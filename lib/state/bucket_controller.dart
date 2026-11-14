import '../core/api/api_client.dart';
import '../models/admin_extras.dart';
import '../models/bucket.dart';
import '../models/credential.dart';
import '../models/lifecycle_rule.dart';
import '../models/webhook.dart';
import 'safe_notifier.dart';

/// Everything about one open bucket except its objects. Scoped to the
/// bucket screen, so switching tabs keeps the loaded data.
class BucketController extends LoadState {
  final ApiClient _api;
  final String name;

  /// Lets the bucket list on the dashboard reflect changes made here.
  final void Function(Bucket)? onBucketChanged;

  BucketController(this._api, this.name, {this.onBucketChanged});

  Bucket? _bucket;
  List<Credential> _credentials = const [];
  List<LifecycleRule> _rules = const [];
  List<Webhook> _webhooks = const [];

  Bucket? get bucket => _bucket;
  List<Credential> get credentials => _credentials;
  List<LifecycleRule> get rules => _rules;
  List<Webhook> get webhooks => _webhooks;

  String get _base => '/buckets/${ApiClient.seg(name)}';

  Future<void> load() => runLoad(() async {
        final r = await Future.wait([
          _api.get(_base),
          _api.get('$_base/credentials'),
          _api.get('$_base/lifecycle'),
          _api.get('$_base/webhooks'),
        ]);
        _setBucket(Bucket.fromJson(r[0]));
        _credentials = _list(r[1]['credentials'], Credential.fromJson);
        _rules = _list(r[2]['rules'], LifecycleRule.fromJson);
        _webhooks = _list(r[3]['webhooks'], Webhook.fromJson);
      });

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
      ((raw as List?) ?? const [])
          .map((e) => f(e as Map<String, dynamic>))
          .toList();

  void _setBucket(Bucket b) {
    _bucket = b;
    onBucketChanged?.call(b);
  }

  Future<void> reloadBucket() async {
    _setBucket(Bucket.fromJson(await _api.get(_base)));
    notifyListeners();
  }

  // --- Settings ---

  Future<void> setQuota(int bytes) async {
    await _api.put('$_base/quota', body: {'quota_bytes': bytes});
    await reloadBucket();
  }

  Future<void> setStorage(String dir) async {
    await _api.put('$_base/storage',
        body: {'storage_dir': dir}, timeout: ApiClient.longTimeout);
    await reloadBucket();
  }

  Future<void> setVersioning(bool enabled) async {
    await _api.put('$_base/versioning',
        body: {'versioning': enabled ? 'Enabled' : 'Suspended'});
    await reloadBucket();
  }

  Future<void> setPublicRead(bool enabled) async {
    await _api.put('$_base/public-read', body: {'public_read': enabled});
    await reloadBucket();
  }

  Future<void> setWebdav(bool enabled) async {
    await _api.put('$_base/webdav', body: {'webdav_enabled': enabled});
    await reloadBucket();
  }

  Future<void> reprocessImages() => _api.post('$_base/reprocess');

  // --- Credentials ---

  Future<Credential> createCredential(String label, String permission) async {
    final data = await _api.post('$_base/credentials',
        body: {'name': label, 'permission': permission});
    final cred = Credential.fromJson(data);
    await _reloadCredentials();
    return cred;
  }

  Future<void> deleteCredential(String accessKey) async {
    await _api.delete('/credentials/${ApiClient.seg(accessKey)}');
    await _reloadCredentials();
  }

  Future<void> _reloadCredentials() async {
    final d = await _api.get('$_base/credentials');
    _credentials = _list(d['credentials'], Credential.fromJson);
    notifyListeners();
    await reloadBucket(); // credential count
  }

  // --- Lifecycle ---

  Future<void> addRule(String label, String prefix, int days) async {
    await _api.post('$_base/lifecycle',
        body: {'name': label, 'prefix': prefix, 'expiration_days': days});
    await _reloadRules();
  }

  /// The server deletes rules by prefix; an empty prefix means "every
  /// rule", so a rule without a prefix is only removable with all others.
  Future<void> deleteRules({String? prefix}) async {
    await _api.delete('$_base/lifecycle',
        query: prefix != null && prefix.isNotEmpty ? {'prefix': prefix} : null);
    await _reloadRules();
  }

  Future<void> _reloadRules() async {
    final d = await _api.get('$_base/lifecycle');
    _rules = _list(d['rules'], LifecycleRule.fromJson);
    notifyListeners();
  }

  // --- Lifecycle v2 (all rule actions, edit, enable/disable, delete by id)

  Future<void> saveRule(LifecycleRule rule) async {
    if (rule.id > 0) {
      await _api.put('$_base/lifecycle/${rule.id}', body: rule.toJson());
    } else {
      await _api.post('$_base/lifecycle', body: rule.toJson());
    }
    await _reloadRules();
  }

  Future<void> deleteRuleById(int id) async {
    await _api.delete('$_base/lifecycle/$id');
    await _reloadRules();
  }

  // --- Incomplete multipart uploads

  List<MultipartUploadInfo> _uploads = const [];
  bool _uploadsLoaded = false;
  List<MultipartUploadInfo> get uploads => _uploads;
  bool get uploadsLoaded => _uploadsLoaded;

  Future<void> loadUploads() async {
    final d = await _api.get('$_base/uploads');
    _uploads = _list(d['uploads'], MultipartUploadInfo.fromJson);
    _uploadsLoaded = true;
    notifyListeners();
  }

  Future<void> abortUpload(String uploadId) async {
    await _api.delete('$_base/uploads/${ApiClient.seg(uploadId)}');
    await loadUploads();
  }

  Future<int> abortUploads({int? olderThanDays}) async {
    final d = await _api.delete('$_base/uploads',
        query: olderThanDays != null
            ? {'older_than_days': '$olderThanDays'}
            : null,
        timeout: ApiClient.longTimeout);
    await loadUploads();
    return (d['aborted'] as num?)?.toInt() ?? 0;
  }

  // --- Webhooks v2

  Future<void> updateWebhook(int id,
      {required String label,
      required String url,
      required String events,
      required bool active,
      String? secret}) async {
    await _api.put('/webhooks/$id', body: {
      'name': label,
      'url': url,
      'event_types': events,
      'active': active,
      'secret': ?secret,
    });
    await _reloadWebhooks();
  }

  Future<List<WebhookDelivery>> deliveries(int id) async {
    final d = await _api.get('/webhooks/$id/deliveries', query: {'limit': '50'});
    return _list(d['deliveries'], WebhookDelivery.fromJson);
  }

  Future<WebhookDelivery> testWebhook(int id) async {
    final d = await _api.post('/webhooks/$id/test',
        timeout: const Duration(seconds: 40));
    return WebhookDelivery(
      id: 0,
      eventType: 's3:TestEvent',
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      error: d['error'] as String? ?? '',
      durationMs: (d['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }

  // --- Webhooks ---

  Future<void> addWebhook({
    required String label,
    required String url,
    required String events,
    String secret = '',
  }) async {
    await _api.post('$_base/webhooks', body: {
      'name': label,
      'url': url,
      'event_types': events,
      'secret': secret,
    });
    await _reloadWebhooks();
  }

  Future<void> deleteWebhook(int id) async {
    await _api.delete('/webhooks/$id');
    await _reloadWebhooks();
  }

  Future<void> _reloadWebhooks() async {
    final d = await _api.get('$_base/webhooks');
    _webhooks = _list(d['webhooks'], Webhook.fromJson);
    notifyListeners();
  }
}
