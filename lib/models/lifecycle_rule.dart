class LifecycleRule {
  final int id;
  final String name;
  final String prefix;
  final int expirationDays;
  final String createdAt;

  LifecycleRule({
    required this.id,
    this.name = '',
    required this.prefix,
    required this.expirationDays,
    required this.createdAt,
  });

  factory LifecycleRule.fromJson(Map<String, dynamic> json) {
    return LifecycleRule(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      expirationDays: (json['expiration_days'] as num).toInt(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get prefixDisplay => prefix.isEmpty ? '(all)' : prefix;
  String get displayName => name.isNotEmpty ? name : 'Expire ${expirationDays}d';
}
