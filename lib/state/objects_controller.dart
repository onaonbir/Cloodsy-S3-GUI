import '../core/api/api_client.dart';
import '../models/admin_extras.dart';
import '../models/s3_object.dart';
import 'safe_notifier.dart';

enum ObjectSort { name, size, modified }

/// The file browser of one bucket: the current folder, paginated listing
/// (the server returns at most [pageSize] entries per request), selection
/// and object-level operations.
class ObjectsController extends LoadState {
  final ApiClient _api;
  final String bucket;
  static const int pageSize = 500;

  ObjectsController(this._api, this.bucket);

  String _prefix = '';
  List<String> _folders = const [];
  List<S3Object> _objects = const [];
  bool _truncated = false;
  String _nextMarker = '';
  bool _loadingMore = false;
  String _filter = '';
  ObjectSort _sort = ObjectSort.name;
  bool _ascending = true;
  final Set<String> _selected = {};
  int _requestSeq = 0;

  String get prefix => _prefix;
  bool get hasMore => _truncated && _nextMarker.isNotEmpty;
  bool get loadingMore => _loadingMore;
  String get filter => _filter;
  ObjectSort get sort => _sort;
  bool get ascending => _ascending;
  Set<String> get selected => Set.unmodifiable(_selected);

  String get _base => '/buckets/${ApiClient.seg(bucket)}';

  /// Folder path segments for the breadcrumb.
  List<String> get segments =>
      _prefix.split('/').where((s) => s.isNotEmpty).toList();

  bool _matches(String name) =>
      _filter.isEmpty || name.toLowerCase().contains(_filter.toLowerCase());

  String folderName(String p) {
    final rest = p.substring(_prefix.length);
    return rest.endsWith('/') ? rest.substring(0, rest.length - 1) : rest;
  }

