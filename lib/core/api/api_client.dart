import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Decoded JSON body of the error response, when the server sent one.
  /// Some endpoints attach extra fields next to `error` (delete-prefix
  /// reports `deleted`/`failed` counts even when it fails half-way).
  final Map<String, dynamic>? data;

  const ApiException(this.statusCode, this.message, {this.data});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isTooManyRequests => statusCode == 429;

  /// True when the request never reached the server (DNS, refused, TLS,
  /// timeout) as opposed to an HTTP error response.
  bool get isConnectionError => statusCode == 0;

  /// The user cancelled a transfer.
  bool get isCancelled => statusCode == -1;

  @override
  String toString() => message;
}

/// Cancels an in-flight upload or download.
class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

typedef ProgressCallback = void Function(int done, int? total);

/// Thin client for the Cloodsy S3 Admin REST API (`<server>/admin/...`).
///
/// Paths passed in are already-encoded path strings; build them with [seg]
/// for any user-controlled segment (bucket names, usernames, object keys).
class ApiClient {
  String baseUrl;
  String? token;
  final http.Client _client;

  /// Default per-request timeout. Long-running operations (storage move,
  /// prefix delete, forced bucket delete) pass [longTimeout] instead.
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(minutes: 5);

  /// Called when a 401 is received (token expired / revoked). Not invoked
  /// for the login endpoint itself, where 401 means wrong credentials.
  void Function()? onUnauthorized;

  ApiClient({this.baseUrl = '', this.token, http.Client? client})
      : _client = client ?? http.Client();

  /// Percent-encodes one path segment.
  static String seg(String s) => Uri.encodeComponent(s);

