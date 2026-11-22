import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salon_booking/src/core/network/backend_api.dart';
import 'package:salon_booking/src/core/network/session_store.dart';
import 'package:salon_booking/src/core/bootstrap/startup_sequence.dart';
import 'package:salon_booking/src/features/auth/data/auth_repository.dart';

class _ConfiguredBackendApi extends BackendApi {
  _ConfiguredBackendApi({
    required SessionStore sessionStore,
    required http.Client client,
  }) : super(
         sessionStore: sessionStore,
         client: client,
         baseUrl: 'https://example.test',
       );
}

http.Response _response(int status, Map<String, Object?> body) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> get _user => {
  'id': 'user-1',
  'email': 'cliente@example.it',
  'firstName': 'Mario',
  'lastName': 'Rossi',
  'phone': '3331234567',
  'role': 'client',
  'emailVerified': true,
  'emailVerificationRequired': true,
};

Future<SessionStore> _storedSession() async {
  FlutterSecureStorage.setMockInitialValues({
    'agh_access_token': 'access-old',
    'agh_refresh_token': 'refresh-old',
  });
  final store = SessionStore();
  await store.initialize();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('access scaduto rinnova i token e poi ripristina il profilo', () async {
    final store = await _storedSession();
    final calls = <String>[];
    var profileCalls = 0;
    final api = _ConfiguredBackendApi(
      sessionStore: store,
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/v1/auth/me') {
          profileCalls++;
          if (profileCalls == 1) {
            expect(request.headers['Authorization'], 'Bearer access-old');
            return _response(401, {});
          }
          expect(request.headers['Authorization'], 'Bearer access-new');
          return _response(200, {'user': _user});
        }
        expect(request.url.path, '/v1/auth/refresh');
        expect(request.headers['Authorization'], isNull);
        return _response(200, {
          'accessToken': 'access-new',
          'refreshToken': 'refresh-new',
        });
      }),
    );
    final auth = AuthRepository(backendApi: api, sessionStore: store);

    await auth.initialize();

    expect(calls, [
      'GET /v1/auth/me',
      'POST /v1/auth/refresh',
      'GET /v1/auth/me',
    ]);
    expect(auth.currentUser?.uid, 'user-1');
    expect(store.accessToken, 'access-new');
    expect(store.refreshToken, 'refresh-new');
  });

  test('refresh temporaneamente irraggiungibile conserva i token', () async {
    final store = await _storedSession();
    final api = _ConfiguredBackendApi(
      sessionStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/v1/auth/me') return _response(401, {});
        return _response(503, {});
      }),
    );
    final auth = AuthRepository(backendApi: api, sessionStore: store);

    await expectLater(auth.initialize(), throwsA(isA<ApiException>()));

    expect(store.accessToken, 'access-old');
    expect(store.refreshToken, 'refresh-old');
    expect(auth.currentUser, isNull);
  });

  test('refresh rifiutato definitivamente cancella la sessione', () async {
    final store = await _storedSession();
    final api = _ConfiguredBackendApi(
      sessionStore: store,
      client: MockClient((request) async => _response(401, {})),
    );
    final auth = AuthRepository(backendApi: api, sessionStore: store);

    await auth.initialize();

    expect(store.hasSession, isFalse);
    expect(auth.currentUser, isNull);
  });

  test(
    'timeout durante refresh e Riprova condividono un solo rinnovo',
    () async {
      final store = await _storedSession();
      final refreshResponse = Completer<http.Response>();
      var profileCalls = 0;
      var refreshCalls = 0;
      final api = _ConfiguredBackendApi(
        sessionStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/auth/me') {
            profileCalls++;
            if (profileCalls == 1) return _response(401, {});
            return _response(200, {'user': _user});
          }
          refreshCalls++;
          return refreshResponse.future;
        }),
      );
      final auth = AuthRepository(backendApi: api, sessionStore: store);
      final sequence = StartupSequence(auth.initialize);

      final expiredAttempt = sequence.run(Future.value(true));
      while (refreshCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      sequence.expireCurrentAttempt();
      final retryAttempt = sequence.run(Future.value(true));
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 1);
      expect(store.refreshToken, 'refresh-old');
      refreshResponse.complete(
        _response(200, {
          'accessToken': 'access-new',
          'refreshToken': 'refresh-new',
        }),
      );

      expect(await expiredAttempt, isFalse);
      expect(await retryAttempt, isTrue);
      expect(refreshCalls, 1);
      expect(store.accessToken, 'access-new');
      expect(store.refreshToken, 'refresh-new');
      expect(auth.currentUser?.uid, 'user-1');
    },
  );
}
