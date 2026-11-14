import 'dart:convert';

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String username;

  /// Public S3 endpoint used for share links (e.g. behind a reverse proxy).
  /// Empty → derived from the admin host and the server's S3 port.
  final String s3Url;

  ServerConnection({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    this.s3Url = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
        if (s3Url.isNotEmpty) 's3_url': s3Url,
      };

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
      s3Url: json['s3_url'] as String? ?? '',
    );
  }

  static String encodeList(List<ServerConnection> servers) {
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }

  static List<ServerConnection> decodeList(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((j) => ServerConnection.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  ServerConnection copyWith(
      {String? name, String? url, String? username, String? s3Url}) {
    return ServerConnection(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      s3Url: s3Url ?? this.s3Url,
    );
  }
}
