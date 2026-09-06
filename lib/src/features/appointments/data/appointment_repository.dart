import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/backend_api.dart';
import '../domain/appointment_models.dart';

class AppointmentRepository {
  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    BackendApi? backendApi,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _auth = auth ?? FirebaseAuth.instance,
       _backendApi = backendApi ?? BackendApi(auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final BackendApi _backendApi;

  Stream<List<SalonService>> watchServices({bool admin = false}) {
    Query<Map<String, dynamic>> query = _firestore.collection('services');
    if (!admin) query = query.where('active', isEqualTo: true);
    return query
        .orderBy('displayOrder')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(SalonService.fromDocument).toList(),
        );
  }

  Stream<List<Appointment>> watchClientAppointments(String uid) {
    return _firestore
        .collection('appointments')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Appointment.fromDocument).toList(),
        );
  }

  Stream<List<Appointment>> watchAdminAppointments() {
    return _firestore
        .collection('appointments')
        .orderBy('createdAt', descending: true)
        .limit(250)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Appointment.fromDocument).toList(),
        );
  }

  Stream<List<Appointment>> watchAdminAgenda({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return _firestore
        .collection('appointments')
        .where(
          'confirmedStartAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startAt.toUtc()),
        )
        .where(
          'confirmedStartAt',
          isLessThan: Timestamp.fromDate(endAt.toUtc()),
        )
        .orderBy('confirmedStartAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Appointment.fromDocument).toList(),
        );
  }

  Stream<List<AgendaBlock>> watchAdminBlocks() {
    return _firestore
        .collection('blocks')
        .where('active', isEqualTo: true)
        .limit(250)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AgendaBlock.fromDocument).toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt)),
        );
  }

  Stream<Map<String, dynamic>> watchStudioConfig() {
    return _firestore
        .collection('studio')
        .doc('config')
        .snapshots()
        .map((snapshot) => snapshot.data() ?? const <String, dynamic>{});
  }

  Stream<List<Map<String, dynamic>>> watchClients() {
    return _firestore
        .collection('users')
        .orderBy('lastName')
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<List<AvailabilitySlot>> availability({
    required String serviceId,
    required DateTime localDay,
  }) async {
    if (_backendApi.enabled) {
      final data = await _backendApi.get(
        '/v1/availability',
        query: {
          'serviceId': serviceId,
          'date': localDay.toIso8601String().substring(0, 10),
        },
      );
      final slots = List<Object?>.from(data['slots']! as List);
      return slots
          .map(
            (slot) => AvailabilitySlot.fromJson(
              Map<Object?, Object?>.from(slot! as Map),
            ),
          )
          .toList();
    }
    final result = await _functions
        .httpsCallable('getAvailability')
        .call<Object?>({
          'serviceId': serviceId,
          'date': localDay.toIso8601String().substring(0, 10),
        });
    final data = Map<Object?, Object?>.from(result.data! as Map);
    final slots = List<Object?>.from(data['slots']! as List);
    return slots
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
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      await _auth.currentUser?.getIdToken(true);
    }
    if (_backendApi.enabled) {
      final data = await _backendApi.post('/v1/appointments', {
        'serviceId': serviceId,
        'requestedStartAt': requestedStartAt.toUtc().toIso8601String(),
      });
      return data['appointmentId']! as String;
    }
    final result = await _functions
        .httpsCallable('createAppointmentRequest')
        .call<Object?>({
          'serviceId': serviceId,
          'requestedStartAt': requestedStartAt.toUtc().toIso8601String(),
        });
    return Map<Object?, Object?>.from(result.data! as Map)['appointmentId']!
        as String;
  }

  Future<void> adminAccept(String appointmentId) => _mutate(
    'adminAcceptAppointment',
    '/v1/admin/appointments/$appointmentId/accept',
    {'appointmentId': appointmentId},
  );

  Future<void> adminReject(String appointmentId, {String? reason}) => _mutate(
    'adminRejectAppointment',
    '/v1/admin/appointments/$appointmentId/reject',
    {'appointmentId': appointmentId, 'reason': reason},
    apiData: {'reason': reason},
  );

  Future<void> adminCounterPropose(
    String appointmentId,
    DateTime proposedStartAt,
  ) => _mutate(
    'adminCounterPropose',
    '/v1/admin/appointments/$appointmentId/counter-proposal',
    {
      'appointmentId': appointmentId,
      'proposedStartAt': proposedStartAt.toUtc().toIso8601String(),
    },
    apiData: {'proposedStartAt': proposedStartAt.toUtc().toIso8601String()},
  );

  Future<void> clientRespondToCounterProposal(
    String appointmentId, {
    required bool accept,
  }) => _mutate(
    'clientRespondToCounterProposal',
    '/v1/appointments/$appointmentId/counter-response',
    {'appointmentId': appointmentId, 'accept': accept},
    apiData: {'accept': accept},
  );

  Future<void> cancelAppointment(String appointmentId) => _mutate(
    'cancelAppointment',
    '/v1/appointments/$appointmentId/cancel',
    {'appointmentId': appointmentId},
  );

  Future<void> adminCompleteAppointment(String appointmentId) => _mutate(
    'adminCompleteAppointment',
    '/v1/admin/appointments/$appointmentId/complete',
    {'appointmentId': appointmentId},
  );

  Future<void> adminRescheduleAppointment(
    String appointmentId,
    DateTime startAt,
  ) => _mutate(
    'adminRescheduleAppointment',
    '/v1/admin/appointments/$appointmentId/reschedule',
    {
      'appointmentId': appointmentId,
      'startAt': startAt.toUtc().toIso8601String(),
    },
    apiData: {'startAt': startAt.toUtc().toIso8601String()},
  );

  Future<void> adminCreateAppointment({
    required String clientId,
    required String serviceId,
    required DateTime startAt,
  }) => _mutate('adminCreateAppointment', '/v1/admin/appointments', {
    'clientId': clientId,
    'serviceId': serviceId,
    'startAt': startAt.toUtc().toIso8601String(),
  });

  Future<void> adminCreateBlock({
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) => _mutate('adminCreateBlock', '/v1/admin/blocks', {
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'reason': reason.trim(),
  });

  Future<void> ownerSetUserRole({required String uid, required String role}) =>
      _mutate(
        'ownerSetUserRole',
        '/v1/owner/users/$uid/role',
        {'uid': uid, 'role': role},
        apiData: {'role': role},
        apiMethod: 'PUT',
      );

  Future<void> saveService(SalonService service) async {
    if (_backendApi.enabled) {
      final data = Map<String, Object?>.from(service.toJson());
      if (service.id.isEmpty) {
        await _backendApi.post('/v1/admin/services', data);
      } else {
        await _backendApi.put('/v1/admin/services/${service.id}', data);
      }
      return;
    }
    final reference = service.id.isEmpty
        ? _firestore.collection('services').doc()
        : _firestore.collection('services').doc(service.id);
    await reference.set({
      ...service.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (service.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _call(String name, Map<String, Object?> data) async {
    await _functions.httpsCallable(name).call<void>(data);
  }

  Future<void> saveStudioConfig(Map<String, Object?> data) async {
    if (_backendApi.enabled) {
      await _backendApi.patch('/v1/admin/studio-config', data);
      return;
    }
    await _firestore.collection('studio').doc('config').set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _mutate(
    String functionName,
    String apiPath,
    Map<String, Object?> functionData, {
    Map<String, Object?>? apiData,
    String apiMethod = 'POST',
  }) async {
    if (!_backendApi.enabled) {
      await _call(functionName, functionData);
      return;
    }
    final body = apiData ?? functionData;
    if (apiMethod == 'PUT') {
      await _backendApi.put(apiPath, body);
    } else {
      await _backendApi.post(apiPath, body);
    }
  }
}
