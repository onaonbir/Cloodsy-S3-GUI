class Bucket {
  final int id;
  final String name;
  final int quotaBytes;
  final String versioning;
  final String storageDir;
  final String? storagePath;
  final bool publicRead;
  final bool webdavEnabled;
  final int objects;
  final int usageBytes;
  final int credentials;
  final String createdAt;

  Bucket({
    required this.id,
    required this.name,
    this.quotaBytes = 0,
    this.versioning = '',
    this.storageDir = '',
    this.storagePath,
    this.publicRead = false,
    this.webdavEnabled = false,
    this.objects = 0,
    this.usageBytes = 0,
    this.credentials = 0,
    required this.createdAt,
  });

  factory Bucket.fromJson(Map<String, dynamic> json) {
    return Bucket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String,
      quotaBytes: (json['quota_bytes'] as num?)?.toInt() ?? 0,
      versioning: json['versioning'] as String? ?? '',
      storageDir: json['storage_dir'] as String? ?? '',
      storagePath: json['storage_path'] as String?,
      publicRead: json['public_read'] as bool? ?? false,
      webdavEnabled: json['webdav_enabled'] as bool? ?? false,
      objects: (json['objects'] as num?)?.toInt() ?? 0,
      usageBytes: (json['usage_bytes'] as num?)?.toInt() ?? 0,
      credentials: (json['credentials'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get versioningDisplay =>
      versioning.isEmpty ? 'Disabled' : versioning;

  bool get versioningEnabled => versioning == 'Enabled';
  bool get hasQuota => quotaBytes > 0;

  String get publicReadDisplay => publicRead ? 'Enabled' : 'Disabled';

  double get quotaUsagePercent {
    if (quotaBytes <= 0) return 0;
    return usageBytes / quotaBytes;
  }
}
