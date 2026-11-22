import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class BackendReadiness {
  BackendReadiness({http.Client? client, String? backendUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _backendUrl = backendUrl ?? AppConfig.backendApiUrl;

  final http.Client _client;
  final bool _ownsClient;
  final String _backendUrl;

  Future<bool> check() async {
    final base = _backendUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) return true;

    try {
      final response = await _client
          .get(
            Uri.parse('$base/readyz'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Backend not ready (${response.statusCode})');
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['status'] != 'ready') {
        throw const FormatException('Unexpected /readyz response');
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_ownsClient) _client.close();
    }
  }
}
