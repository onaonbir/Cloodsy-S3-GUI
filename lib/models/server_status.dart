/// `GET /admin/status`. Fields beyond `status`/`version`/`buckets` arrived
/// in later server releases, so every one of them is optional.
class ServerStatus {
  final String status;
  final String version;
  final int buckets;
  final bool adminExists;
  final bool webdavEnabled;
  final String webdavListen;

  /// Capability flags (`object-download`, `object-upload`,
  /// `object-versions`, …). Empty on servers older than the GUI v2 API.
  final Set<String> features;
  final int? uptimeSeconds;
  final TlsStatus? tls;
  final StorageStatus? storage;
  final S3Endpoint? s3;
  final HostInfo? host;

  const ServerStatus({
    required this.status,
    this.version = '',
    this.buckets = 0,
    this.adminExists = false,
    this.webdavEnabled = false,
    this.webdavListen = '',
    this.features = const {},
    this.uptimeSeconds,
    this.tls,
    this.storage,
    this.s3,
    this.host,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final webdav = json['webdav'];
    final tls = json['tls'];
    final storage = json['storage'];
    final features = json['features'];
    return ServerStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '',
      buckets: (json['buckets'] as num?)?.toInt() ?? 0,
      adminExists: json['admin_exists'] as bool? ?? false,
      webdavEnabled: webdav is Map ? webdav['enabled'] as bool? ?? false : false,
      webdavListen: webdav is Map ? webdav['listen'] as String? ?? '' : '',
      features: features is List
          ? features.whereType<String>().toSet()
          : const <String>{},
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt(),
      tls: tls is Map<String, dynamic> ? TlsStatus.fromJson(tls) : null,
      storage: storage is Map<String, dynamic>
          ? StorageStatus.fromJson(storage)
          : null,
      s3: json['s3'] is Map<String, dynamic>
          ? S3Endpoint.fromJson(json['s3'] as Map<String, dynamic>)
          : null,
      host: json['host'] is Map<String, dynamic>
          ? HostInfo.fromJson(json['host'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isOk => status == 'ok';
  bool has(String feature) => features.contains(feature);
  bool get canDownload => has('object-download');
  bool get canUpload => has('object-upload');
  bool get canListVersions => has('object-versions');
  bool get canObjectInfo => has('object-info');
  bool get canRange => has('object-range');
  bool get canCopy => has('object-copy');
  bool get canSearch => has('object-search');
  bool get canPrefixStats => has('prefix-stats');
  bool get canEditMetadata => has('object-metadata');
  bool get canMultipart => has('multipart');
  bool get lifecycleV2 => has('lifecycle-v2');
  bool get webhooksV2 => has('webhooks-v2');
  bool get canMaintenance => has('maintenance');
  bool get canSessions => has('sessions');
  bool get canLogs => has('logs');
  bool get canConfig => has('config');
  bool get canMetrics => has('metrics');
}

/// The S3 listener of the server (`status.s3`).
class S3Endpoint {
  final String listen;
  final bool tls;
  final String region;
  final List<String> virtualHostDomains;

  const S3Endpoint({
    this.listen = '',
    this.tls = false,
    this.region = 'us-east-1',
    this.virtualHostDomains = const [],
  });

  factory S3Endpoint.fromJson(Map<String, dynamic> j) => S3Endpoint(
        listen: j['listen'] as String? ?? '',
        tls: j['tls'] as bool? ?? false,
        region: (j['region'] as String?)?.isNotEmpty == true
            ? j['region'] as String
            : 'us-east-1',
        virtualHostDomains: (j['virtual_host_domains'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );

  String get port {
    final i = listen.lastIndexOf(':');
    return i >= 0 ? listen.substring(i + 1) : listen;
  }
}

/// Where the server process runs (`status.host`), used to open object files
/// locally when the GUI runs on the same machine.
class HostInfo {
  final String os;
  final String hostname;
  final String wslDistro;

  const HostInfo({this.os = '', this.hostname = '', this.wslDistro = ''});

  factory HostInfo.fromJson(Map<String, dynamic> j) => HostInfo(
        os: j['os'] as String? ?? '',
        hostname: j['hostname'] as String? ?? '',
        wslDistro: j['wsl_distro'] as String? ?? '',
      );
}

class TlsStatus {
  final bool s3;
  final bool admin;
  final bool webdav;
  final bool acme;
  final List<String> acmeDomains;

  const TlsStatus({
    this.s3 = false,
    this.admin = false,
    this.webdav = false,
    this.acme = false,
    this.acmeDomains = const [],
  });

  factory TlsStatus.fromJson(Map<String, dynamic> json) => TlsStatus(
        s3: json['s3'] as bool? ?? false,
        admin: json['admin'] as bool? ?? false,
        webdav: json['webdav'] as bool? ?? false,
        acme: json['acme'] as bool? ?? false,
        acmeDomains: (json['acme_domains'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );
}

class StorageStatus {
  final String path;
  final int totalBytes;
  final int freeBytes;

  const StorageStatus({this.path = '', this.totalBytes = 0, this.freeBytes = 0});

  factory StorageStatus.fromJson(Map<String, dynamic> json) => StorageStatus(
        path: json['path'] as String? ?? '',
        totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
        freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      );

  bool get hasDiskStats => totalBytes > 0;
  int get usedBytes => totalBytes - freeBytes;
  double get usedFraction => totalBytes > 0 ? usedBytes / totalBytes : 0;
}
