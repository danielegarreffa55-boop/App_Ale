import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BackendApi {
  BackendApi({SessionStore? sessionStore, http.Client? client})
    : _sessionStore = sessionStore ?? SessionStore.instance,
      _client = client ?? http.Client();

  static final instance = BackendApi();

  final SessionStore _sessionStore;
  final http.Client _client;
  Future<bool>? _refreshInFlight;
  void Function()? onSessionExpired;

  bool get enabled => AppConfig.isBackendConfigured;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('POST', path, body: body, authenticated: true);

  Future<Map<String, dynamic>> postPublic(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('POST', path, body: body, authenticated: false);

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('PUT', path, body: body, authenticated: true);

  Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('PATCH', path, body: body, authenticated: true);

  Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path, authenticated: true);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    required bool authenticated,
    bool retryAfterRefresh = true,
  }) async {
    if (!enabled) {
      throw const ApiException(
        code: 'backend-not-configured',
        message: 'BACKEND_NOT_CONFIGURED',
      );
    }
    await _sessionStore.initialize();
    final response = await _perform(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
    );
    if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
      if (await _refreshTokens()) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          authenticated: true,
          retryAfterRefresh: false,
        );
      }
    }
    return _decode(response);
  }

  Future<http.Response> _perform(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    required bool authenticated,
  }) async {
    final base = AppConfig.backendApiUrl.trim().replaceFirst(RegExp(r'/$'), '');
    var uri = Uri.parse('$base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final accessToken = _sessionStore.accessToken;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && accessToken != null)
        'Authorization': 'Bearer $accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);
    try {
      return await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw StateError('Unsupported HTTP method: $method'),
      }.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException(
        code: 'deadline-exceeded',
        message: 'BACKEND_TIMEOUT',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        code: 'unavailable',
        message: 'BACKEND_UNREACHABLE',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(decoded! as Map);
    }
    final envelope = decoded is Map ? decoded['error'] : null;
    final error = envelope is Map ? envelope : const <String, dynamic>{};
    throw ApiException(
      code: '${error['code'] ?? 'internal'}',
      message: '${error['message'] ?? 'INTERNAL_ERROR'}',
      statusCode: response.statusCode,
    );
  }

  Future<bool> _refreshTokens() async {
    if (_refreshInFlight case final pending?) return pending;
    final future = _doRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _sessionStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _perform(
        'POST',
        '/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
        authenticated: false,
      );
      final data = _decode(response);
      await _sessionStore.save(
        accessToken: data['accessToken']! as String,
        refreshToken: data['refreshToken']! as String,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        await _sessionStore.clear();
        onSessionExpired?.call();
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
