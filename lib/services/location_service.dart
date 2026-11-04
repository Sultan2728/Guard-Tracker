import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/guard_status.dart';
import 'firestore_service.dart';

/// Watches one worker's GPS position for one shift at their assigned
/// site, compares it against that site's geofence, and writes the
/// resulting in/out status + a log entry whenever they cross the
/// boundary. Uses a small hysteresis buffer so GPS jitter right at the
/// edge of the zone doesn't spam enter/exit events back-to-back.
class LocationService {
  final FirestoreService firestore;
  final String workerId;
  final String workerName;
  final String role;
  final String siteId;

  static const double exitBufferM = 15; // exit threshold = radius + buffer

  StreamSubscription<Position>? _sub;
  Site? _site;
  bool? _currentInZone;

  // Worked-hours bookkeeping for the current shift.
  String? _shiftId;
  int _inZoneMs = 0;
  int? _lastTickMs;

  LocationService({
    required this.firestore,
    required this.workerId,
    required this.workerName,
    required this.role,
    required this.siteId,
  });

  Future<bool> ensurePermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    if (perm == LocationPermission.denied) return false;

    if (!await Geolocator.isLocationServiceEnabled()) return false;

    if (perm == LocationPermission.whileInUse) {
      await Geolocator.requestPermission(); // prompts for "always" on some OS versions
    }
    return true;
  }

  void updateSite(Site? site) {
    _site = site;
  }

  double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double toRad(double d) => d * math.pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * R * math.asin(math.sqrt(a));
  }

  /// Starts the shift: logs shift_start and begins the position stream.
  Future<void> startShift({required void Function(bool inZone, double distanceM) onUpdate}) async {
    await firestore.logEvent(
      workerId: workerId, workerName: workerName, role: role, siteId: siteId, type: 'shift_start',
    );
    _inZoneMs = 0;
    _lastTickMs = null;
    _shiftId = await firestore.startShiftRecord(
      workerId: workerId, workerName: workerName, role: role, siteId: siteId,
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters before a new reading fires
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      // Add the time since the previous reading if the worker was in the zone.
      final tick = DateTime.now().millisecondsSinceEpoch;
      if (_lastTickMs != null && _currentInZone == true) _inZoneMs += tick - _lastTickMs!;
      _lastTickMs = tick;

      final site = _site;
      if (site == null) {
        await firestore.writeStatus(
          workerId: workerId, onShift: true, inZone: false,
          lat: pos.latitude, lng: pos.longitude, accuracy: pos.accuracy,
        );
        return;
      }

      final dist = haversineMeters(pos.latitude, pos.longitude, site.lat, site.lng);
      bool inZone = _currentInZone ?? (dist <= site.radiusM);

      if (_currentInZone != true && dist <= site.radiusM) {
        inZone = true;
      } else if (_currentInZone != false && dist >= site.radiusM + exitBufferM) {
        inZone = false;
      }

      if (inZone != _currentInZone) {
        _currentInZone = inZone;
        await firestore.logEvent(
          workerId: workerId,
          workerName: workerName,
          role: role,
          siteId: siteId,
          type: inZone ? 'enter' : 'exit',
          lat: pos.latitude,
          lng: pos.longitude,
        );
        if (_shiftId != null) await firestore.updateShiftRecord(_shiftId!, inZoneMs: _inZoneMs);
      }

      await firestore.writeStatus(
        workerId: workerId,
        onShift: true,
        inZone: inZone,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      onUpdate(inZone, site.radiusM - dist);
    });
  }

  Future<void> endShift() async {
    await _sub?.cancel();
    _sub = null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTickMs != null && _currentInZone == true) _inZoneMs += now - _lastTickMs!;
    if (_shiftId != null) {
      await firestore.updateShiftRecord(_shiftId!, inZoneMs: _inZoneMs, endedAt: now);
      _shiftId = null;
    }
    _lastTickMs = null;
    _currentInZone = null;
    await firestore.logEvent(
      workerId: workerId, workerName: workerName, role: role, siteId: siteId, type: 'shift_end',
    );
    await firestore.writeStatus(workerId: workerId, onShift: false, inZone: false);
  }

  void dispose() {
    _sub?.cancel();
  }
}
