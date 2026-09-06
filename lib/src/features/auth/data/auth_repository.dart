import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/backend_api.dart';
import '../../../core/network/session_store.dart';
import '../../../core/notifications/notification_service.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.emailVerified,
  });

  factory AuthUser.fromJson(Map<String, dynamic> data) => AuthUser(
    uid: data['id']! as String,
    email: data['email'] as String? ?? '',
    firstName: data['firstName'] as String? ?? '',
    lastName: data['lastName'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    role: data['role'] as String? ?? 'client',
    emailVerified: data['emailVerified'] as bool? ?? false,
  );

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final bool emailVerified;

  String get displayName => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'manager' || role == 'owner';
  bool get isOwner => role == 'owner';
}

class AuthRepository extends ChangeNotifier {
  AuthRepository({
    BackendApi? backendApi,
    SessionStore? sessionStore,
    NotificationService? notifications,
  }) : _api = backendApi ?? BackendApi.instance,
       _sessionStore = sessionStore ?? SessionStore.instance,
       _notifications = notifications ?? NotificationService() {
    _api.onSessionExpired = _handleSessionExpired;
  }

  static final instance = AuthRepository();

  final BackendApi _api;
  final SessionStore _sessionStore;
  final NotificationService _notifications;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;

  Stream<AuthUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _changes.stream;
  }

  Future<void> initialize() async {
    await _sessionStore.initialize();
    if (!AppConfig.isBackendConfigured || !_sessionStore.hasSession) return;
    try {
      final response = await _api.get('/v1/auth/me');
      await _setUser(
        AuthUser.fromJson(Map<String, dynamic>.from(response['user']! as Map)),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        await _sessionStore.clear();
      }
      await _setUser(null);
    }
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _api.postPublic('/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return _acceptSession(response);
  }

  Future<AuthUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _api.postPublic('/v1/auth/register', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'privacyAccepted': true,
    });
    return _acceptSession(response);
  }

  Future<AuthUser> _acceptSession(Map<String, dynamic> response) async {
    await _sessionStore.save(
      accessToken: response['accessToken']! as String,
      refreshToken: response['refreshToken']! as String,
    );
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(response['user']! as Map),
    );
    await _setUser(user);
    return user;
  }

  Future<void> sendPasswordReset(String email) async {
    await _api.postPublic('/v1/auth/forgot-password', {'email': email.trim()});
  }

  Future<void> verifyEmail(String token) async {
    await _api.postPublic('/v1/auth/verify-email', {'token': token});
    if (_currentUser != null) await refreshCurrentUser();
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.postPublic('/v1/auth/reset-password', {
      'token': token,
      'newPassword': newPassword,
    });
    await _sessionStore.clear();
    await _setUser(null);
  }

  Future<void> resendEmailVerification() async {
    await _api.post('/v1/auth/resend-verification');
  }

  Future<bool> isAdmin({bool forceRefresh = false}) async {
    if (forceRefresh && _currentUser != null) await refreshCurrentUser();
    return _currentUser?.isAdmin ?? false;
  }

  Future<bool> isOwner({bool forceRefresh = false}) async {
    if (forceRefresh && _currentUser != null) await refreshCurrentUser();
    return _currentUser?.isOwner ?? false;
  }

  Future<void> refreshCurrentUser() async {
    final response = await _api.get('/v1/auth/me');
    await _setUser(
      AuthUser.fromJson(Map<String, dynamic>.from(response['user']! as Map)),
    );
  }

  Future<void> signOut() async {
    final refreshToken = _sessionStore.refreshToken;
    if (refreshToken != null) {
      try {
        await _api.postPublic('/v1/auth/logout', {
          'refreshToken': refreshToken,
        });
      } catch (_) {
        // Local cleanup must still happen if the server cannot be reached.
      }
    }
    await _notifications.clearIdentity();
    await _sessionStore.clear();
    await _setUser(null);
  }

  Future<void> deleteAccount() async {
    await _api.delete('/v1/account');
    await _notifications.clearIdentity();
    await _sessionStore.clear();
    await _setUser(null);
  }

  Future<void> _setUser(AuthUser? user) async {
    _currentUser = user;
    if (user != null) await _notifications.identify(user.uid);
    _changes.add(user);
    notifyListeners();
  }

  void _handleSessionExpired() {
    _currentUser = null;
    unawaited(_notifications.clearIdentity());
    _changes.add(null);
    notifyListeners();
  }
}
