import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../core/api/api_client.dart';
import '../core/desktop.dart';
import '../core/format.dart';
import '../models/admin_extras.dart';
import 'safe_notifier.dart';
import '../core/i18n.dart';

enum TransferKind { upload, download }

enum TransferStatus { queued, running, done, failed, cancelled }

class Transfer {
  final int id;
  final TransferKind kind;
  final String bucket;
  final String key;
  final String localPath;
  final String? versionId;
  final CancelToken cancelToken = CancelToken();

  int done = 0;
  int? total;
  TransferStatus status = TransferStatus.queued;
  String? error;

  /// Multipart state, kept across retries so an interrupted upload resumes
  /// with the parts the server already has.
  String? uploadId;
  final Map<int, String> parts = {};

  Transfer({
    required this.id,
    required this.kind,
    required this.bucket,
    required this.key,
    required this.localPath,
    this.versionId,
    this.total,
  });

  String get name {
    final k = key.endsWith('/') ? key.substring(0, key.length - 1) : key;
    return k.split('/').last;
  }

  double? get progress =>
      total != null && total! > 0 ? (done / total!).clamp(0.0, 1.0) : null;

  bool get isActive =>
      status == TransferStatus.queued || status == TransferStatus.running;

  bool get isMultipart => uploadId != null;
}

/// Upload/download queue for the session. Runs [maxConcurrent] transfers at
/// a time; finished uploads are announced on [uploaded] so an open file
/// browser can refresh.
class TransfersController extends SafeNotifier {
  final ApiClient _api;
  static const int maxConcurrent = 3;

  /// Single-request uploads are limited to 5 GiB by the server.
  static const int singlePutLimit = 5 * 1024 * 1024 * 1024;

  /// Above this size uploads go multipart (when the server supports it) so
  /// they can resume after a failure. Instance fields so tests can shrink
  /// them.
  int multipartThreshold = 64 * 1024 * 1024;
  int minPartSize = 16 * 1024 * 1024;

  TransfersController(this._api);

  /// Set from the server's capabilities.
  bool multipart = false;

  /// System notification when a batch of transfers finishes.
  bool notifications = true;

  final List<Transfer> _items = [];
  final StreamController<Transfer> _uploaded = StreamController.broadcast();
  int _nextId = 1;
  int _running = 0;
  int _finishedInBatch = 0;
  int _failedInBatch = 0;

  List<Transfer> get items => List.unmodifiable(_items);
  Stream<Transfer> get uploaded => _uploaded.stream;
  int get activeCount => _items.where((t) => t.isActive).length;
  bool get hasItems => _items.isNotEmpty;

  /// Overall progress of active transfers with a known size.
  double? get overallProgress {
    final active = _items.where((t) => t.isActive && t.total != null);
    final total = active.fold<int>(0, (s, t) => s + t.total!);
    if (total == 0) return null;
    return active.fold<int>(0, (s, t) => s + t.done) / total;
  }

  @override
  void notifyListeners() {
    Desktop.taskbarProgress(activeCount > 0 ? (overallProgress ?? 0) : null);
    super.notifyListeners();
  }

  /// Queues uploads of local [files] (file → object key).
  void upload(String bucket, Map<File, String> files) {
    for (final e in files.entries) {
      _items.add(Transfer(
        id: _nextId++,
        kind: TransferKind.upload,
        bucket: bucket,
        key: e.value,
        localPath: e.key.path,
      ));
    }
    notifyListeners();
    _pump();
  }

  void download(String bucket, String key, File dest,
      {String? versionId, int? size}) {
    _items.add(Transfer(
      id: _nextId++,
      kind: TransferKind.download,
      bucket: bucket,
      key: key,
      localPath: dest.path,
      versionId: versionId,
      total: size,
    ));
    notifyListeners();
    _pump();
  }

  void cancel(Transfer t) {
    if (!t.isActive) return;
    t.cancelToken.cancel();
    if (t.status == TransferStatus.queued) {
      t.status = TransferStatus.cancelled;
      notifyListeners();
    }
  }

  void cancelAll() {
    for (final t in _items) {
      cancel(t);
    }
  }

  void retry(Transfer t) {
    if (t.isActive) return;
    _items.remove(t);
    final n = Transfer(
      id: _nextId++,
      kind: t.kind,
      bucket: t.bucket,
      key: t.key,
      localPath: t.localPath,
      versionId: t.versionId,
      total: t.total,
    );
    // Resume a failed multipart upload instead of starting over.
    if (t.status == TransferStatus.failed && t.uploadId != null) {
      n.uploadId = t.uploadId;
      n.parts.addAll(t.parts);
    }
    _items.add(n);
    notifyListeners();
    _pump();
  }

  void remove(Transfer t) {
    if (t.isActive) return;
    _items.remove(t);
    notifyListeners();
  }

  void clearFinished() {
    _items.removeWhere((t) => !t.isActive);
    notifyListeners();
  }

  void _pump() {
    while (_running < maxConcurrent) {
      final next = _items
          .where((t) => t.status == TransferStatus.queued)
          .firstOrNull;
      if (next == null) break;
      _running++;
      next.status = TransferStatus.running;
      notifyListeners();
      _run(next).whenComplete(() {
        _running--;
        if (disposed) return;
        _pump();
        _maybeAnnounceBatch();
      });
    }
  }

