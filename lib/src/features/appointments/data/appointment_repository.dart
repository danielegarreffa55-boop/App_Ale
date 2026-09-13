import '../../../core/config/app_config.dart';
import '../../../core/network/backend_api.dart';
import '../domain/appointment_models.dart';

class AppointmentRepository {
  AppointmentRepository({BackendApi? backendApi})
    : _api = backendApi ?? BackendApi.instance;

  final BackendApi _api;

  Duration get _pollInterval =>
      Duration(seconds: AppConfig.apiPollSeconds.clamp(2, 60));

  Stream<T> _poll<T>(Future<T> Function() loader) async* {
    var consecutiveFailures = 0;
    while (true) {
      try {
        yield await loader();
        consecutiveFailures = 0;
      } catch (error, stackTrace) {
        consecutiveFailures++;
        yield* Stream<T>.error(error, stackTrace);
      }
      final retryMultiplier = 1 << (consecutiveFailures.clamp(0, 3));
      await Future<void>.delayed(_pollInterval * retryMultiplier);
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> response) =>
      List<Object?>.from(response['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item! as Map))
          .toList();

  Stream<List<SalonService>> watchServices({bool admin = false}) => _poll(
    () async => _items(
      await _api.get('/v1/services', query: {'includeInactive': '$admin'}),
    ).map(SalonService.fromJson).toList(),
  );

  Stream<List<Appointment>> watchClientAppointments(String userId) => _poll(
    () async =>
        _items(await _api.get('/v1/appointments'))
            .map(Appointment.fromJson)
            .toList(),
  );

  Stream<List<Appointment>> watchAdminAppointments() => _poll(
    () async =>
        _items(await _api.get('/v1/admin/appointments'))
            .map(Appointment.fromJson)
            .toList(),
  );

  Stream<List<Appointment>> watchAdminAgenda({
    required DateTime startAt,
    required DateTime endAt,
  }) => _poll(
    () async => _items(
      await _api.get(
        '/v1/admin/appointments',
        query: {
          'startAt': startAt.toUtc().toIso8601String(),
          'endAt': endAt.toUtc().toIso8601String(),
        },
      ),
    ).map(Appointment.fromJson).toList(),
  );

  Stream<List<AgendaBlock>> watchAdminBlocks() => _poll(
    () async =>
        _items(await _api.get('/v1/admin/blocks'))
            .map(AgendaBlock.fromJson)
            .toList(),
  );

  Stream<Map<String, dynamic>> watchStudioConfig() => _poll(() async {
    final response = await _api.get('/v1/studio-config');
    return Map<String, dynamic>.from(response['config']! as Map);
  });

  Stream<List<Map<String, dynamic>>> watchClients() =>
      _poll(() async => _items(await _api.get('/v1/admin/users')));

  Future<List<AvailabilitySlot>> availability({
    required String serviceId,
    required DateTime localDay,
  }) async {
    final data = await _api.get(
      '/v1/availability',
      query: {
        'serviceId': serviceId,
        'date': localDay.toIso8601String().substring(0, 10),
      },
    );
    return List<Object?>.from(data['slots']! as List)
        .map(
          (slot) => AvailabilitySlot.fromJson(
            Map<Object?, Object?>.from(slot! as Map),
          ),
        )
        .toList();
  }

  Future<String> createRequest({
    required String serviceId,
    required DateTime requestedStartAt,
  }) async {
    final data = await _api.post('/v1/appointments', {
      'serviceId': serviceId,
      'requestedStartAt': requestedStartAt.toUtc().toIso8601String(),
    });
    return data['appointmentId']! as String;
  }

  Future<void> adminAccept(String appointmentId) =>
      _api.post('/v1/admin/appointments/$appointmentId/accept');

  Future<void> adminReject(String appointmentId, {String? reason}) => _api.post(
    '/v1/admin/appointments/$appointmentId/reject',
    {'reason': reason},
  );

  Future<void> adminCounterPropose(
    String appointmentId,
    DateTime proposedStartAt,
  ) => _api.post('/v1/admin/appointments/$appointmentId/counter-proposal', {
    'proposedStartAt': proposedStartAt.toUtc().toIso8601String(),
  });

  Future<void> clientRespondToCounterProposal(
    String appointmentId, {
    required bool accept,
  }) => _api.post('/v1/appointments/$appointmentId/counter-response', {
    'accept': accept,
  });

  Future<void> cancelAppointment(String appointmentId) =>
      _api.post('/v1/appointments/$appointmentId/cancel');

  Future<void> adminCompleteAppointment(String appointmentId) =>
      _api.post('/v1/admin/appointments/$appointmentId/complete');

  Future<void> adminRescheduleAppointment(
    String appointmentId,
    DateTime startAt,
  ) => _api.post('/v1/admin/appointments/$appointmentId/reschedule', {
    'startAt': startAt.toUtc().toIso8601String(),
  });

  Future<void> adminCreateAppointment({
    required String clientId,
    required String serviceId,
    required DateTime startAt,
  }) => _api.post('/v1/admin/appointments', {
    'clientId': clientId,
    'serviceId': serviceId,
    'startAt': startAt.toUtc().toIso8601String(),
  });

  Future<void> adminCreateBlock({
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) => _api.post('/v1/admin/blocks', {
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'reason': reason.trim(),
  });

  Future<void> ownerSetUserRole({required String uid, required String role}) =>
      _api.put('/v1/owner/users/$uid/role', {'role': role});

  Future<void> saveService(SalonService service) async {
    final data = Map<String, Object?>.from(service.toJson());
    if (service.id.isEmpty) {
      await _api.post('/v1/admin/services', data);
    } else {
      await _api.put('/v1/admin/services/${service.id}', data);
    }
  }

  Future<void> saveStudioConfig(Map<String, Object?> data) =>
      _api.patch('/v1/admin/studio-config', data);
}