  List<String> get folders {
    final list = _folders.where((p) => _matches(folderName(p))).toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_sort == ObjectSort.name && !_ascending) {
      return list.reversed.toList();
    }
    return list;
  }

  List<S3Object> get objects {
    // The folder's own marker ("photos/" while inside photos/) is not a file.
    final list = _objects
        .where((o) => o.key != _prefix && _matches(o.fileName))
        .toList();
    int cmp(S3Object a, S3Object b) => switch (_sort) {
          ObjectSort.name =>
            a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
          ObjectSort.size => a.size.compareTo(b.size),
          ObjectSort.modified => a.lastModified.compareTo(b.lastModified),
        };
    list.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return list;
  }

  bool get isEmpty => _folders.isEmpty && objects.isEmpty;

  void setFilter(String f) {
    _filter = f.trim();
    notifyListeners();
  }

  void setSort(ObjectSort s) {
    if (_sort == s) {
      _ascending = !_ascending;
    } else {
      _sort = s;
      _ascending = s == ObjectSort.name;
    }
    notifyListeners();
  }

  void toggleSelected(String key, [bool? value]) {
    final on = value ?? !_selected.contains(key);
    on ? _selected.add(key) : _selected.remove(key);
    notifyListeners();
  }

  void selectAllVisible(bool on) {
    final keys = objects.map((o) => o.key);
    on ? _selected.addAll(keys) : _selected.removeAll(keys);
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<void> open(String prefix) {
    _prefix = prefix;
    _filter = '';
    _searchSeq++;
    _search = '';
    _searchResults = const [];
    _searching = false;
    _selected.clear();
    _folders = const [];
    _objects = const [];
    _truncated = false;
    _nextMarker = '';
    return refresh();
  }

  void up() {
    final segs = segments;
    if (segs.isEmpty) return;
    segs.removeLast();
    open(segs.isEmpty ? '' : '${segs.join('/')}/');
  }

  /// Reloads the first page of the current folder.
  Future<void> refresh() {
    final seq = ++_requestSeq;
    final prefix = _prefix;
    return runLoad(() async {
      final page = await _page(prefix, '');
      if (seq != _requestSeq) return; // the user navigated meanwhile
      _folders = page.prefixes;
      _objects = page.objects;
      _truncated = page.truncated;
      _nextMarker = page.nextMarker;
      _selected.removeWhere((k) => !_objects.any((o) => o.key == k));
    });
  }

  Future<void> loadMore() async {
    if (!hasMore || _loadingMore) return;
    final seq = _requestSeq;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _page(_prefix, _nextMarker);
      if (seq != _requestSeq) return;
      _folders = [..._folders, ...page.prefixes.where((p) => !_folders.contains(p))];
      _objects = [..._objects, ...page.objects];
      _truncated = page.truncated;
      _nextMarker = page.nextMarker;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<ObjectListResult> _page(String prefix, String marker) async {
    final data = await _api.get('$_base/objects', query: {
      'prefix': prefix,
      'delimiter': '/',
      'max-keys': '$pageSize',
      if (marker.isNotEmpty) 'marker': marker,
    });
    return ObjectListResult.fromJson(data);
  }

  // --- Mutations ---

  Future<void> deleteObject(String key, {String? versionId}) async {
    await _api.delete('$_base/objects/${ApiClient.keyPath(key)}',
        query: versionId != null ? {'versionId': versionId} : null);
    _selected.remove(key);
  }

  /// Deletes [keys] one by one; returns the keys that failed with the last
  /// error message, then reloads the folder.
  Future<({List<String> failed, String? error})> deleteKeys(
      List<String> keys) async {
    final failed = <String>[];
    String? lastError;
    for (final k in keys) {
      try {
        await deleteObject(k);
      } on ApiException catch (e) {
        failed.add(k);
        lastError = e.message;
      }
    }
    await refresh();
    return (failed: failed, error: lastError);
  }

  /// Deletes everything under [folderPrefix]. Returns the server's counts.
  /// A half-way failure throws with the counts in the message.
  Future<({int deleted, int failed})> deleteFolder(String folderPrefix) async {
    try {
      final data = await _api.post('$_base/objects/delete-prefix',
          body: {'prefix': folderPrefix}, timeout: ApiClient.longTimeout);
      return (
        deleted: (data['deleted'] as num?)?.toInt() ?? 0,
        failed: (data['failed'] as num?)?.toInt() ?? 0,
      );
    } on ApiException catch (e) {
      final d = (e.data?['deleted'] as num?)?.toInt();
      final f = (e.data?['failed'] as num?)?.toInt();
      if (d != null && f != null) {
        throw ApiException(e.statusCode, '${e.message} ($d deleted, $f failed)',
            data: e.data);
      }
      rethrow;
    } finally {
      await refresh();
    }
  }

  /// Creates an empty `name/` marker in the current folder (needs the
  /// object-upload API).
  Future<void> createFolder(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (clean.isEmpty) throw const ApiException(400, 'Folder name required');
    await _api.putBytes('$_base/object', const [],
        query: {'key': '$_prefix$clean/'});
    await refresh();
  }

  // --- GUI v2 endpoints ---

  Future<ObjectInfo> info(String key) async =>
      ObjectInfo.fromJson(await _api.get('$_base/object/info', query: {'key': key}));

  /// Reads up to [maxBytes] of an object for previews.
  Future<({List<int> bytes, int? total, String contentType})> readBytes(
    String key, {
    int? maxBytes,
    String? versionId,
    bool rangeSupported = true,
  }) =>
      _api.getBytes('$_base/object',
          query: {
            'key': key,
            'inline': '1',
            'versionId': ?versionId,
          },
          maxBytes: maxBytes,
          useRange: rangeSupported);

  /// Server-side copy (or move) of one object.
  Future<void> copy(String sourceKey, String destKey,
      {String? destBucket, bool move = false}) async {
    await _api.post('$_base/objects/copy',
        body: {
          'source_key': sourceKey,
          'dest_key': destKey,
          if (destBucket != null && destBucket != bucket)
            'dest_bucket': destBucket,
          'move': move,
        },
        timeout: ApiClient.longTimeout);
    _selected.remove(sourceKey);
    await refresh();
  }

  /// Copies or moves every object under a folder prefix.
  Future<({int copied, int failed})> copyPrefix(
      String sourcePrefix, String destPrefix,
      {String? destBucket, bool move = false}) async {
    try {
      final d = await _api.post('$_base/objects/copy-prefix',
          body: {
            'source_prefix': sourcePrefix,
            'dest_prefix': destPrefix,
            if (destBucket != null && destBucket != bucket)
              'dest_bucket': destBucket,
            'move': move,
          },
          timeout: ApiClient.longTimeout);
      return (
        copied: (d['copied'] as num?)?.toInt() ?? 0,
        failed: (d['failed'] as num?)?.toInt() ?? 0,
      );
    } finally {
      await refresh();
    }
  }

  Future<({int objects, int bytes})> prefixStats(String prefix) async {
    final d = await _api.get('$_base/prefix-stats', query: {'prefix': prefix});
    return (
      objects: (d['objects'] as num?)?.toInt() ?? 0,
      bytes: (d['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ObjectInfo> updateMetadata(String key,
      {required String contentType,
      required Map<String, String> metadata}) async {
    final d = await _api.put('$_base/object/meta',
        query: {'key': key},
        body: {'content_type': contentType, 'metadata': metadata});
    await refresh();
    return ObjectInfo.fromJson(d);
  }

  // --- Recursive search (server-side, paginated) ---

  String _search = '';
  List<S3Object> _searchResults = const [];
  bool _searchTruncated = false;
  String _searchMarker = '';
  bool _searching = false;
  int _searchSeq = 0;

  /// Non-empty while showing results of a bucket-wide search.
  String get searchQuery => _search;
  bool get searching => _searching;
  List<S3Object> get searchResults => _searchResults;
  bool get searchHasMore => _searchTruncated && _searchMarker.isNotEmpty;

  Future<void> search(String q, {bool more = false}) async {
    if (!more) {
      _search = q.trim();
      _searchResults = const [];
      _searchMarker = '';
      _searchTruncated = false;
      if (_search.isEmpty) {
        notifyListeners();
        return;
      }
    }
    final seq = more ? _searchSeq : ++_searchSeq;
    _searching = true;
    notifyListeners();
    try {
      final d = await _api.get('$_base/search', query: {
        'q': _search,
        'prefix': _prefix,
        'max-keys': '$pageSize',
        if (more && _searchMarker.isNotEmpty) 'marker': _searchMarker,
      });
      if (seq != _searchSeq) return;
      final page = ObjectListResult.fromJson(d);
      _searchResults = more ? [..._searchResults, ...page.objects] : page.objects;
      _searchTruncated = page.truncated;
      _searchMarker = page.nextMarker;
    } finally {
      if (seq == _searchSeq) {
        _searching = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _searchSeq++;
    _search = '';
    _searchResults = const [];
    _searching = false;
    notifyListeners();
  }

  Future<List<ObjectVersion>> versions(String key) async {
    final data = await _api.get('$_base/versions', query: {'key': key});
    return ((data['versions'] as List?) ?? const [])
        .map((v) => ObjectVersion.fromJson(v as Map<String, dynamic>))
        .toList();
  }
}
