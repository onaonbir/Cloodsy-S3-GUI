import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the Cloodsy S3 Admin API, enough for controller
/// and widget tests.
class FakeServer {
  final Map<String, String> admins = {'admin': 'secret-pass'};
  final Set<String> tokens = {};
  final List<http.Request> requests = [];
  final List<Map<String, dynamic>> buckets = [
    {
      'id': 1,
      'name': 'photos',
      'objects': 3,
      'usage_bytes': 3072,
      'quota_bytes': 0,
      'versioning': 'Enabled',
      'created_at': '2026-11-01T10:00:00Z',
    },
  ];

  /// key → size, for the object listing of every bucket.
  final Map<String, int> objects = {};

  bool newApi = true;

  final Map<String, ({String key, Map<int, List<int>> parts})> uploads = {};
  final Map<String, List<int>> completed = {};
  int partPuts = 0;

  /// Makes the PUT of this part number fail once (resume test).
  int? failPartOnce;
  int _tokenSeq = 0;

  http.Response _json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  late final MockClient client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path.replaceFirst('/admin', '');

    if (path == '/login' && req.method == 'POST') {
      final b = jsonDecode(req.body) as Map;
      if (admins[b['username']] != b['password']) {
        return _json(401, {'error': 'invalid credentials'});
      }
      final token = 'tok${++_tokenSeq}';
      tokens.add(token);
      return _json(200, {
        'token': token,
        'username': b['username'],
        'expires_in': 3600,
      });
    }

    final auth = req.headers['Authorization'] ?? '';
    if (!tokens.contains(auth.replaceFirst('Bearer ', ''))) {
      return _json(401, {'error': 'unauthorized'});
    }

