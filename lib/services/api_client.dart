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

  ApiException(this.statusCode, this.message, {this.data});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isTooManyRequests => statusCode == 429;

  /// True when the request never reached the server (DNS, refused, TLS,
  /// timeout) as opposed to an HTTP error response.
  bool get isConnectionError => statusCode == 0;

  @override
  String toString() => message;
}

class ApiClient {
  String baseUrl;
  String? token;
  final http.Client _client = http.Client();

  /// Default per-request timeout. Long-running operations (storage move,
  /// prefix delete, forced bucket delete) pass [longTimeout] instead.
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration longTimeout = Duration(minutes: 5);

  // Called when a 401 is received (token expired / revoked). Not invoked for
  // the login endpoint itself, where 401 simply means wrong credentials.
  void Function()? onUnauthorized;

  ApiClient({this.baseUrl = '', this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl/admin$path');

  Future<Map<String, dynamic>> _handleResponse(
      http.Response response, String path) async {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Not JSON (proxy error page, plain-text 413 from a body limiter, …).
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? <String, dynamic>{};
    }

    if (response.statusCode == 401 && path != '/login') {
      onUnauthorized?.call();
    }

    throw ApiException(
      response.statusCode,
      _errorMessage(response.statusCode, body),
      data: body,
    );
  }

  /// Prefers the server's own `error` text; falls back to a clear message
  /// for status codes the server may return without a JSON body.
  static String _errorMessage(int status, Map<String, dynamic>? body) {
    final serverMsg = body?['error'];
    switch (status) {
      case 401:
        return serverMsg is String && serverMsg != 'unauthorized'
            ? serverMsg
            : 'Session expired or invalid credentials';
      case 413:
        return 'Request too large (server limit exceeded)';
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
  static ApiException _connectionError(Object e) {
    if (e is HandshakeException) {
      return ApiException(
          0,
          'TLS handshake failed: the server certificate is not trusted '
          '(self-signed?). Install the CA certificate on this machine or use '
          'a certificate from a trusted authority.');
    }
    if (e is TimeoutException) {
      return ApiException(0, 'Connection timed out');
    }
    if (e is SocketException) {
      final os = e.osError?.message;
      return ApiException(0,
          'Cannot reach server: ${os != null && os.isNotEmpty ? os : e.message}');
    }
    if (e is http.ClientException) {
      return ApiException(0, 'Connection failed: ${e.message}');
    }
    return ApiException(0, 'Connection failed: $e');
  }

  Future<Map<String, dynamic>> get(String path, {Duration? timeout}) async {
    try {
      final response = await _client
          .get(_uri(path), headers: _headers)
          .timeout(timeout ?? defaultTimeout);
      return _handleResponse(response, path);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectionError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body, Duration? timeout]) async {
    try {
      final response = await _client
          .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(timeout ?? defaultTimeout);
      return _handleResponse(response, path);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectionError(e);
    }
  }

  Future<Map<String, dynamic>> put(String path,
      [Map<String, dynamic>? body, Duration? timeout]) async {
    try {
      final response = await _client
          .put(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(timeout ?? defaultTimeout);
      return _handleResponse(response, path);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectionError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Duration? timeout}) async {
    try {
      final response = await _client
          .delete(_uri(path), headers: _headers)
          .timeout(timeout ?? defaultTimeout);
      return _handleResponse(response, path);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectionError(e);
    }
  }

  void dispose() {
    _client.close();
  }
}
