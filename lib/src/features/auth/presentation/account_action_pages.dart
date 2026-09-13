import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/backend_api.dart';
import '../../../shared/brand_logo.dart';
import '../data/auth_repository.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({required this.token, super.key});

  final String token;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  var _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    if (widget.token.isEmpty) {
      setState(() => _error = 'Link di verifica non valido.');
      return;
    }
    try {
      await AuthRepository.instance.verifyEmail(widget.token);
      if (mounted) setState(() => _done = true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message == 'INVALID_OR_EXPIRED_TOKEN'
              ? 'Il link è scaduto o è già stato utilizzato.'
              : 'Verifica non riuscita. Riprova tra poco.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AccountActionScaffold(
    title: _done ? 'Email verificata' : 'Verifica email',
    body: _error != null
        ? Text(_error!, textAlign: TextAlign.center)
        : _done
        ? const Text(
            'Il tuo account è attivo. Ora puoi inviare richieste di prenotazione.',
            textAlign: TextAlign.center,
          )
        : const CircularProgressIndicator(),
    actionLabel: _done || _error != null ? 'Continua' : null,
    onAction: () => context.go('/'),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({required this.token, super.key});

  final String token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _busy = false;
  var _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.token.isEmpty) {
      setState(() => _error = 'Link di reimpostazione non valido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthRepository.instance.resetPassword(
        token: widget.token,
        newPassword: _password.text,
      );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message == 'INVALID_OR_EXPIRED_TOKEN'
              ? 'Il link è scaduto o è già stato utilizzato.'
              : 'Reimpostazione non riuscita. Riprova tra poco.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _AccountActionScaffold(
        title: 'Password aggiornata',
        body: const Text(
          'La password è stata cambiata. Accedi di nuovo su tutti i dispositivi.',
          textAlign: TextAlign.center,
        ),
        actionLabel: 'Accedi',
        onAction: () => context.go('/'),
      );
    }
    return _AccountActionScaffold(
      title: 'Nuova password',
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Nuova password'),
              validator: (value) => value == null || value.length < 8
                  ? 'Usa almeno 8 caratteri'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Ripeti password'),
              validator: (value) =>
                  value != _password.text ? 'Le password non coincidono' : null,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actionLabel: _busy ? null : 'Salva password',
      onAction: _submit,
      loading: _busy,
    );
  }
}

class _AccountActionScaffold extends StatelessWidget {
  const _AccountActionScaffold({
    required this.title,
    required this.body,
    required this.onAction,
    this.actionLabel,
    this.loading = false,
  });

  final String title;
  final Widget body;
  final String? actionLabel;
  final VoidCallback onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const BrandWordmark(),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        Center(child: body),
                        if (actionLabel != null || loading) ...[
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: loading ? null : onAction,
                            child: loading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(actionLabel!),
                          ),
                        ],
                      ],
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
