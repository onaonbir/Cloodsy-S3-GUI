import 'dart:convert';

import 'package:crypto/crypto.dart';

/// AWS Signature V4 query-string presigning (what `aws s3 presign` does),
/// computed locally from a bucket access key. The secret never leaves the
/// machine; the server validates the signature like any S3 client request.
class Presigner {
  Presigner._();

  static const _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';

  /// RFC 3986 encoding as SigV4 requires it (`/` kept only for paths).
  static String awsEncode(String s, {bool keepSlash = false}) {
    final out = StringBuffer();
    for (final b in utf8.encode(s)) {
      final ch = String.fromCharCode(b);
      if (_unreserved.contains(ch) || (keepSlash && ch == '/')) {
        out.write(ch);
      } else {
        out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Presigns [url] (scheme, host, port, path; no query) for [method].
  static Uri presign({
    required Uri url,
    required String accessKey,
    required String secretKey,
    String region = 'us-east-1',
    String method = 'GET',
    Duration expires = const Duration(hours: 1),
    DateTime? now,
    Map<String, String> extraQuery = const {},
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    final date = '${t.year}${_two(t.month)}${_two(t.day)}';
    final amzDate = '${date}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';
    final scope = '$date/$region/s3/aws4_request';

    final defaultPort = (url.scheme == 'https' && url.port == 443) ||
        (url.scheme == 'http' && url.port == 80);
    final host = url.hasPort && !defaultPort ? '${url.host}:${url.port}' : url.host;

    final params = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKey/$scope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '${expires.inSeconds}',
      'X-Amz-SignedHeaders': 'host',
      ...extraQuery,
    };
    final keys = params.keys.toList()..sort();
    final canonicalQuery = keys
        .map((k) => '${awsEncode(k)}=${awsEncode(params[k]!)}')
        .join('&');

    // url.path is already percent-encoded by Uri; re-encode from the decoded
    // segments so the canonical form is exactly SigV4's.
    final canonicalPath = '/${url.pathSegments.map(awsEncode).join('/')}';

    final canonicalRequest = [
      method,
      canonicalPath,
      canonicalQuery,
      'host:$host\n',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final kDate = hmac(utf8.encode('AWS4$secretKey'), date);
    final kRegion = hmac(kDate, region);
    final kService = hmac(kRegion, 's3');
    final kSigning = hmac(kService, 'aws4_request');
    final signature = Hmac(sha256, kSigning)
        .convert(utf8.encode(stringToSign))
        .toString();

    return Uri.parse(
        '${url.scheme}://$host$canonicalPath?$canonicalQuery&X-Amz-Signature=$signature');
  }

  /// Path-style object URL: `<endpoint>/<bucket>/<key>`.
  static Uri objectUrl(String endpoint, String bucket, String key) {
    var e = endpoint;
    while (e.endsWith('/')) {
      e = e.substring(0, e.length - 1);
    }
    return Uri.parse(
        '$e/${awsEncode(bucket)}/${awsEncode(key, keepSlash: true)}');
  }
}
