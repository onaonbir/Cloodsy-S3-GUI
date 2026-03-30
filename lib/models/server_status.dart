class ServerStatus {
  final String status;
  final String version;
  final int buckets;
  final bool adminExists;

  ServerStatus({
    required this.status,
    this.version = '',
    required this.buckets,
    required this.adminExists,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '',
      buckets: (json['buckets'] as num?)?.toInt() ?? 0,
      adminExists: json['admin_exists'] as bool? ?? false,
    );
  }

  bool get isOk => status == 'ok';
}
