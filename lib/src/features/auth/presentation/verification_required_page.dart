import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers.dart';
import '../../../shared/brand_logo.dart';

class VerificationRequiredPage extends ConsumerStatefulWidget {
  const VerificationRequiredPage({super.key});

  @override
  ConsumerState<VerificationRequiredPage> createState() =>
      _VerificationRequiredPageState();
}

class _VerificationRequiredPageState
    extends ConsumerState<VerificationRequiredPage> {
  var _busy = false;

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nuovo link di verifica inviato.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invio non riuscito. Riprova più tardi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).refreshCurrentUser();
      final user = ref.read(authRepositoryProvider).currentUser;
      if (!mounted) return;
      if (user?.emailVerified == true) {
        context.go(user!.isAdmin ? '/admin' : '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L’email non risulta ancora verificata.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).value?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandWordmark(),
                      const SizedBox(height: 28),
                      const Icon(Icons.mark_email_unread_outlined, size: 52),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Verifica la tua email',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Abbiamo inviato un link a $email.\n'
                        'Aprilo per attivare l’account, fino alla verifica non è possibile consultare '
                        'servizi, appuntamenti o effettuare prenotazioni.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _check,
                        child: const Text('Ho verificato, controlla'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _resend,
                        child: const Text('Invia di nuovo l’email'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await ref
                                    .read(authRepositoryProvider)
                                    .signOut();
                                if (context.mounted) context.go('/');
                              },
                        child: const Text('Esci'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
