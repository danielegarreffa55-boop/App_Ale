import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../appointments/domain/appointment_models.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _startupDialogsHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupDialogs());
  }

  Future<void> _showStartupDialogs() async {
    if (_startupDialogsHandled || !mounted) return;
    _startupDialogsHandled = true;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final notifications = ref.read(notificationServiceProvider);
    final alreadyAsked = await notifications.firstPromptWasShown(user.uid);
    final enabled = await notifications.permissionEnabled();
    if (!alreadyAsked && enabled != true && mounted) {
      final activate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined),
          title: const Text('Vuoi attivare le notifiche?'),
          content: const Text(
            'Riceverai conferme, controproposte e promemoria degli appuntamenti. '
            'Potrai abilitarle o disabilitarle in qualsiasi momento dalla sezione Profilo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non ora'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Attiva'),
            ),
          ],
        ),
      );
      await notifications.markFirstPromptShown(user.uid);
      if (activate == true) {
        await notifications.requestAndRegister(userId: user.uid);
      }
    } else if (!alreadyAsked) {
      await notifications.markFirstPromptShown(user.uid);
    }

    if (!mounted) return;
    try {
      final config = await ref.read(studioConfigProvider.future);
      final raw = config['announcement'];
      if (raw is! Map) return;
      final announcement = Map<String, dynamic>.from(raw);
      final title = (announcement['title'] as String? ?? '').trim();
      final message = (announcement['message'] as String? ?? '').trim();
      if (announcement['active'] != true || title.isEmpty || message.isEmpty) {
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.campaign_outlined),
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    } catch (_) {
      // La home rimane utilizzabile anche se l'avviso non è disponibile.
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(clientAppointmentsProvider);
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName;
    final firstName = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').first
        : null;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(clientAppointmentsProvider),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciao${firstName == null ? '' : ', $firstName'}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Benvenuto da ${AppConfig.studioName}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Il tuo prossimo appuntamento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/book'),
                      icon: const Icon(Icons.add),
                      label: const Text('Prenota'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AsyncValueView<List<Appointment>>(
                  value: appointments,
                  onRetry: () => ref.invalidate(clientAppointmentsProvider),
                  data: (items) {
                    final now = DateTime.now().toUtc();
                    final upcoming =
                        items
                            .where(
                              (item) =>
                                  item.effectiveEndAt.isAfter(now) &&
                                  item.status != AppointmentStatus.rejected &&
                                  item.status != AppointmentStatus.cancelled &&
                                  item.status !=
                                      AppointmentStatus.counterRejected,
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.effectiveStartAt.compareTo(
                              b.effectiveStartAt,
                            ),
                          );
                    if (upcoming.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              const Text('Nessun appuntamento in programma.'),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => context.go('/book'),
                                child: const Text('Scegli un servizio'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return AppointmentCard(appointment: upcoming.first);
                  },
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(AppConfig.address),
                    subtitle: Text(AppConfig.supportPhone),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
