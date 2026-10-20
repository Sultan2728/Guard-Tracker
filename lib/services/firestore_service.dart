import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guard_status.dart';

/// Wraps all Firestore reads/writes so the rest of the app never
/// touches collection/document paths directly.
///
/// Firestore layout:
///   config/zone                -> { lat, lng, radiusM, updatedAt }
///   status/guard1..3           -> { onShift, inZone, lat, lng, accuracy, updatedAt }
///   events/{autoId}            -> { slot, type, timestamp, lat, lng }
///   tokens/guard1..3, tokens/boss -> { fcmToken } (for push notifications)
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  DocumentReference get _zoneRef => _db.collection('config').doc('zone');
  DocumentReference _statusRef(int slot) =>
      _db.collection('status').doc('guard$slot');
  CollectionReference get _eventsRef => _db.collection('events');
  DocumentReference _tokenRef(String id) => _db.collection('tokens').doc(id);

  // ---------- Zone ----------
  Stream<ZoneConfig?> watchZone() {
    return _zoneRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      return ZoneConfig.fromMap(snap.data() as Map<String, dynamic>?);
    });
  }

  Future<void> saveZone(ZoneConfig zone) {
    return _zoneRef.set(zone.toMap());
  }

  // ---------- Guard status ----------
  Stream<GuardStatus> watchGuard(int slot) {
    return _statusRef(slot).snapshots().map(
        (snap) => GuardStatus.fromMap(slot, snap.data() as Map<String, dynamic>?));
  }

  Future<void> writeGuardStatus({
    required int slot,
    required bool onShift,
    required bool inZone,
    double? lat,
    double? lng,
    double? accuracy,
  }) {
    return _statusRef(slot).set({
      'slot': slot,
      'onShift': onShift,
      'inZone': inZone,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------- Events log ----------
  Future<void> logEvent({
    required int slot,
    required String type, // enter | exit | shift_start | shift_end
    double? lat,
    double? lng,
  }) {
    return _eventsRef.add({
      'slot': slot,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
    });
  }

  Stream<List<Map<String, dynamic>>> watchEvents({int limit = 25}) {
    return _eventsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
            .toList());
  }

  Future<void> clearEvents() async {
    final snap = await _eventsRef.limit(300).get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }

  // ---------- Push notification tokens ----------
  /// Call after login/role selection so Cloud Functions know where to
  /// send push notifications. `id` is e.g. "boss" or "guard1".
  Future<void> saveFcmToken(String id, String token) {
    return _tokenRef(id).set({'fcmToken': token});
  }
}
