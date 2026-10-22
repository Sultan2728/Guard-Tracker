import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guard_status.dart';
import '../models/worker.dart';

/// Wraps all Firestore reads/writes so the rest of the app never touches
/// collection/document paths directly.
///
/// Firestore layout:
///   sites/{siteId}        -> { name, lat, lng, radiusM }
///   workers/{uid}         -> { name, phone, role, isBoss, status, siteId, createdAt }
///   status/{uid}          -> { onShift, inZone, lat, lng, accuracy, updatedAt }
///   events/{autoId}       -> { workerId, workerName, role, siteId, type, timestamp, lat, lng }
///   tokens/{uid}          -> { fcmToken } (for push notifications)
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _sitesRef => _db.collection('sites');
  CollectionReference get _workersRef => _db.collection('workers');
  DocumentReference _statusRef(String workerId) => _db.collection('status').doc(workerId);
  CollectionReference get _eventsRef => _db.collection('events');
  DocumentReference _tokenRef(String id) => _db.collection('tokens').doc(id);

  // ---------- Sites (objects / ЖК) ----------
  Stream<List<Site>> watchSites() {
    return _sitesRef.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Site.fromMap(d.id, d.data() as Map<String, dynamic>?))
        .toList());
  }

  Stream<Site?> watchSite(String siteId) {
    return _sitesRef.doc(siteId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Site.fromMap(snap.id, snap.data() as Map<String, dynamic>?);
    });
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
    // Unassign (not delete) any workers who were on this site.
    final assigned = await _workersRef.where('siteId', isEqualTo: siteId).get();
    for (final d in assigned.docs) {
      await d.reference.update({'siteId': null});
    }
  }

  // ---------- Workers ----------
  Stream<List<Worker>> watchPendingWorkers() {
    return _workersRef.where('status', isEqualTo: 'pending').snapshots().map((snap) =>
        snap.docs.map((d) => Worker.fromMap(d.id, d.data() as Map<String, dynamic>?)).toList());
  }

  /// Approved workers who aren't assigned to a site yet.
  Stream<List<Worker>> watchUnassignedWorkers() {
    return _workersRef
        .where('status', isEqualTo: 'approved')
        .where('siteId', isNull: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Worker.fromMap(d.id, d.data() as Map<String, dynamic>?))
            .where((w) => !w.isBoss)
            .toList());
  }

  Stream<List<Worker>> watchWorkersForSite(String siteId) {
    return _workersRef
        .where('siteId', isEqualTo: siteId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Worker.fromMap(d.id, d.data() as Map<String, dynamic>?))
            .toList());
  }

  Future<void> approveAndAssign(String workerId, String siteId) {
    return _workersRef.doc(workerId).update({'status': 'approved', 'siteId': siteId});
  }

  Future<void> assignToSite(String workerId, String? siteId) {
    return _workersRef.doc(workerId).update({'siteId': siteId});
  }

  Future<void> rejectWorker(String workerId) {
    return _workersRef.doc(workerId).update({'status': 'rejected'});
  }

  Future<void> removeWorker(String workerId) {
    return _workersRef.doc(workerId).delete();
  }

  // ---------- Live shift status ----------
  Stream<ShiftStatus> watchStatus(String workerId) {
    return _statusRef(workerId).snapshots().map(
        (snap) => ShiftStatus.fromMap(workerId, snap.data() as Map<String, dynamic>?));
  }

  Future<void> writeStatus({
    required String workerId,
    required bool onShift,
    required bool inZone,
    double? lat,
    double? lng,
    double? accuracy,
  }) {
    return _statusRef(workerId).set({
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
    required String workerId,
    required String workerName,
    required String role,
    required String siteId,
    required String type, // enter | exit | shift_start | shift_end
    double? lat,
    double? lng,
  }) {
    return _eventsRef.add({
      'workerId': workerId,
      'workerName': workerName,
      'role': role,
      'siteId': siteId,
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
