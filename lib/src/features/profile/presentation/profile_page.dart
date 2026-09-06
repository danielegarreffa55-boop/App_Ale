import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  var _notificationBusy = false;

  Future<void> _enableNotifications() async {
    setState(() => _notificationBusy = true);
    try {
      final service = ref.read(notificationServiceProvider);
      final enabled = await service.requestAndRegister();
      await service.listenForTokenRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Notifiche abilitate su questo dispositivo.'
                  : 'Permesso notifiche non concesso.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configurazione non riuscita: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Il profilo verrà eliminato e i dati storici saranno anonimizzati. '
          'Questa operazione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantieni account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eliminazione non riuscita: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profilo',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(user?.displayName ?? 'Cliente'),
                        subtitle: Text(user?.email ?? ''),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text('Notifiche appuntamenti'),
                        subtitle: const Text(
                          'Conferme, controproposte e promemoria del giorno prima.',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: _notificationBusy
                              ? null
                              : _enableNotifications,
                          child: Text(
                            _notificationBusy ? 'Attendi…' : 'Abilita',
                          ),
                        ),
                      ),
                      if (user != null && !user.emailVerified) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.mark_email_unread_outlined),
                          title: const Text('Email non verificata'),
                          trailing: TextButton(
                            onPressed: () => ref
                                .read(authRepositoryProvider)
                                .resendEmailVerification(),
                            child: const Text('Reinvia'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('Assistenza'),
                        subtitle: Text(
                          [AppConfig.supportEmail, AppConfig.supportPhone]
                              .where((value) => value.trim().isNotEmpty)
                              .join('\n'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text(
                          'Testo da pubblicare prima della release',
                        ),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: AppConfig.appName,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/');
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Esci'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
