import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Client HTTP REST API untuk komunikasi aplikasi Flutter dengan Backend PostgreSQL Estopa Kos.
class EstopaApiClient {
  String baseUrl;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  EstopaApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static const List<String> _fallbackUrls = [
    'http://127.0.0.1:8080/api',
    'http://192.168.1.32:8080/api',
    'http://192.168.1.66:8080/api',
    'http://10.0.2.2:8080/api',
    'http://localhost:8080/api',
  ];

  Future<Map<String, dynamic>> getJson(String path) async {
    return _request('GET', path);
  }

  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    return _request('POST', path, payload);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _request('PUT', path, payload);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    return _request('PATCH', path, payload);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final candidates = <String>[
      baseUrl,
      ..._fallbackUrls.where((u) => u != baseUrl),
    ];

    Object? lastError;
    for (final candidateBase in candidates) {
      try {
        final result = await _sendSingle(candidateBase, method, path, payload);
        baseUrl = candidateBase;
        return result;
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      }
    }
    throw lastError ??
        const SocketException('Tidak dapat terhubung ke server backend.');
  }

  Future<Map<String, dynamic>> _sendSingle(
    String targetBaseUrl,
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final uri = Uri.parse('$targetBaseUrl$path');
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (payload != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
    }
    final response = await request.close().timeout(const Duration(seconds: 3));
    final body = await response.transform(utf8.decoder).join();
    final decoded =
        body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode >= 400) {
      final msg = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'HTTP ${response.statusCode}';
      throw HttpException(msg, uri: uri);
    }
    return decoded as Map<String, dynamic>;
  }
}
