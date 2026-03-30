import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  String baseUrl;
  String? token;
  final http.Client _client = http.Client();

  // Called when a 401 is received (token expired)
  void Function()? onUnauthorized;

  ApiClient({this.baseUrl = '', this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl/admin$path');

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    throw ApiException(
      response.statusCode,
      body['error'] as String? ?? 'Unknown error',
    );
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _client
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    try {
      final response = await _client
          .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> put(String path,
      [Map<String, dynamic>? body]) async {
    try {
      final response = await _client
          .put(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _client
          .delete(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Connection failed: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
