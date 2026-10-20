import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/guard_status.dart';
import 'firestore_service.dart';

/// Watches this guard's GPS position, compares it against the configured
/// zone, and writes the resulting in/out status + a log entry whenever
/// the guard crosses the boundary. Uses a small hysteresis buffer so
/// GPS jitter right at the edge of the zone doesn't spam enter/exit
/// events back-to-back.
class LocationService {
  final FirestoreService firestore;
  final int slot;

  static const double exitBufferM = 15; // exit threshold = radius + buffer

  StreamSubscription<Position>? _sub;
  ZoneConfig? _zone;
  bool? _currentInZone;

  LocationService({required this.firestore, required this.slot});

  Future<bool> ensurePermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    if (perm == LocationPermission.denied) return false;

    if (!await Geolocator.isLocationServiceEnabled()) return false;

    // Background permission is optional but needed for tracking with
    // the screen off / app backgrounded. Ask separately so the app
    // still works (foreground-only) if the guard declines it.
    if (perm == LocationPermission.whileInUse) {
      await Geolocator.requestPermission(); // prompts for "always" on some OS versions
    }
    return true;
  }

  void updateZone(ZoneConfig? zone) {
    _zone = zone;
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
    await firestore.logEvent(slot: slot, type: 'shift_start');

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters before a new reading fires
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      final zone = _zone;
      if (zone == null) {
        await firestore.writeGuardStatus(
          slot: slot, onShift: true, inZone: false, lat: pos.latitude, lng: pos.longitude, accuracy: pos.accuracy,
        );
        return;
      }

      final dist = haversineMeters(pos.latitude, pos.longitude, zone.lat, zone.lng);
      bool inZone = _currentInZone ?? (dist <= zone.radiusM);

      if (_currentInZone != true && dist <= zone.radiusM) {
        inZone = true;
      } else if (_currentInZone != false && dist >= zone.radiusM + exitBufferM) {
        inZone = false;
      }

      if (inZone != _currentInZone) {
        _currentInZone = inZone;
        await firestore.logEvent(
          slot: slot,
          type: inZone ? 'enter' : 'exit',
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }

      await firestore.writeGuardStatus(
        slot: slot,
        onShift: true,
        inZone: inZone,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      onUpdate(inZone, zone.radiusM - dist);
    });
  }

  Future<void> endShift() async {
    await _sub?.cancel();
    _sub = null;
    _currentInZone = null;
    await firestore.logEvent(slot: slot, type: 'shift_end');
    await firestore.writeGuardStatus(slot: slot, onShift: false, inZone: false);
  }

  void dispose() {
    _sub?.cancel();
  }
}
