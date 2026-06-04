class ServerStatus {
  final String status;
  final String version;
  final int buckets;
  final bool adminExists;
  final bool webdavEnabled;
  final String webdavListen;

  ServerStatus({
    required this.status,
    this.version = '',
    required this.buckets,
    required this.adminExists,
    this.webdavEnabled = false,
    this.webdavListen = '',
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final webdav = json['webdav'] as Map<String, dynamic>?;
    return ServerStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '',
      buckets: (json['buckets'] as num?)?.toInt() ?? 0,
      adminExists: json['admin_exists'] as bool? ?? false,
      webdavEnabled: (webdav?['enabled'] as bool?) ?? false,
      webdavListen: (webdav?['listen'] as String?) ?? '',
    );
  }

  bool get isOk => status == 'ok';
}
