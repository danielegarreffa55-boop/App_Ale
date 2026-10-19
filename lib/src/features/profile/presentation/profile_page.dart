import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../providers.dart';
import '../../../shared/dialog_action_row.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  var _notificationBusy = false;
  bool? _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _refreshNotificationState();
  }

  Future<void> _refreshNotificationState() async {
    final enabled = await ref
        .read(notificationServiceProvider)
        .permissionEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _toggleNotifications() async {
    setState(() => _notificationBusy = true);
    try {
      final service = ref.read(notificationServiceProvider);
      final enabled = _notificationsEnabled == true
          ? false
          : await service.requestAndRegister(
              userId: ref.read(authRepositoryProvider).currentUser?.uid,
            );
      if (_notificationsEnabled == true) await service.disable();
      if (mounted) {
        setState(() => _notificationsEnabled = enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Notifiche abilitate su questo dispositivo.'
                  : 'Notifiche disabilitate su questo dispositivo.',
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
          DialogActionRow(
            cancelLabel: 'Mantieni account',
            confirmLabel: 'Elimina definitivamente',
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
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
                              : _toggleNotifications,
                          child: Text(
                            _notificationBusy
                                ? 'Attendi…'
                                : _notificationsEnabled == true
                                ? 'Disabilita'
                                : 'Abilita',
                          ),
                        ),
                      ),
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
                          'Consulta finalità, fornitori, conservazione e diritti.',
                        ),
                        onTap: () => context.push('/privacy'),
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
