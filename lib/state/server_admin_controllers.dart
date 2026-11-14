import 'dart:async';

import '../core/api/api_client.dart';
import '../models/admin_extras.dart';
import 'safe_notifier.dart';

/// Disk consistency scan and orphan cleanup.
class MaintenanceController extends LoadState {
  final ApiClient _api;
  MaintenanceController(this._api);

  ScanReport? _report;
  DateTime? _scannedAt;
  ScanReport? get report => _report;
  DateTime? get scannedAt => _scannedAt;

  Future<void> scan() => runLoad(() async {
        _report = ScanReport.fromJson(await _api.post('/maintenance/scan',
            timeout: ApiClient.longTimeout));
        _scannedAt = DateTime.now();
      });

  Future<({int deleted, List<String> failed})> deleteOrphanDirs(
      List<String> paths) async {
    final d = await _api.post('/maintenance/orphan-dirs/delete',
        body: {'paths': paths}, timeout: ApiClient.longTimeout);
    await scan();
    return (
      deleted: (d['deleted'] as num?)?.toInt() ?? 0,
      failed: ((d['failed'] as List?) ?? const [])
          .map((f) => '${(f as Map)['path']}: ${f['error']}')
          .toList(),
    );
  }
}

class SessionsController extends LoadState {
  final ApiClient _api;
  SessionsController(this._api);

  List<AdminSession> _sessions = const [];
  List<AdminSession> get sessions => _sessions;

  Future<void> load() => runLoad(() async {
        final d = await _api.get('/sessions');
        _sessions = ((d['sessions'] as List?) ?? const [])
            .map((s) => AdminSession.fromJson(s as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      });

  Future<void> revoke(String id) async {
    await _api.delete('/sessions/${ApiClient.seg(id)}');
    await load();
  }
}

/// Live server log tail (polls `GET /admin/logs?since_id=`).
class LogsController extends LoadState {
  final ApiClient _api;
  LogsController(this._api);

  static const int maxEntries = 3000;
  static const Duration interval = Duration(seconds: 2);

  final List<LogEntry> _entries = [];
  int _lastId = 0;
  String _level = 'DEBUG';
  String _query = '';
  bool _paused = false;
  Timer? _timer;
  bool _polling = false;

  List<LogEntry> get entries => _entries;
  String get level => _level;
  String get query => _query;
  bool get paused => _paused;

  void start() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void setPaused(bool p) {
    _paused = p;
    notifyListeners();
  }

  /// Filters are applied server-side, so changing them reloads the tail.
  void setFilter({String? level, String? query}) {
    _level = level ?? _level;
    _query = query ?? _query;
    _entries.clear();
    _lastId = 0;
    notifyListeners();
    _poll();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  Future<void> _poll() async {
    if (_paused || _polling || disposed) return;
    _polling = true;
    try {
      await runLoad(() async {
        final d = await _api.get('/logs', query: {
          if (_lastId > 0) 'since_id': '$_lastId',
          'level': _level,
          if (_query.isNotEmpty) 'q': _query,
          'limit': '500',
        });
        final fresh = ((d['entries'] as List?) ?? const [])
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries.addAll(fresh);
        if (_entries.length > maxEntries) {
          _entries.removeRange(0, _entries.length - maxEntries);
        }
        _lastId = (d['last_id'] as num?)?.toInt() ??
            (fresh.isNotEmpty ? fresh.last.id : _lastId);
      });
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MetricsController extends LoadState {
  final ApiClient _api;
  MetricsController(this._api);

  ServerMetrics? _metrics;
  ServerMetrics? get metrics => _metrics;
  Timer? _timer;

  void start() {
    load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  Future<void> load() => runLoad(() async {
        _metrics = ServerMetrics.fromJson(await _api.get('/metrics'));
      });

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ConfigController extends LoadState {
  final ApiClient _api;
  ConfigController(this._api);

  Map<String, dynamic>? _config;
  Map<String, dynamic>? get config => _config;

  Future<void> load() => runLoad(() async {
        _config = await _api.get('/config');
      });
}
