import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/backend_api.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    BackendApi? backendApi,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _backendApi = backendApi ?? BackendApi(auth: auth);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final BackendApi _backendApi;

  Stream<User?> authStateChanges() => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(
      '${firstName.trim()} ${lastName.trim()}'.trim(),
    );
    await credential.user?.sendEmailVerification();
    final profile = <String, Object?>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone.trim(),
      'privacyAccepted': true,
    };
    if (_backendApi.enabled) {
      await _backendApi.post('/v1/profile', profile);
    } else {
      await _functions.httpsCallable('ensureUserProfile').call<void>(profile);
    }
    return credential;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<bool> isAdmin({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['admin'] == true;
  }

  Future<bool> isOwner({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['owner'] == true;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    if (_backendApi.enabled) {
      await _backendApi.delete('/v1/account');
    } else {
      await _functions.httpsCallable('requestAccountDeletion').call<void>();
    }
    await _auth.signOut();
  }
}
