import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../providers.dart';
import '../../../shared/brand_logo.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.checkExistingSession = true, super.key});

  final bool checkExistingSession;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  var _register = false;
  var _privacy = false;
  var _busy = false;
  var _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.checkExistingSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (ref.read(authRepositoryProvider).currentUser != null) {
          await _finishAuthentication();
        }
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obbligatorio' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_register && !_privacy) {
      setState(
        () => _error = 'Accetta l\u2019informativa privacy per continuare.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_register) {
        await auth.register(
          firstName: _firstName.text,
          lastName: _lastName.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      await _finishAuthentication();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyAuthError(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Accesso non riuscito. Riprova tra poco.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishAuthentication() async {
    final admin = await ref
        .read(authRepositoryProvider)
        .isAdmin(forceRefresh: true);
    if (!mounted) return;
    ref.invalidate(authStateProvider);
    context.go(admin ? '/admin' : '/home');
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reimposta password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: AppStrings.email),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Invia link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email di reimpostazione inviata.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyAuthError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, keyboardVisible ? 8 : 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  if (keyboardVisible) ...[
                    const BrandWordmark(),
                    const SizedBox(height: 12),
                  ] else ...[
                    const BrandLogo(),
                    const SizedBox(height: 16),
                    Text(
                      _register ? 'Crea il tuo profilo cliente' : 'Bentornato. Il tuo prossimo appuntamento ti aspetta.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                  ],
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(keyboardVisible ? 18 : 24),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _register
                                    ? AppStrings.signUp
                                    : AppStrings.signIn,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 20),
                              if (_register) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: const Key('firstNameField'),
                                        controller: _firstName,
                                        validator: _required,
                                        autofillHints: const [
                                          AutofillHints.givenName,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: AppStrings.firstName,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastName,
                                        validator: _required,
                                        autofillHints: const [
                                          AutofillHints.familyName,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: AppStrings.lastName,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  validator: _required,
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.phone,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                key: const Key('emailField'),
                                controller: _email,
                                validator: (value) {
                                  if (_required(value) case final error?) {
                                    return error;
                                  }
                                  return value!.contains('@')
                                      ? null
                                      : 'Inserisci un indirizzo email valido';
                                },
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: AppStrings.email,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('passwordField'),
                                controller: _password,
                                validator: (value) {
                                  if (_required(value) case final error?) {
                                    return error;
                                  }
                                  if (_register && value!.length < 8) {
                                    return 'Usa almeno 8 caratteri';
                                  }
                                  return null;
                                },
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_busy) _submit();
                                },
                                autofillHints: [
                                  _register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: AppStrings.password,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (_register) ...[
                                const SizedBox(height: 12),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _privacy,
                                  onChanged: (value) =>
                                      setState(() => _privacy = value ?? false),
                                  title: const Text(AppStrings.privacyConsent),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ],
                              if (_error case final error?) ...[
                                const SizedBox(height: 8),
                                Text(
                                  error,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                key: const Key('authSubmitButton'),
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _register
                                            ? AppStrings.signUp
                                            : AppStrings.signIn,
                                      ),
                              ),
                              if (!_register)
                                TextButton(
                                  onPressed: _busy ? null : _forgotPassword,
                                  child: const Text(AppStrings.forgotPassword),
                                ),
                              TextButton(
                                key: const Key('toggleAuthModeButton'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _register = !_register;
                                        _error = null;
                                      }),
                                child: Text(
                                  _register
                                      ? 'Hai già un account? Accedi'
                                      : 'Non hai un account? Registrati',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthError(FirebaseAuthException error) => switch (error.code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' => 'Email o password non corretti.',
  'email-already-in-use' => 'Esiste già un account con questa email.',
  'weak-password' => 'La password scelta è troppo debole.',
  'too-many-requests' => 'Troppi tentativi. Attendi qualche minuto.',
  'network-request-failed' => 'Connessione non disponibile.',
  _ => error.message ?? 'Autenticazione non riuscita.',
};
