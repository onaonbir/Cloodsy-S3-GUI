class Webhook {
  final int id;
  final String name;
  final String url;
  final String eventTypes;
  final bool active;
  final String createdAt;

  Webhook({
    required this.id,
    this.name = '',
    required this.url,
    required this.eventTypes,
    this.active = true,
    required this.createdAt,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) {
    return Webhook(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      url: json['url'] as String,
      eventTypes: json['event_types'] as String? ?? '*',
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get displayName => name.isNotEmpty ? name : url;
}
