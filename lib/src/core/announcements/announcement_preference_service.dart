import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AnnouncementPreferenceService {
  AnnouncementPreferenceService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String userId, String announcementId) =>
      'agh_announcement_dismissed_${userId}_$announcementId';

  Future<bool> wasDismissed({
    required String userId,
    required String announcementId,
  }) async => await _storage.read(key: _key(userId, announcementId)) == 'true';

  Future<void> dismiss({
    required String userId,
    required String announcementId,
  }) => _storage.write(key: _key(userId, announcementId), value: 'true');
}
