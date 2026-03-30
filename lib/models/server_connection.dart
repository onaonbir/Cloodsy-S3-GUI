import 'dart:convert';

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String username;

  ServerConnection({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
      };

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
    );
  }

  static String encodeList(List<ServerConnection> servers) {
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }

  static List<ServerConnection> decodeList(String json) {
    final list = jsonDecode(json) as List;
    return list.map((j) => ServerConnection.fromJson(j)).toList();
  }

  ServerConnection copyWith({String? name, String? url, String? username}) {
    return ServerConnection(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
    );
  }
}
