class S3Object {
  final String key;
  final int size;
  final String etag;
  final String contentType;
  final String lastModified;

  S3Object({
    required this.key,
    required this.size,
    this.etag = '',
    this.contentType = '',
    required this.lastModified,
  });

  factory S3Object.fromJson(Map<String, dynamic> json) {
    return S3Object(
      key: json['key'] as String,
      size: (json['size'] as num).toInt(),
      etag: json['etag'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      lastModified: json['last_modified'] as String? ?? '',
    );
  }

  /// Returns just the filename portion of the key
  String get fileName {
    final parts = key.split('/');
    return parts.last;
  }

  /// File extension (lowercase, without dot)
  String get extension {
    final name = fileName;
    final idx = name.lastIndexOf('.');
    if (idx < 0) return '';
    return name.substring(idx + 1).toLowerCase();
  }
}

class ObjectListResult {
  final List<S3Object> objects;
  final List<String> prefixes;
  final String prefix;
  final bool truncated;
  final String nextMarker;

  ObjectListResult({
    required this.objects,
    required this.prefixes,
    required this.prefix,
    required this.truncated,
    required this.nextMarker,
  });

  factory ObjectListResult.fromJson(Map<String, dynamic> json) {
    return ObjectListResult(
      objects: ((json['objects'] as List?) ?? [])
          .map((o) => S3Object.fromJson(o))
          .toList(),
      prefixes: ((json['prefixes'] as List?) ?? [])
          .map((p) => p.toString())
          .toList(),
      prefix: json['prefix'] as String? ?? '',
      truncated: json['truncated'] as bool? ?? false,
      nextMarker: json['next_marker'] as String? ?? '',
    );
  }
}
