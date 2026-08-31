import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/date_time_x.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../appointments/domain/appointment_models.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  var _selected = 0;

  static const _labels = [
    'Dashboard',
    'Richieste',
    'Agenda',
    'Clienti',
    'Servizi',
    'Orari',
    'Impostazioni',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.mark_email_unread_outlined,
    Icons.calendar_month_outlined,
    Icons.people_outline,
    Icons.content_cut_outlined,
    Icons.schedule_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _AccessDenied(error: error),
      data: (allowed) {
        if (!allowed) return const _AccessDenied();
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 980;
        final content = switch (_selected) {
          0 => const _DashboardSection(),
          1 => const _RequestsSection(),
          2 => const _AgendaSection(),
          3 => const _ClientsSection(),
          4 => const _ServicesSection(),
          5 => const _HoursSection(),
          _ => const _SettingsSection(),
        };
        return Scaffold(
          appBar: AppBar(
            title: Text('${AppConfig.studioName} · Admin'),
            actions: [
              IconButton(
                tooltip: 'Esci',
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : NavigationDrawer(
                  selectedIndex: _selected,
                  onDestinationSelected: (index) {
                    setState(() => _selected = index);
                    Navigator.pop(context);
                  },
                  children: [
                    const SizedBox(height: 16),
                    for (var index = 0; index < _labels.length; index++)
                      NavigationDrawerDestination(
                        icon: Icon(_icons[index]),
                        label: Text(_labels[index]),
                      ),
                  ],
                ),
          body: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: _selected,
                  extended: width >= 1220,
                  labelType: width >= 1220
                      ? NavigationRailLabelType.none
                      : null,
                  onDestinationSelected: (index) =>
                      setState(() => _selected = index),
                  destinations: [
                    for (var index = 0; index < _labels.length; index++)
                      NavigationRailDestination(
                        icon: Icon(_icons[index]),
                        label: Text(_labels[index]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text('Accesso amministratore richiesto.'),
                  if (error != null) Text('$error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Torna all\u2019app'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.displaySmall),
              if (subtitle case final subtitle?) Text(subtitle),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _DashboardSection extends ConsumerWidget {
  const _DashboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    final clients = ref.watch(clientsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Dashboard',
          subtitle: 'Situazione operativa in tempo reale',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            onRetry: () => ref.invalidate(adminAppointmentsProvider),
            data: (items) {
              final localNow = DateTime.now().inStudioTimezone;
              bool sameDay(DateTime date, int offset) {
                final local = date.inStudioTimezone;
                final target = localNow.add(Duration(days: offset));
                return local.year == target.year &&
                    local.month == target.month &&
                    local.day == target.day;
              }

              final metrics = [
                (
                  'Nuove richieste',
                  items
                      .where((a) => a.status == AppointmentStatus.pendingAdmin)
                      .length,
                  Icons.mark_email_unread_outlined,
                ),
                (
                  'Controproposte',
                  items
                      .where(
                        (a) => a.status == AppointmentStatus.counterProposed,
                      )
                      .length,
                  Icons.swap_horiz_rounded,
                ),
                (
                  'Oggi',
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            sameDay(a.effectiveStartAt, 0),
                      )
                      .length,
                  Icons.today_outlined,
                ),
                (
                  'Domani',
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            sameDay(a.effectiveStartAt, 1),
                      )
                      .length,
                  Icons.event_outlined,
                ),
                ('Clienti', clients.value?.length ?? 0, Icons.people_outline),
              ];
              final upcoming =
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            a.effectiveStartAt.isAfter(DateTime.now().toUtc()),
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.effectiveStartAt.compareTo(b.effectiveStartAt),
                    );
              return ListView(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: metrics
                        .map(
                          (metric) => SizedBox(
                            width: 210,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(metric.$3, size: 30),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${metric.$2}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium,
                                        ),
                                        Text(metric.$1),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Prossimi appuntamenti',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    const Text('Nessun appuntamento confermato.')
                  else
                    ...upcoming
                        .take(8)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppointmentCard(appointment: item),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestsSection extends ConsumerWidget {
  const _RequestsSection();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(adminAppointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Richiesta aggiornata.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    Appointment item,
  ) async {
    final reason = await _textDialog(
      context,
      title: 'Rifiuta richiesta',
      label: 'Motivo facoltativo',
    );
    if (reason == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(appointmentRepositoryProvider)
          .adminReject(item.id, reason: reason.isEmpty ? null : reason),
    );
  }

  Future<void> _counter(
    BuildContext context,
    WidgetRef ref,
    Appointment item,
  ) async {
    final date = await _pickDateTime(context, initial: item.requestedStartAt);
    if (date == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(appointmentRepositoryProvider)
          .adminCounterPropose(item.id, date),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Richieste',
          subtitle: 'Accetta, rifiuta o proponi direttamente un altro orario',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            onRetry: () => ref.invalidate(adminAppointmentsProvider),
            data: (items) {
              final requests = items
                  .where(
                    (item) =>
                        item.status == AppointmentStatus.pendingAdmin ||
                        item.status == AppointmentStatus.counterProposed ||
                        item.status == AppointmentStatus.counterRejected,
                  )
                  .toList();
              if (requests.isEmpty) {
                return const Center(
                  child: Text('Nessuna richiesta da gestire.'),
                );
              }
              return ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clientName ?? 'Cliente ${item.clientId}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (item.clientPhone case final phone?) Text(phone),
                          const SizedBox(height: 6),
                          Text(
                            '${item.serviceName} · ${item.requestedStartAt.italianDateTime}',
                          ),
                          const SizedBox(height: 12),
                          AppointmentStatusChip(status: item.status),
                          const SizedBox(height: 16),
                          AdminRequestActions(
                            acceptEnabled:
                                item.status == AppointmentStatus.pendingAdmin,
                            onAccept: () => _run(
                              context,
                              ref,
                              () => ref
                                  .read(appointmentRepositoryProvider)
                                  .adminAccept(item.id),
                            ),
                            onReject: () => _reject(context, ref, item),
                            onCounterPropose: () =>
                                _counter(context, ref, item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgendaSection extends ConsumerWidget {
  const _AgendaSection();

  Future<void> _manualAppointment(BuildContext context, WidgetRef ref) async {
    final clients = ref.read(clientsProvider).value ?? const [];
    final services = ref.read(adminServicesProvider).value ?? const [];
    if (clients.isEmpty || services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servono almeno un cliente e un servizio.'),
        ),
      );
      return;
    }
    var clientId = clients.first['id']! as String;
    var serviceId = services.first.id;
    DateTime? startAt;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo appuntamento manuale'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: clientId,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client['id']! as String,
                          child: Text(
                            '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => clientId = value!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: serviceId,
                  decoration: const InputDecoration(labelText: 'Servizio'),
                  items: services
                      .where((service) => service.active)
                      .map(
                        (service) => DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => serviceId = value!,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(startAt?.italianDateTime ?? 'Scegli data e ora'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await _pickDateTime(context);
                    if (picked != null) setDialogState(() => startAt = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: startAt == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Crea e conferma'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || startAt == null) return;
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .adminCreateAppointment(
            clientId: clientId,
            serviceId: serviceId,
            startAt: startAt!,
          );
      ref.invalidate(adminAppointmentsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _createBlock(BuildContext context, WidgetRef ref) async {
    final start = await _pickDateTime(context);
    if (start == null || !context.mounted) return;
    final end = await _pickDateTime(
      context,
      initial: start.add(const Duration(hours: 1)),
    );
    if (end == null || !end.isAfter(start) || !context.mounted) return;
    final reason = await _textDialog(
      context,
      title: 'Motivo blocco',
      label: 'Ferie, pausa, impegno…',
    );
    if (reason == null) return;
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .adminCreateBlock(startAt: start, endAt: end, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Fascia bloccata.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Blocco non riuscito: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    ref.watch(clientsProvider);
    ref.watch(adminServicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Agenda',
          subtitle: 'Appuntamenti confermati e blocchi manuali',
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _createBlock(context, ref),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Blocca fascia'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _manualAppointment(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            data: (items) {
              final confirmed =
                  items
                      .where(
                        (item) =>
                            item.status == AppointmentStatus.confirmed &&
                            item.effectiveEndAt.isAfter(DateTime.now().toUtc()),
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.effectiveStartAt.compareTo(b.effectiveStartAt),
                    );
              if (confirmed.isEmpty) {
                return const Center(child: Text('Agenda libera.'));
              }
              return ListView.separated(
                itemCount: confirmed.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = confirmed[index];
                  return AppointmentCard(
                    appointment: item,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        try {
                          if (action == 'reschedule') {
                            final startAt = await _pickDateTime(
                              context,
                              initial: item.confirmedStartAt,
                            );
                            if (startAt == null) return;
                            await ref
                                .read(appointmentRepositoryProvider)
                                .adminRescheduleAppointment(item.id, startAt);
                          } else if (action == 'cancel') {
                            await ref
                                .read(appointmentRepositoryProvider)
                                .cancelAppointment(item.id);
                          } else {
                            await ref
                                .read(appointmentRepositoryProvider)
                                .adminCompleteAppointment(item.id);
                          }
                          ref.invalidate(adminAppointmentsProvider);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Operazione non riuscita: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'reschedule',
                          child: Text('Sposta appuntamento'),
                        ),
                        PopupMenuItem(
                          value: 'complete',
                          child: Text('Completato'),
                        ),
                        PopupMenuItem(value: 'cancel', child: Text('Annulla')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClientsSection extends ConsumerStatefulWidget {
  const _ClientsSection();

  @override
  ConsumerState<_ClientsSection> createState() => _ClientsSectionState();
}

class _ClientsSectionState extends ConsumerState<_ClientsSection> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final appointments = ref.watch(adminAppointmentsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Clienti',
          subtitle: 'Ricerca e storico appuntamenti',
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cerca per nome, telefono o email',
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AsyncValueView<List<Map<String, dynamic>>>(
            value: clients,
            data: (items) {
              final filtered = items.where((client) {
                final haystack = [
                  client['firstName'],
                  client['lastName'],
                  client['email'],
                  client['phone'],
                ].join(' ').toLowerCase();
                return haystack.contains(_query);
              }).toList();
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final client = filtered[index];
                  final visits = appointments
                      .where(
                        (item) =>
                            item.clientId == client['id'] &&
                            item.status == AppointmentStatus.completed,
                      )
                      .length;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}',
                      ),
                      subtitle: Text(
                        '${client['phone'] ?? ''} · ${client['email'] ?? ''}',
                      ),
                      trailing: Text('$visits visite'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  const _ServicesSection();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SalonService? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name);
    final description = TextEditingController(text: existing?.description);
    final duration = TextEditingController(
      text: '${existing?.durationMinutes ?? 30}',
    );
    final buffer = TextEditingController(
      text: '${existing?.bufferMinutes ?? 0}',
    );
    final price = TextEditingController(
      text: existing?.priceCents == null
          ? ''
          : (existing!.priceCents! / 100).toStringAsFixed(2),
    );
    var active = existing?.active ?? true;
    final result = await showDialog<SalonService>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Nuovo servizio' : 'Modifica servizio',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durata (min)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: buffer,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Buffer (min)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Prezzo EUR'),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('Prenotabile'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final durationValue = int.tryParse(duration.text);
                if (name.text.trim().isEmpty || durationValue == null) return;
                final priceValue = double.tryParse(
                  price.text.replaceAll(',', '.'),
                );
                Navigator.pop(
                  dialogContext,
                  SalonService(
                    id: existing?.id ?? '',
                    name: name.text,
                    description: description.text,
                    durationMinutes: durationValue,
                    bufferMinutes: int.tryParse(buffer.text) ?? 0,
                    priceCents: priceValue == null
                        ? null
                        : (priceValue * 100).round(),
                    active: active,
                    displayOrder: existing?.displayOrder ?? 100,
                  ),
                );
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    duration.dispose();
    buffer.dispose();
    price.dispose();
    if (result == null) return;
    await ref.read(appointmentRepositoryProvider).saveService(result);
    ref.invalidate(adminServicesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(adminServicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Servizi',
          subtitle: 'Durata, buffer, prezzo e visibilità',
          actions: [
            FilledButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo servizio'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<SalonService>>(
            value: services,
            data: (items) => ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final service = items[index];
                final price = service.priceCents == null
                    ? 'Prezzo su richiesta'
                    : NumberFormat.simpleCurrency(locale: 'it_IT')
                          .format(service.priceCents! / 100);
                return Card(
                  child: ListTile(
                    leading: Icon(
                      service.active
                          ? Icons.check_circle_outline
                          : Icons.hide_source,
                    ),
                    title: Text(service.name),
                    subtitle: Text(
                      '${service.durationMinutes} min + ${service.bufferMinutes} buffer · $price',
                    ),
                    trailing: IconButton(
                      onPressed: () => _edit(context, ref, service),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HoursSection extends StatelessWidget {
  const _HoursSection();
  static const _days = <String, String>{
    'monday': 'Lunedì',
    'tuesday': 'Martedì',
    'wednesday': 'Mercoledì',
    'thursday': 'Giovedì',
    'friday': 'Venerdì',
    'saturday': 'Sabato',
    'sunday': 'Domenica',
  };

  Future<void> _editDay(
    BuildContext context,
    String key,
    String label,
    Map<String, dynamic> current,
    Map<String, dynamic> allHours,
  ) async {
    var enabled = current['enabled'] as bool? ?? false;
    var open = current['open'] as String? ?? '09:00';
    var close = current['close'] as String? ?? '18:00';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
                title: const Text('Giorno lavorativo'),
              ),
              ListTile(
                title: const Text('Apertura'),
                trailing: Text(open),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(open),
                  );
                  if (picked != null) {
                    setDialogState(() => open = _formatTime(picked));
                  }
                },
              ),
              ListTile(
                title: const Text('Chiusura'),
                trailing: Text(close),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(close),
                  );
                  if (picked != null) {
                    setDialogState(() => close = _formatTime(picked));
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await FirebaseFirestore.instance.collection('studio').doc('config').set({
      'openingHours': {
        ...allHours,
        key: {'enabled': enabled, 'open': open, 'close': close, 'breaks': []},
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Orari',
          subtitle: 'Settimana standard; ferie e chiusure si gestiscono dai blocchi agenda',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('studio')
                .doc('config')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final hours = Map<String, dynamic>.from(
                snapshot.data!.data()?['openingHours'] as Map? ?? const {},
              );
              return ListView(
                children: _days.entries.map((entry) {
                  final day = Map<String, dynamic>.from(
                    hours[entry.key] as Map? ?? const {},
                  );
                  final enabled = day['enabled'] as bool? ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          enabled
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_outlined,
                        ),
                        title: Text(entry.value),
                        subtitle: Text(
                          enabled
                              ? '${day['open'] ?? '09:00'} – ${day['close'] ?? '18:00'}'
                              : 'Chiuso',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editDay(
                          context,
                          entry.key,
                          entry.value,
                          day,
                          hours,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection();

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final _studioName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _reminder = TextEditingController();
  var _loaded = false;

  @override
  void dispose() {
    _studioName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _reminder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('studio').doc('config').set({
      'studioName': _studioName.text.trim(),
      'supportEmail': _email.text.trim(),
      'supportPhone': _phone.text.trim(),
      'address': _address.text.trim(),
      'timezone': AppConfig.timezone,
      'currency': AppConfig.currency,
      'reminderTime': _reminder.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impostazioni salvate.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('studio')
          .doc('config')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_loaded) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          _studioName.text =
              data['studioName'] as String? ?? AppConfig.studioName;
          _email.text =
              data['supportEmail'] as String? ?? AppConfig.supportEmail;
          _phone.text =
              data['supportPhone'] as String? ?? AppConfig.supportPhone;
          _address.text = data['address'] as String? ?? AppConfig.address;
          _reminder.text =
              data['reminderTime'] as String? ?? AppConfig.reminderTime;
          _loaded = true;
        }
        return ListView(
          children: [
            const _SectionHeader(
              'Impostazioni',
              subtitle: 'Brand, contatti e promemoria',
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _studioName,
                        decoration: const InputDecoration(
                          labelText: 'Nome studio',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email supporto',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reminder,
                        decoration: const InputDecoration(
                          labelText: 'Promemoria giorno prima (HH:mm)',
                          helperText: 'Timezone Europe/Rome',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text(AppStrings.save),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text(AppStrings.confirm),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<DateTime?> _pickDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final localInitial =
      initial?.inStudioTimezone ?? DateTime.now().add(const Duration(days: 1));
  final now = DateUtils.dateOnly(DateTime.now());
  final day = await showDatePicker(
    context: context,
    initialDate: DateTime(
      localInitial.year,
      localInitial.month,
      localInitial.day,
    ),
    firstDate: now,
    lastDate: now.add(const Duration(days: 730)),
    locale: const Locale('it', 'IT'),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: localInitial.hour,
      minute: localInitial.minute,
    ),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 9,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