    switch ((req.method, path)) {
      case ('GET', '/status'):
        return _json(200, {
          'status': 'ok',
          'version': '1.4.0',
          'buckets': buckets.length,
          'admin_exists': true,
          'webdav': {'enabled': false, 'listen': ':9002'},
          if (newApi) ...{
            'features': [
              'object-download', 'object-upload', 'object-versions',
              'multipart', 'object-copy', 'object-search', 'sessions',
            ],
            'uptime_seconds': 3700,
            'tls': {'s3': true, 'admin': false, 'webdav': false, 'acme': false, 'acme_domains': []},
            'storage': {'path': '/data', 'total_bytes': 1000, 'free_bytes': 250},
          },
        });
      case ('POST', '/logout'):
        tokens.remove(auth.replaceFirst('Bearer ', ''));
        return _json(200, {'message': 'ok'});
      case ('GET', '/buckets'):
        return _json(200, {'buckets': buckets});
      case ('GET', '/admins'):
        return _json(200, {
          'admins': [
            for (final (i, u) in admins.keys.indexed)
              {'id': i + 1, 'username': u, 'created_at': '2026-01-01T00:00:00Z'}
          ]
        });
    }

    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0] == 'admins' && req.method == 'PUT') {
      final user = Uri.decodeComponent(parts[1]);
      final b = jsonDecode(req.body) as Map;
      final pw = (b['password'] as String?) ?? 'generated-pw-123';
      admins[user] = pw;
      tokens.clear(); // the real server revokes the user's sessions
      return _json(200, {
        'username': user,
        'password': pw,
        'auto_generated': b['password'] == null,
      });
    }
    if (parts.length >= 2 && parts[0] == 'buckets') {
      final name = Uri.decodeComponent(parts[1]);
      final bucket = buckets.where((b) => b['name'] == name).firstOrNull;
      if (bucket == null) return _json(404, {'error': 'bucket not found'});
      if (parts.length == 2 && req.method == 'GET') return _json(200, bucket);
      final sub = parts.length > 2 ? parts[2] : '';
      if (req.method == 'GET' && sub == 'credentials') {
        return _json(200, {'credentials': []});
      }
      if (req.method == 'GET' && sub == 'lifecycle') {
        return _json(200, {'rules': []});
      }
      if (req.method == 'GET' && sub == 'webhooks') {
        return _json(200, {'webhooks': []});
      }
      if (req.method == 'GET' && sub == 'objects') {
        return _list(req.url.queryParameters);
      }
      // --- multipart (mirrors admin/multipart.go)
      if (sub == 'uploads' && parts.length == 3 && req.method == 'POST') {
        final id = 'up${++_tokenSeq}';
        uploads[id] = (key: req.url.queryParameters['key']!, parts: <int, List<int>>{});
        return _json(200, {'upload_id': id, 'key': uploads[id]!.key});
      }
      if (sub == 'uploads' && parts.length >= 4) {
        final up = uploads[parts[3]];
        if (up == null) return _json(404, {'error': 'upload not found'});
        if (parts.length == 6 && parts[4] == 'parts' && req.method == 'PUT') {
          if (failPartOnce != null && int.parse(parts[5]) == failPartOnce) {
            failPartOnce = null;
            return _json(500, {'error': 'disk hiccup'});
          }
          up.parts[int.parse(parts[5])] = req.bodyBytes;
          partPuts++;
          return _json(200, {
            'part_number': int.parse(parts[5]),
            'etag': 'e${parts[5]}',
            'size': req.bodyBytes.length,
          });
        }
        if (parts.length == 5 && parts[4] == 'parts' && req.method == 'GET') {
          return _json(200, {
            'parts': [
              for (final e in up.parts.entries)
                {'part_number': e.key, 'etag': 'e${e.key}', 'size': e.value.length}
            ]
          });
        }
        if (parts.length == 5 && parts[4] == 'complete' && req.method == 'POST') {
          final nums = up.parts.keys.toList()..sort();
          final all = [for (final n in nums) ...up.parts[n]!];
          objects[up.key] = all.length;
          completed[up.key] = all;
          uploads.remove(parts[3]);
          return _json(200, {'key': up.key, 'size': all.length, 'etag': 'm', 'version_id': ''});
        }
        if (parts.length == 4 && req.method == 'DELETE') {
          uploads.remove(parts[3]);
          return _json(200, {'message': 'aborted'});
        }
      }
      if (req.method == 'PUT' && sub == 'object') {
        final key = req.url.queryParameters['key']!;
        if (key.endsWith('/') && req.bodyBytes.isNotEmpty) {
          return _json(400, {'error': 'folder marker must have an empty body'});
        }
        objects[key] = req.bodyBytes.length;
        return _json(200, {'key': key, 'size': req.bodyBytes.length, 'etag': 'e', 'version_id': ''});
      }
    }
    return _json(404, {'error': 'not found'});
  });

  http.Response _list(Map<String, String> q) {
    final prefix = q['prefix'] ?? '';
    final marker = q['marker'] ?? '';
    final max = int.parse(q['max-keys'] ?? '200');
    final keys = objects.keys.where((k) => k.startsWith(prefix)).toList()..sort();
    final folders = <String>{};
    final files = <String>[];
    for (final k in keys) {
      final rest = k.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash >= 0 && slash < rest.length - 1) {
        folders.add('$prefix${rest.substring(0, slash + 1)}');
      } else {
        files.add(k);
      }
    }
    final page = files.where((k) => k.compareTo(marker) > 0).take(max).toList();
    final truncated = files.where((k) => k.compareTo(marker) > 0).length > max;
    return _json(200, {
      'objects': [
        for (final k in page)
          {
            'key': k,
            'size': objects[k],
            'etag': 'e',
            'content_type': 'text/plain',
            'last_modified': '2026-11-10T08:00:00Z',
          }
      ],
      'prefixes': marker.isEmpty ? folders.toList() : [],
      'prefix': prefix,
      'truncated': truncated,
      'next_marker': truncated ? page.last : '',
    });
  }
}
