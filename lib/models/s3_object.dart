class S3Object {
  final String key;
  final int size;
  final String etag;
  final String contentType;
  final String lastModified;

  const S3Object({
    required this.key,
    required this.size,
    this.etag = '',
    this.contentType = '',
    required this.lastModified,
  });

  factory S3Object.fromJson(Map<String, dynamic> json) {
    return S3Object(
      key: json['key'] as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
      etag: json['etag'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      lastModified: json['last_modified'] as String? ?? '',
    );
  }

  /// The last path segment of the key.
  String get fileName {
    final trimmed =
        key.endsWith('/') ? key.substring(0, key.length - 1) : key;
    return trimmed.split('/').last;
  }

  /// Lower-cased extension without the dot.
  String get extension {
    final name = fileName;
    final idx = name.lastIndexOf('.');
    if (idx <= 0) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  /// Zero-byte `foo/` keys that S3 clients create to represent folders.
  bool get isFolderMarker => key.endsWith('/') && size == 0;
}

class ObjectListResult {
  final List<S3Object> objects;
  final List<String> prefixes;
  final String prefix;
  final bool truncated;
  final String nextMarker;

  const ObjectListResult({
    required this.objects,
    required this.prefixes,
    required this.prefix,
    required this.truncated,
    required this.nextMarker,
  });

  factory ObjectListResult.fromJson(Map<String, dynamic> json) {
    return ObjectListResult(
      objects: ((json['objects'] as List?) ?? const [])
          .map((o) => S3Object.fromJson(o as Map<String, dynamic>))
          .toList(),
      prefixes: ((json['prefixes'] as List?) ?? const [])
          .map((p) => p.toString())
          .toList(),
      prefix: json['prefix'] as String? ?? '',
      truncated: json['truncated'] as bool? ?? false,
      nextMarker: json['next_marker'] as String? ?? '',
    );
  }
}

/// One entry of `GET /admin/buckets/{b}/versions?key=`.
class ObjectVersion {
  final String versionId;
  final int size;
  final String etag;
  final String contentType;
  final String lastModified;
  final bool isLatest;
  final bool isDeleteMarker;

  const ObjectVersion({
    required this.versionId,
    this.size = 0,
    this.etag = '',
    this.contentType = '',
    this.lastModified = '',
    this.isLatest = false,
    this.isDeleteMarker = false,
  });

  factory ObjectVersion.fromJson(Map<String, dynamic> json) => ObjectVersion(
        versionId: json['version_id'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        etag: json['etag'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        lastModified: json['last_modified'] as String? ?? '',
        isLatest: json['is_latest'] as bool? ?? false,
        isDeleteMarker: json['is_delete_marker'] as bool? ?? false,
      );

  /// The unversioned "null" version id S3 uses for pre-versioning objects.
  bool get isNullVersion => versionId.isEmpty || versionId == 'null';
}
