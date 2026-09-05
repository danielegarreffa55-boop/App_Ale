import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/appointment_models.dart';

class AppointmentRepository {
  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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
    final result = await _functions
        .httpsCallable('createAppointmentRequest')
        .call<Object?>({
          'serviceId': serviceId,
          'requestedStartAt': requestedStartAt.toUtc().toIso8601String(),
        });
    return Map<Object?, Object?>.from(result.data! as Map)['appointmentId']!
        as String;
  }

  Future<void> adminAccept(String appointmentId) =>
      _call('adminAcceptAppointment', {'appointmentId': appointmentId});

  Future<void> adminReject(String appointmentId, {String? reason}) => _call(
    'adminRejectAppointment',
    {'appointmentId': appointmentId, 'reason': reason},
  );

  Future<void> adminCounterPropose(
    String appointmentId,
    DateTime proposedStartAt,
  ) => _call('adminCounterPropose', {
    'appointmentId': appointmentId,
    'proposedStartAt': proposedStartAt.toUtc().toIso8601String(),
  });

  Future<void> clientRespondToCounterProposal(
    String appointmentId, {
    required bool accept,
  }) => _call('clientRespondToCounterProposal', {
    'appointmentId': appointmentId,
    'accept': accept,
  });

  Future<void> cancelAppointment(String appointmentId) =>
      _call('cancelAppointment', {'appointmentId': appointmentId});

  Future<void> adminCompleteAppointment(String appointmentId) =>
      _call('adminCompleteAppointment', {'appointmentId': appointmentId});

  Future<void> adminRescheduleAppointment(
    String appointmentId,
    DateTime startAt,
  ) => _call('adminRescheduleAppointment', {
    'appointmentId': appointmentId,
    'startAt': startAt.toUtc().toIso8601String(),
  });

  Future<void> adminCreateAppointment({
    required String clientId,
    required String serviceId,
    required DateTime startAt,
  }) => _call('adminCreateAppointment', {
    'clientId': clientId,
    'serviceId': serviceId,
    'startAt': startAt.toUtc().toIso8601String(),
  });

  Future<void> adminCreateBlock({
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) => _call('adminCreateBlock', {
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'reason': reason.trim(),
  });

  Future<void> saveService(SalonService service) async {
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
}
