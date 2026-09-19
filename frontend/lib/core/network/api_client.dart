import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin HTTP layer. Every response leaves here as either a decoded `data` map or
/// an [ApiException] — callers never see a status code or a socket error.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
    return _send(() => _client.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _client.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _client.put(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    }

    Map<String, dynamic> decoded;
    try {
      final dynamic parsed = jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } on FormatException {
      // A gateway or proxy answered with something that is not our envelope.
      throw ApiException(
        code: response.statusCode >= 500 ? 'SERVER_ERROR' : 'BAD_RESPONSE',
        message: 'We could not reach TalentRadar just now. Please try again.',
        status: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
      final dynamic data = decoded['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }

    throw _toException(decoded, response.statusCode);
  }

  ApiException _toException(Map<String, dynamic> body, int status) {
    final dynamic error = body['error'];
    if (error is! Map<String, dynamic>) {
      return ApiException(
        code: status >= 500 ? 'SERVER_ERROR' : 'BAD_REQUEST',
        message: 'Something went wrong. Please try again.',
        status: status,
      );
    }

    final fieldErrors = <String, String>{};
    final dynamic details = error['details'];
    if (details is List) {
      for (final dynamic entry in details) {
        if (entry is Map && entry['field'] != null && entry['message'] != null) {
          // Keep the first message per field — that is the one worth showing.
          fieldErrors.putIfAbsent('${entry['field']}', () => '${entry['message']}');
        }
      }
    }

    return ApiException(
      code: '${error['code'] ?? 'SERVER_ERROR'}',
      message: '${error['message'] ?? 'Something went wrong. Please try again.'}',
      status: status,
      fieldErrors: fieldErrors,
      details: details is Map<String, dynamic> ? details : null,
    );
  }

  void close() => _client.close();
}
