// DTOs for the GUI v2 admin endpoints (object info, multipart, webhook
// deliveries, maintenance, sessions, logs, metrics).

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _str(Object? v) => v as String? ?? '';
List<Map<String, dynamic>> _maps(Object? v) =>
    ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

class ObjectInfo {
  final String key;
  final int size;
  final String etag;
  final String contentType;
  final String lastModified;
  final String versionId;
  final Map<String, String> metadata;
  final String diskPath;
  final String bucketDir;
  final VariantInfo? variant;
  final List<VersionInfo> versions;

  const ObjectInfo({
    required this.key,
    this.size = 0,
    this.etag = '',
    this.contentType = '',
    this.lastModified = '',
    this.versionId = '',
    this.metadata = const {},
    this.diskPath = '',
    this.bucketDir = '',
    this.variant,
    this.versions = const [],
  });

  factory ObjectInfo.fromJson(Map<String, dynamic> j) => ObjectInfo(
        key: _str(j['key']),
        size: _int(j['size']),
        etag: _str(j['etag']),
        contentType: _str(j['content_type']),
        lastModified: _str(j['last_modified']),
        versionId: _str(j['version_id']),
        metadata: ((j['metadata'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        diskPath: _str(j['disk_path']),
        bucketDir: _str(j['bucket_dir']),
        variant: j['variant'] is Map<String, dynamic>
            ? VariantInfo.fromJson(j['variant'] as Map<String, dynamic>)
            : null,
        versions: _maps(j['versions']).map(VersionInfo.fromJson).toList(),
      );

  bool get isDeleted => diskPath.isEmpty && versions.isNotEmpty;
}

class VariantInfo {
  final bool exists;
  final String diskPath;
  final int size;
  const VariantInfo({this.exists = false, this.diskPath = '', this.size = 0});
  factory VariantInfo.fromJson(Map<String, dynamic> j) => VariantInfo(
        exists: j['exists'] as bool? ?? false,
        diskPath: _str(j['disk_path']),
        size: _int(j['size']),
      );
}

class VersionInfo {
  final String versionId;
  final int size;
  final String etag;
  final String lastModified;
  final bool isLatest;
  final bool isDeleteMarker;
  final String diskPath;

  const VersionInfo({
    required this.versionId,
    this.size = 0,
    this.etag = '',
    this.lastModified = '',
    this.isLatest = false,
    this.isDeleteMarker = false,
    this.diskPath = '',
  });

  factory VersionInfo.fromJson(Map<String, dynamic> j) => VersionInfo(
        versionId: _str(j['version_id']),
        size: _int(j['size']),
        etag: _str(j['etag']),
        lastModified: _str(j['last_modified']),
        isLatest: j['is_latest'] as bool? ?? false,
        isDeleteMarker: j['is_delete_marker'] as bool? ?? false,
        diskPath: _str(j['disk_path']),
      );
}

class MultipartUploadInfo {
  final String uploadId;
  final String key;
  final String initiated;
  final int parts;
  final int bytes;

  const MultipartUploadInfo({
    required this.uploadId,
    required this.key,
    this.initiated = '',
    this.parts = 0,
    this.bytes = 0,
  });

  factory MultipartUploadInfo.fromJson(Map<String, dynamic> j) =>
      MultipartUploadInfo(
        uploadId: _str(j['upload_id']),
        key: _str(j['key']),
        initiated: _str(j['initiated']),
        parts: _int(j['parts']),
        bytes: _int(j['bytes']),
      );
}

class UploadedPart {
  final int partNumber;
  final String etag;
  final int size;
  const UploadedPart(this.partNumber, this.etag, this.size);
  factory UploadedPart.fromJson(Map<String, dynamic> j) =>
      UploadedPart(_int(j['part_number']), _str(j['etag']), _int(j['size']));
}

class WebhookDelivery {
  final int id;
  final String eventType;
  final String objectKey;
  final int statusCode;
  final String error;
  final int durationMs;
  final int attempt;
  final String createdAt;

  const WebhookDelivery({
    required this.id,
    this.eventType = '',
    this.objectKey = '',
    this.statusCode = 0,
    this.error = '',
    this.durationMs = 0,
    this.attempt = 1,
    this.createdAt = '',
  });

  factory WebhookDelivery.fromJson(Map<String, dynamic> j) => WebhookDelivery(
        id: _int(j['id']),
        eventType: _str(j['event_type']),
        objectKey: _str(j['object_key']),
        statusCode: _int(j['status_code']),
        error: _str(j['error']),
        durationMs: _int(j['duration_ms']),
        attempt: _int(j['attempt']),
        createdAt: _str(j['created_at']),
      );

  bool get ok => error.isEmpty && statusCode >= 200 && statusCode < 300;
}

class ScanReport {
  final List<({String path, int bytes})> orphanDirs;
  final List<({String bucket, String key, String versionId})> missingFiles;
  final List<({String bucket, String path, int bytes})> untrackedFiles;
  final int scannedObjects;
  final bool truncated;

  const ScanReport({
    this.orphanDirs = const [],
    this.missingFiles = const [],
    this.untrackedFiles = const [],
    this.scannedObjects = 0,
    this.truncated = false,
  });

  factory ScanReport.fromJson(Map<String, dynamic> j) => ScanReport(
        orphanDirs: _maps(j['orphan_dirs'])
            .map((m) => (path: _str(m['path']), bytes: _int(m['bytes'])))
            .toList(),
        missingFiles: _maps(j['missing_files'])
            .map((m) => (
                  bucket: _str(m['bucket']),
                  key: _str(m['key']),
                  versionId: _str(m['version_id'])
                ))
            .toList(),
        untrackedFiles: _maps(j['untracked_files'])
            .map((m) => (
                  bucket: _str(m['bucket']),
                  path: _str(m['path']),
                  bytes: _int(m['bytes'])
                ))
            .toList(),
        scannedObjects: _int(j['scanned_objects']),
        truncated: j['truncated'] as bool? ?? false,
      );

  bool get clean =>
      orphanDirs.isEmpty && missingFiles.isEmpty && untrackedFiles.isEmpty;
}

class AdminSession {
  final String id;
  final String username;
  final String createdAt;
  final String lastSeenAt;
  final String expiresAt;
  final String ip;
  final String userAgent;
  final bool current;

  const AdminSession({
    required this.id,
    this.username = '',
    this.createdAt = '',
    this.lastSeenAt = '',
    this.expiresAt = '',
    this.ip = '',
    this.userAgent = '',
    this.current = false,
  });

  factory AdminSession.fromJson(Map<String, dynamic> j) => AdminSession(
        id: _str(j['id']),
        username: _str(j['username']),
        createdAt: _str(j['created_at']),
        lastSeenAt: _str(j['last_seen_at']),
        expiresAt: _str(j['expires_at']),
        ip: _str(j['ip']),
        userAgent: _str(j['user_agent']),
        current: j['current'] as bool? ?? false,
      );
}

class LogEntry {
  final int id;
  final String time;
  final String level;
  final String message;
  final Map<String, String> attrs;

  const LogEntry({
    required this.id,
    this.time = '',
    this.level = 'INFO',
    this.message = '',
    this.attrs = const {},
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: _int(j['id']),
        time: _str(j['time']),
        level: _str(j['level']).toUpperCase(),
        message: _str(j['message']),
        attrs: ((j['attrs'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
}

class MetricsPoint {
  final String time;
  final int requests;
  final int errors;
  final int bytesIn;
  final int bytesOut;
  const MetricsPoint(
      this.time, this.requests, this.errors, this.bytesIn, this.bytesOut);
  factory MetricsPoint.fromJson(Map<String, dynamic> j) => MetricsPoint(
        _str(j['time']),
        _int(j['requests']),
        _int(j['errors']),
        _int(j['bytes_in']),
        _int(j['bytes_out']),
      );
}

class ServerMetrics {
  final String since;
  final int requests;
  final int errors4xx;
  final int errors5xx;
  final int bytesIn;
  final int bytesOut;
  final Map<String, int> byMethod;
  final List<MetricsPoint> series;

  const ServerMetrics({
    this.since = '',
    this.requests = 0,
    this.errors4xx = 0,
    this.errors5xx = 0,
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.byMethod = const {},
    this.series = const [],
  });

  factory ServerMetrics.fromJson(Map<String, dynamic> j) {
    final s3 = (j['s3'] as Map<String, dynamic>?) ?? const {};
    return ServerMetrics(
      since: _str(j['since']),
      requests: _int(s3['requests']),
      errors4xx: _int(s3['errors_4xx']),
      errors5xx: _int(s3['errors_5xx']),
      bytesIn: _int(s3['bytes_in']),
      bytesOut: _int(s3['bytes_out']),
      byMethod: ((s3['by_method'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      series: _maps(j['series']).map(MetricsPoint.fromJson).toList(),
    );
  }
}