  void _maybeAnnounceBatch() {
    if (activeCount > 0 || _finishedInBatch + _failedInBatch == 0) return;
    final ok = _finishedInBatch, failed = _failedInBatch;
    _finishedInBatch = 0;
    _failedInBatch = 0;
    if (!notifications) return;
    Desktop.notify(
      failed == 0 ? tr('Transfers complete') : tr('Transfers finished with errors'),
      failed == 0
          ? tr('{n} files transferred', {'n': ok})
          : tr('{ok} succeeded, {failed} failed', {'ok': ok, 'failed': failed}),
    );
  }

  Future<void> _run(Transfer t) async {
    var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
    void progress(int done, int? total) {
      t.done = done;
      t.total = total ?? t.total;
      final now = DateTime.now();
      // Repainting on every 64 KB chunk is wasteful; ~10 fps is plenty.
      if (now.difference(lastNotify).inMilliseconds > 100) {
        lastNotify = now;
        notifyListeners();
      }
    }

    final base = '/buckets/${ApiClient.seg(t.bucket)}';
    try {
      if (t.kind == TransferKind.upload) {
        final file = File(t.localPath);
        final size = await file.length();
        t.total = size;
        if (multipart && (size > multipartThreshold || t.uploadId != null)) {
          await _multipartUpload(t, base, file, size, progress);
        } else if (size > singlePutLimit) {
          throw const ApiException(413,
              'Files over 5 GB need a server with multipart upload support');
        } else {
          await _api.uploadFile('$base/object', file,
              query: {'key': t.key},
              contentType: guessContentType(t.name),
              onProgress: progress,
              cancel: t.cancelToken);
        }
      } else {
        await _api.downloadToFile('$base/object', File(t.localPath),
            query: {
              'key': t.key,
              if (t.versionId != null) 'versionId': t.versionId!,
            },
            onProgress: progress,
            cancel: t.cancelToken);
      }
      t.status = TransferStatus.done;
      if (t.total != null) t.done = t.total!;
      _finishedInBatch++;
      if (t.kind == TransferKind.upload && !_uploaded.isClosed) {
        _uploaded.add(t);
      }
    } on ApiException catch (e) {
      if (e.isCancelled || t.cancelToken.isCancelled) {
        t.status = TransferStatus.cancelled;
        // A cancelled multipart upload would otherwise linger on the server.
        final id = t.uploadId;
        if (id != null) {
          unawaited(_api
              .delete('$base/uploads/${ApiClient.seg(id)}')
              .then((_) {}, onError: (_) {}));
          t.uploadId = null;
          t.parts.clear();
        }
      } else {
        t.status = TransferStatus.failed;
        t.error = e.message;
        _failedInBatch++;
      }
    } on FileSystemException catch (e) {
      t.status = TransferStatus.failed;
      t.error = 'File error: ${e.message}';
      _failedInBatch++;
    }
    notifyListeners();
  }

  Future<void> _multipartUpload(Transfer t, String base, File file, int size,
      void Function(int, int?) progress) async {
    // ≤ 9 000 parts keeps well under S3's 10 000-part limit.
    final partSize = max(minPartSize, (size / 9000).ceil());
    final count = max(1, (size / partSize).ceil());

    if (t.uploadId == null) {
      final d = await _api.post('$base/uploads',
          query: {'key': t.key},
          headers: {'Content-Type': guessContentType(t.name)});
      t.uploadId = d['upload_id'] as String;
    } else {
      // Resume: trust the server's list of parts it already has.
      final d = await _api.get(
          '$base/uploads/${ApiClient.seg(t.uploadId!)}/parts');
      t.parts
        ..clear()
        ..addEntries(((d['parts'] as List?) ?? const [])
            .map((p) => UploadedPart.fromJson(p as Map<String, dynamic>))
            .map((p) => MapEntry(p.partNumber, p.etag)));
    }
    final upload = '$base/uploads/${ApiClient.seg(t.uploadId!)}';

    int partLen(int n) =>
        n < count ? partSize : size - partSize * (count - 1);
    var doneBytes = t.parts.keys.fold<int>(0, (s, n) => s + partLen(n));
    progress(doneBytes, size);

    for (var n = 1; n <= count; n++) {
      if (t.parts.containsKey(n)) continue;
      if (t.cancelToken.isCancelled) {
        throw const ApiException(-1, 'Cancelled');
      }
      final before = doneBytes;
      final r = await _api.uploadFile('$upload/parts/$n', file,
          start: (n - 1) * partSize,
          count: partLen(n),
          onProgress: (sent, _) => progress(before + sent, size),
          cancel: t.cancelToken);
      t.parts[n] = r['etag'] as String? ?? '';
      doneBytes += partLen(n);
    }

    final ordered = t.parts.keys.toList()..sort();
    await _api.post('$upload/complete',
        body: {
          'parts': [
            for (final n in ordered) {'part_number': n, 'etag': t.parts[n]}
          ]
        },
        timeout: ApiClient.longTimeout);
    t.uploadId = null;
  }

  @override
  void dispose() {
    cancelAll();
    Desktop.taskbarProgress(null);
    _uploaded.close();
    super.dispose();
  }
}
