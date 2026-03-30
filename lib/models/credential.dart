class Credential {
  final int id;
  final String name;
  final String accessKey;
  final String? secretKey;
  final String permission;
  final String createdAt;

  Credential({
    required this.id,
    this.name = '',
    required this.accessKey,
    this.secretKey,
    required this.permission,
    required this.createdAt,
  });

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      accessKey: json['access_key'] as String,
      secretKey: json['secret_key'] as String?,
      permission: json['permission'] as String? ?? 'read-write',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isReadOnly => permission == 'read-only';
  String get displayName => name.isNotEmpty ? name : accessKey;
}
