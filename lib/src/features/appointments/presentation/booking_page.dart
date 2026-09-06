import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_time_x.dart';
import '../../../core/network/backend_api.dart';
import '../../../providers.dart';
import '../../../shared/async_value_view.dart';
import '../domain/appointment_models.dart';

String bookingRequestErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'Non siamo riusciti a inviare la richiesta. Riprova tra poco.';
  }
  return switch (error.message) {
    'EMAIL_NOT_VERIFIED' => 'Verifica l\'email dal link ricevuto, poi riprova.',
    'PROFILE_REQUIRED' =>
      'Completa il profilo con il numero di telefono prima di prenotare.',
    'DATE_TOO_SOON' =>
      'Questo orario è troppo vicino. Scegli un orario successivo.',
    'DATE_OUT_OF_RANGE' => 'Questo orario non rientra nel periodo prenotabile.',
    'SERVICE_NOT_FOUND' =>
      'Il servizio scelto non è più disponibile. Selezionane un altro.',
    'RATE_LIMITED' =>
      'Hai inviato troppe richieste. Attendi qualche minuto e riprova.',
    _ when error.code == 'unauthenticated' =>
      'La sessione è scaduta. Accedi di nuovo e riprova.',
    _ => 'Non siamo riusciti a inviare la richiesta. Riprova tra poco.',
  };
}

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  SalonService? _service;
  DateTime _day = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  Future<List<AvailabilitySlot>>? _slots;
  AvailabilitySlot? _selectedSlot;
  var _submitting = false;

  void _loadSlots() {
    final service = _service;
    if (service == null) return;
    setState(() {
      _selectedSlot = null;
      _slots = ref
          .read(appointmentRepositoryProvider)
          .availability(serviceId: service.id, localDay: _day);
    });
  }

  Future<void> _pickDay() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final studioConfig = ref.read(studioConfigProvider).value ?? const {};
    final horizonDays =
        (studioConfig['bookingHorizonDays'] as num?)?.toInt() ?? 90;
    final day = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(now) ? now : _day,
      firstDate: now,
      lastDate: now.add(Duration(days: horizonDays.clamp(1, 730))),
      locale: const Locale('it', 'IT'),
      helpText: 'Scegli il giorno',
    );
    if (day == null) return;
    _day = day;
    _loadSlots();
  }

  Future<void> _submit() async {
    final service = _service;
    final slot = _selectedSlot;
    if (service == null || slot == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invia richiesta'),
        content: Text(
          '${service.name}\n${slot.startAt.italianDateTime}\n\n'
          'La richiesta dovrà essere confermata dallo studio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Indietro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Invia richiesta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .createRequest(serviceId: service.id, requestedStartAt: slot.startAt);
      if (!mounted) return;
      ref.invalidate(clientAppointmentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Richiesta inviata. Ti avviseremo dopo la conferma.'),
        ),
      );
      context.go('/appointments');
    } catch (error) {
      if (mounted) {
        final emailNotVerified =
            error is ApiException && error.message == 'EMAIL_NOT_VERIFIED';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingRequestErrorMessage(error)),
            action: emailNotVerified
                ? SnackBarAction(
                    label: 'Reinvia email',
                    onPressed: () async {
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .resendEmailVerification();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email di verifica inviata.'),
                            ),
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Invio email non riuscito. Riprova dal profilo.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prenota',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Scegli il servizio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AsyncValueView<List<SalonService>>(
                  value: services,
                  onRetry: () => ref.invalidate(servicesProvider),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nessun servizio prenotabile al momento.',
                          ),
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth < 640
                            ? constraints.maxWidth
                            : 280.0;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: items.map((service) {
                            final selected = service.id == _service?.id;
                            final price = service.priceCents == null
                                ? null
                                : NumberFormat.simpleCurrency(locale: 'it_IT')
                                      .format(service.priceCents! / 100);
                            return SizedBox(
                              width: cardWidth,
                              child: Card(
                                color: selected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                    : null,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    _service = service;
                                    _loadSlots();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                service.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge,
                                              ),
                                            ),
                                            if (selected)
                                              const Icon(
                                                Icons.check_circle_rounded,
                                              ),
                                          ],
                                        ),
                                        if (service.description.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(service.description),
                                        ],
                                        const SizedBox(height: 12),
                                        Text(
                                          '${service.category} · '
                                          '${service.durationMinutes} min'
                                          '${price == null ? '' : ' · ${service.priceFrom ? 'da ' : ''}$price'}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
                if (_service != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Scegli giorno e orario',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickDay,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        DateFormat('EEEE d MMMM', 'it_IT').format(_day),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_slots case final slotsFuture?)
                    FutureBuilder<List<AvailabilitySlot>>(
                      future: slotsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint(
                            'Caricamento disponibilità non riuscito: '
                            '${snapshot.error}',
                          );
                          return SizedBox(
                            width: double.infinity,
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.cloud_off_outlined),
                                title: const Text('Orari non disponibili'),
                                subtitle: const Text(
                                  'Non riusciamo a caricare gli orari. '
                                  'Controlla la connessione e riprova.',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Riprova',
                                  onPressed: _loadSlots,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ),
                            ),
                          );
                        }
                        final slots = snapshot.data ?? const [];
                        if (slots.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Nessuno slot disponibile in questo giorno.',
                              ),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: slots.map((slot) {
                            final selected =
                                slot.startAt == _selectedSlot?.startAt;
                            return ChoiceChip(
                              key: Key(
                                'slot-${slot.startAt.toIso8601String()}',
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedSlot = slot),
                              label: Text(slot.startAt.italianTime),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
                if (_selectedSlot != null) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('submitBookingButton'),
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        _submitting ? 'Invio in corso…' : 'Controlla e invia',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
