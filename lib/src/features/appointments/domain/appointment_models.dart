enum AppointmentStatus {
  pendingAdmin('PENDING_ADMIN', 'In attesa di conferma'),
  counterProposed('COUNTER_PROPOSED', 'Controproposta dello studio'),
  counterRejected('COUNTER_REJECTED', 'Proposta rifiutata'),
  confirmed('CONFIRMED', 'Confermato'),
  rejected('REJECTED', 'Rifiutato'),
  cancelled('CANCELLED', 'Annullato'),
  completed('COMPLETED', 'Completato');

  const AppointmentStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static AppointmentStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => AppointmentStatus.pendingAdmin,
  );
}

DateTime? _date(Object? value) => switch (value) {
  DateTime dateTime => dateTime.toUtc(),
  String text => DateTime.tryParse(text)?.toUtc(),
  _ => null,
};

class SalonService {
  const SalonService({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.active,
    required this.displayOrder,
    this.category = 'Altri servizi',
    this.priceFrom = false,
    this.operatorIds = const [],
    this.priceCents,
  });

  factory SalonService.fromJson(Map<String, dynamic> data) {
    return SalonService(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Altri servizi',
      description: data['description'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      bufferMinutes: (data['bufferMinutes'] as num?)?.toInt() ?? 0,
      priceCents: (data['priceCents'] as num?)?.toInt(),
      priceFrom: data['priceFrom'] as bool? ?? false,
      operatorIds: List<String>.from(data['operatorIds'] as List? ?? const []),
      active: data['active'] as bool? ?? false,
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String category;
  final String description;
  final int durationMinutes;
  final int bufferMinutes;
  final int? priceCents;
  final bool priceFrom;
  final List<String> operatorIds;
  final bool active;
  final int displayOrder;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'category': category.trim(),
    'description': description.trim(),
    'durationMinutes': durationMinutes,
    'bufferMinutes': bufferMinutes,
    'priceCents': priceCents,
    'priceFrom': priceFrom,
    'operatorIds': operatorIds,
    'active': active,
    'displayOrder': displayOrder,
  };
}

class Appointment {
  const Appointment({
    required this.id,
    required this.clientId,
    required this.serviceId,
    required this.serviceName,
    required this.status,
    required this.requestedStartAt,
    required this.requestedEndAt,
    required this.createdAt,
    this.proposedStartAt,
    this.proposedEndAt,
    this.confirmedStartAt,
    this.confirmedEndAt,
    this.adminReason,
    this.clientName,
    this.clientPhone,
  });

  factory Appointment.fromJson(Map<String, dynamic> data) {
    final requestedStart = _date(data['requestedStartAt']) ?? DateTime.now();
    return Appointment(
      id: data['id'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      serviceName: data['serviceName'] as String? ?? 'Servizio',
      status: AppointmentStatus.fromWire(data['status']),
      requestedStartAt: requestedStart,
      requestedEndAt: _date(data['requestedEndAt']) ?? requestedStart,
      proposedStartAt: _date(data['proposedStartAt']),
      proposedEndAt: _date(data['proposedEndAt']),
      confirmedStartAt: _date(data['confirmedStartAt']),
      confirmedEndAt: _date(data['confirmedEndAt']),
      createdAt: _date(data['createdAt']) ?? requestedStart,
      adminReason: data['adminReason'] as String?,
      clientName: data['clientName'] as String?,
      clientPhone: data['clientPhone'] as String?,
    );
  }

  final String id;
  final String clientId;
  final String serviceId;
  final String serviceName;
  final AppointmentStatus status;
  final DateTime requestedStartAt;
  final DateTime requestedEndAt;
  final DateTime? proposedStartAt;
  final DateTime? proposedEndAt;
  final DateTime? confirmedStartAt;
  final DateTime? confirmedEndAt;
  final DateTime createdAt;
  final String? adminReason;
  final String? clientName;
  final String? clientPhone;

  DateTime get effectiveStartAt =>
      confirmedStartAt ?? proposedStartAt ?? requestedStartAt;
  DateTime get effectiveEndAt =>
      confirmedEndAt ?? proposedEndAt ?? requestedEndAt;
}

class AvailabilitySlot {
  const AvailabilitySlot({required this.startAt, required this.endAt});

  factory AvailabilitySlot.fromJson(Map<Object?, Object?> data) {
    return AvailabilitySlot(
      startAt: DateTime.parse(data['startAt']! as String).toUtc(),
      endAt: DateTime.parse(data['endAt']! as String).toUtc(),
    );
  }

  final DateTime startAt;
  final DateTime endAt;
}

class AgendaBlock {
  const AgendaBlock({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.reason,
    required this.active,
  });

  factory AgendaBlock.fromJson(Map<String, dynamic> data) {
    final startAt = _date(data['startAt']) ?? DateTime.now().toUtc();
    return AgendaBlock(
      id: data['id'] as String? ?? '',
      startAt: startAt,
      endAt: _date(data['endAt']) ?? startAt,
      reason: data['reason'] as String? ?? 'Fascia bloccata',
      active: data['active'] as bool? ?? true,
    );
  }

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String reason;
  final bool active;
}

/// Returns the first active agenda block that overlaps the appointment's
/// currently relevant interval.
AgendaBlock? findAgendaBlockConflict(
  Appointment appointment,
  Iterable<AgendaBlock> blocks,
) {
  final startAt = appointment.effectiveStartAt;
  final endAt = appointment.effectiveEndAt;
  for (final block in blocks) {
    if (block.active &&
        startAt.isBefore(block.endAt) &&
        endAt.isAfter(block.startAt)) {
      return block;
    }
  }
  return null;
}

/// Returns confirmed appointments that overlap the request being managed.
List<Appointment> findConfirmedAppointmentConflicts(
  Appointment appointment,
  Iterable<Appointment> appointments,
) {
  final startAt = appointment.effectiveStartAt;
  final endAt = appointment.effectiveEndAt;
  final conflicts = appointments
      .where(
        (candidate) =>
            candidate.id != appointment.id &&
            candidate.status == AppointmentStatus.confirmed &&
            startAt.isBefore(candidate.effectiveEndAt) &&
            endAt.isAfter(candidate.effectiveStartAt),
      )
      .toList();
  conflicts.sort(
    (first, second) =>
        first.effectiveStartAt.compareTo(second.effectiveStartAt),
  );
  return conflicts;
}

bool canTransition(AppointmentStatus from, AppointmentStatus to) {
  const transitions = <AppointmentStatus, Set<AppointmentStatus>>{
    AppointmentStatus.pendingAdmin: {
      AppointmentStatus.confirmed,
      AppointmentStatus.rejected,
      AppointmentStatus.counterProposed,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.counterProposed: {
      AppointmentStatus.confirmed,
      AppointmentStatus.counterRejected,
      AppointmentStatus.counterProposed,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.counterRejected: {
      AppointmentStatus.counterProposed,
      AppointmentStatus.rejected,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.confirmed: {
      AppointmentStatus.cancelled,
      AppointmentStatus.completed,
    },
    AppointmentStatus.rejected: {},
    AppointmentStatus.cancelled: {},
    AppointmentStatus.completed: {},
  };
  return transitions[from]?.contains(to) ?? false;
}
