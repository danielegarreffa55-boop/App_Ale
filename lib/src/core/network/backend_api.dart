import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class BackendApi {
  BackendApi({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  bool get enabled => AppConfig.backendApiUrl.trim().isNotEmpty;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'AUTH_REQUIRED',
      );
    }
    final token = await user.getIdToken();
    final base = AppConfig.backendApiUrl.trim().replaceFirst(RegExp(r'/$'), '');
    var uri = Uri.parse('$base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    try {
      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw StateError('Unsupported HTTP method: $method'),
      }.timeout(const Duration(seconds: 25));
      final decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      final envelope = decoded is Map ? decoded['error'] : null;
      final error = envelope is Map ? envelope : const <String, dynamic>{};
      throw FirebaseFunctionsException(
        code: '${error['code'] ?? 'internal'}',
        message: '${error['message'] ?? 'INTERNAL_ERROR'}',
      );
    } on FirebaseFunctionsException {
      rethrow;
    } on TimeoutException {
      throw FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'BACKEND_TIMEOUT',
      );
    } catch (_) {
      throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'BACKEND_UNREACHABLE',
      );
    }
  }
}
