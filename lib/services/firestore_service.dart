import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guard_status.dart';

/// Wraps all Firestore reads/writes so the rest of the app never touches
/// collection/document paths directly.
///
/// Firestore layout (supports several sites / objects, e.g. several ЖК,
/// each with its own geofence and its own 3 guard slots):
///   sites/{siteId}                       -> { name, lat, lng, radiusM }
///   status/{siteId}_guard{slot}          -> { siteId, slot, onShift, inZone, lat, lng, accuracy, updatedAt }
///   events/{autoId}                      -> { siteId, slot, type, timestamp, lat, lng }
///   tokens/boss                          -> { fcmToken } (for push notifications)
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _sitesRef => _db.collection('sites');
  DocumentReference _statusRef(String siteId, int slot) =>
      _db.collection('status').doc('${siteId}_guard$slot');
  CollectionReference get _eventsRef => _db.collection('events');
  DocumentReference _tokenRef(String id) => _db.collection('tokens').doc(id);

  // ---------- Sites (objects / ЖК) ----------
  Stream<List<Site>> watchSites() {
    return _sitesRef.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Site.fromMap(d.id, d.data() as Map<String, dynamic>?))
        .toList());
  }

  Future<Site> addSite({
    required String name,
    required double lat,
    required double lng,
    required double radiusM,
  }) async {
    final ref = await _sitesRef.add({
      'name': name,
      'lat': lat,
      'lng': lng,
      'radiusM': radiusM,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return Site(id: ref.id, name: name, lat: lat, lng: lng, radiusM: radiusM);
  }

  Future<void> updateSite(Site site) {
    return _sitesRef.doc(site.id).update(site.toMap());
  }

  Future<void> deleteSite(String siteId) async {
    await _sitesRef.doc(siteId).delete();
    // Also clean up this site's 3 guard status docs, best-effort.
    for (final slot in [1, 2, 3]) {
      await _statusRef(siteId, slot).delete();
    }
  }

  // ---------- Guard status ----------
  Stream<GuardStatus> watchGuard(String siteId, int slot) {
    return _statusRef(siteId, slot).snapshots().map(
        (snap) => GuardStatus.fromMap(siteId, slot, snap.data() as Map<String, dynamic>?));
  }

  Future<void> writeGuardStatus({
    required String siteId,
    required int slot,
    required bool onShift,
    required bool inZone,
    double? lat,
    double? lng,
    double? accuracy,
  }) {
    return _statusRef(siteId, slot).set({
      'siteId': siteId,
      'slot': slot,
      'onShift': onShift,
      'inZone': inZone,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------- Events log (per site) ----------
  Future<void> logEvent({
    required String siteId,
    required int slot,
    required String type, // enter | exit | shift_start | shift_end
    double? lat,
    double? lng,
  }) {
    return _eventsRef.add({
      'siteId': siteId,
      'slot': slot,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
    });
  }

  /// NOTE: this filters by siteId AND orders by timestamp, which needs a
  /// Firestore composite index. The first time this runs, Firestore will
  /// throw an error containing a direct link to auto-create that index —
  /// just open the link and click "Create index".
  Stream<List<Map<String, dynamic>>> watchEvents(String siteId, {int limit = 25}) {
    return _eventsRef
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
            .toList());
  }

  Future<void> clearEvents(String siteId) async {
    final snap = await _eventsRef.where('siteId', isEqualTo: siteId).limit(300).get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }

  // ---------- Push notification tokens ----------
  Future<void> saveFcmToken(String id, String token) {
    return _tokenRef(id).set({'fcmToken': token});
  }
}
