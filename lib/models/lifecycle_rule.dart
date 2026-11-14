import '../core/i18n.dart';

class LifecycleRule {
  final int id;
  final String name;
  final String prefix;
  final bool enabled;
  final int expirationDays; // current versions; 0 = off
  final int noncurrentDays; // older versions; 0 = off
  final int abortMultipartDays; // incomplete uploads; 0 = off
  final bool expireDeleteMarkers;
  final String createdAt;

  const LifecycleRule({
    required this.id,
    this.name = '',
    this.prefix = '',
    this.enabled = true,
    this.expirationDays = 0,
    this.noncurrentDays = 0,
    this.abortMultipartDays = 0,
    this.expireDeleteMarkers = false,
    this.createdAt = '',
  });

  factory LifecycleRule.fromJson(Map<String, dynamic> json) {
    return LifecycleRule(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      enabled: (json['status'] as String? ?? 'Enabled') != 'Disabled',
      expirationDays: (json['expiration_days'] as num?)?.toInt() ?? 0,
      noncurrentDays: (json['noncurrent_days'] as num?)?.toInt() ?? 0,
      abortMultipartDays: (json['abort_multipart_days'] as num?)?.toInt() ?? 0,
      expireDeleteMarkers: json['expire_delete_markers'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'prefix': prefix,
        'status': enabled ? 'Enabled' : 'Disabled',
        'expiration_days': expirationDays,
        'noncurrent_days': noncurrentDays,
        'abort_multipart_days': abortMultipartDays,
        'expire_delete_markers': expireDeleteMarkers,
      };

  LifecycleRule copyWith({bool? enabled}) => LifecycleRule(
        id: id,
        name: name,
        prefix: prefix,
        enabled: enabled ?? this.enabled,
        expirationDays: expirationDays,
        noncurrentDays: noncurrentDays,
        abortMultipartDays: abortMultipartDays,
        expireDeleteMarkers: expireDeleteMarkers,
        createdAt: createdAt,
      );

  String get prefixDisplay => prefix.isEmpty ? '(all)' : prefix;
  String get displayName => name.isNotEmpty ? name : tr('Rule #{id}', {'id': id});

  /// Human-readable actions, e.g. ["Delete after 30 days", …].
  List<String> get actions => [
        if (expirationDays > 0)
          tr('Delete objects after {n} days', {'n': expirationDays}),
        if (noncurrentDays > 0)
          tr('Delete old versions after {n} days', {'n': noncurrentDays}),
        if (abortMultipartDays > 0)
          tr('Abort incomplete uploads after {n} days', {'n': abortMultipartDays}),
        if (expireDeleteMarkers) tr('Remove orphan delete markers'),
      ];
}
