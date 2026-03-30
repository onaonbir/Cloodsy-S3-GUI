class AdminUser {
  final int id;
  final String username;
  final String createdAt;

  AdminUser({
    required this.id,
    required this.username,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
