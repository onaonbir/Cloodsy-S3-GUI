class Webhook {
  final int id;
  final String name;
  final String url;
  final String eventTypes;
  final bool active;
  final bool hasSecret;
  final String createdAt;

  Webhook({
    required this.id,
    this.name = '',
    required this.url,
    required this.eventTypes,
    this.active = true,
    this.hasSecret = false,
    required this.createdAt,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) {
    return Webhook(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      eventTypes: json['event_types'] as String? ?? '*',
      active: json['active'] as bool? ?? true,
      hasSecret: json['has_secret'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get displayName => name.isNotEmpty ? name : url;
}