  /// Encodes an object key for use as a multi-segment path, keeping `/`.
  static String keyPath(String key) => key.split('/').map(seg).join('/');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$baseUrl/admin$path');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  Map<String, dynamic> _handleResponse(http.Response response, String path) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Not JSON (proxy error page, plain-text 413 from a body limiter, …).
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? <String, dynamic>{};
    }
    throw _httpError(response.statusCode, body, path);
  }

  ApiException _httpError(int status, Map<String, dynamic>? body, String path) {
    if (status == 401 && path != '/login') onUnauthorized?.call();
    return ApiException(status, errorMessage(status, body), data: body);
  }

  /// Prefers the server's own `error` text; falls back to a clear message
  /// for status codes the server may return without a JSON body.
  static String errorMessage(int status, Map<String, dynamic>? body) {
    final serverMsg = body?['error'];
    switch (status) {
      case 401:
        return serverMsg is String && serverMsg != 'unauthorized'
            ? serverMsg
            : 'Session expired or invalid credentials';
      case 413:
        return serverMsg is String && serverMsg.isNotEmpty
            ? serverMsg
            : 'Request too large (server limit exceeded)';
      case 429:
        return 'Too many failed login attempts. Try again in 15 minutes.';
    }
    if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
    switch (status) {
      case 400:
        return 'Invalid request';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not found';
      case 409:
        return 'Conflict';
      case 500:
        return 'Server error';
      case 502:
      case 503:
      case 504:
        return 'Server unavailable ($status)';
    }
    return 'Request failed ($status)';
  }

  /// Maps transport-level failures to messages a user can act on.
  static ApiException connectionError(Object e) {
    if (e is ApiException) return e;
    if (e is http.RequestAbortedException) {
      return const ApiException(-1, 'Cancelled');
    }
    if (e is HandshakeException) {
      return const ApiException(
          0,
          'TLS handshake failed: the server certificate is not trusted '
          '(self-signed?). Install the CA certificate on this machine or use '
          'a certificate from a trusted authority.');
    }
    if (e is TimeoutException) {
      return const ApiException(0, 'Connection timed out');
    }
    if (e is SocketException) {
      final os = e.osError?.message;
      return ApiException(0,
          'Cannot reach server: ${os != null && os.isNotEmpty ? os : e.message}');
    }
    if (e is http.ClientException) {
      return ApiException(0, 'Connection failed: ${e.message}');
    }
    if (e is FileSystemException) {
      return ApiException(0, 'File error: ${e.message} (${e.path ?? ''})');
    }
    return ApiException(0, 'Connection failed: $e');
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      final req = http.Request(method, uri(path, query))
        ..headers.addAll(_headers)
        ..headers.addAll(headers ?? const {});
      if (body != null) req.body = jsonEncode(body);
      final streamed =
          await _client.send(req).timeout(timeout ?? defaultTimeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout ?? defaultTimeout);
      return _handleResponse(response, path);
    } catch (e) {
      throw connectionError(e);
    }
  }

  Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? query, Duration? timeout}) =>
      _json('GET', path, query: query, timeout: timeout);

  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body,
          Map<String, String>? query,
          Duration? timeout,
          Map<String, String>? headers}) =>
      _json('POST', path,
          query: query, body: body ?? {}, timeout: timeout, headers: headers);

  Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body,
          Map<String, String>? query,
          Duration? timeout}) =>
      _json('PUT', path, query: query, body: body ?? {}, timeout: timeout);

  Future<Map<String, dynamic>> delete(String path,
          {Map<String, String>? query, Duration? timeout}) =>
      _json('DELETE', path, query: query, timeout: timeout);

  /// Reads (part of) a binary response into memory, e.g. object previews.
  /// [maxBytes] sends a `Range` request when the server supports ranges and
  /// also caps what is read when it doesn't.
  Future<({List<int> bytes, int? total, String contentType})> getBytes(
    String path, {
    Map<String, String>? query,
    int? maxBytes,
    bool useRange = true,
  }) async {
    try {
      final req = http.Request('GET', uri(path, query))
        ..headers.addAll({
          if (token != null) 'Authorization': 'Bearer $token',
          if (maxBytes != null && useRange) 'Range': 'bytes=0-${maxBytes - 1}',
        });
      final resp = await _client.send(req).timeout(defaultTimeout);
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        _handleResponse(await http.Response.fromStream(resp), path);
      }
      final out = <int>[];
      await for (final chunk in resp.stream) {
        out.addAll(chunk);
        if (maxBytes != null && out.length >= maxBytes) break;
      }
      int? total = resp.contentLength;
      final range = resp.headers['content-range'];
      if (range != null && range.contains('/')) {
        total = int.tryParse(range.split('/').last) ?? total;
      }
      return (
        bytes: maxBytes != null && out.length > maxBytes
            ? out.sublist(0, maxBytes)
            : out,
        total: total,
        contentType: resp.headers['content-type'] ?? '',
      );
    } catch (e) {
      throw connectionError(e);
    }
  }

  /// `PUT`s raw bytes (small object uploads such as empty folder markers).
  Future<Map<String, dynamic>> putBytes(
    String path,
    List<int> bytes, {
    Map<String, String>? query,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final req = http.Request('PUT', uri(path, query))
        ..headers.addAll({
          'Content-Type': contentType,
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..bodyBytes = bytes;
      final streamed = await _client.send(req).timeout(defaultTimeout);
      return _handleResponse(
          await http.Response.fromStream(streamed).timeout(defaultTimeout),
          path);
    } catch (e) {
      throw connectionError(e);
    }
  }

  /// Streams a local file (or the byte range [start, start+length) of it) to
  /// the server with `PUT` (object upload or multipart part).
  Future<Map<String, dynamic>> uploadFile(
    String path,
    File file, {
    Map<String, String>? query,
    String contentType = 'application/octet-stream',
    ProgressCallback? onProgress,
    CancelToken? cancel,
    int start = 0,
    int? count,
  }) async {
    try {
      final length = count ?? (await file.length()) - start;
      final req = http.AbortableStreamedRequest('PUT', uri(path, query),
          abortTrigger: cancel?.whenCancelled)
        ..contentLength = length
        ..headers.addAll({
          'Content-Type': contentType,
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        });

      var sent = 0;
      onProgress?.call(0, length);
      final sending = _client.send(req);
      unawaited(() async {
        try {
          await req.sink.addStream(file.openRead(start, start + length).map((chunk) {
            sent += chunk.length;
            onProgress?.call(sent, length);
            return chunk;
          }));
        } catch (_) {
          // The send future reports the failure.
        } finally {
          await req.sink.close();
        }
      }());
      final response = await http.Response.fromStream(await sending);
      return _handleResponse(response, path);
    } catch (e) {
      throw connectionError(e);
    }
  }

  /// Streams a `GET` response body into [dest]. Writes to a temporary file
  /// first so a failed or cancelled download never leaves a partial file
  /// under the chosen name.
  Future<void> downloadToFile(
    String path,
    File dest, {
    Map<String, String>? query,
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) async {
    final tmp = File('${dest.path}.part');
    IOSink? sink;
    try {
      final req = http.AbortableRequest('GET', uri(path, query),
          abortTrigger: cancel?.whenCancelled)
        ..headers.addAll({
          if (token != null) 'Authorization': 'Bearer $token',
        });
      final resp = await _client.send(req).timeout(defaultTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _handleResponse(await http.Response.fromStream(resp), path);
        return;
      }
      final total = resp.contentLength;
      var received = 0;
      onProgress?.call(0, total);
      sink = tmp.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      sink = null;
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      throw connectionError(e);
    }
  }

  void dispose() => _client.close();
}
