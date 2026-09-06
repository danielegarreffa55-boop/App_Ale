import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final instance = SessionStore();

  static const _accessKey = 'agh_access_token';
  static const _refreshKey = 'agh_refresh_token';

  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken?.isNotEmpty ?? false;

  Future<void> initialize() async {
    if (_loaded) return;
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }
}
