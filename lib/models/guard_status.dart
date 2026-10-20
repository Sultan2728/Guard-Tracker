/// A security site (e.g. a residential complex / ЖК) with its own geofence.
/// A boss can manage several of these; a guard picks one before a shift.
class Site {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusM;

  Site({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  factory Site.fromMap(String id, Map<String, dynamic>? map) {
    return Site(
      id: id,
      name: map?['name'] as String? ?? 'Без названия',
      lat: (map?['lat'] as num?)?.toDouble() ?? 0,
      lng: (map?['lng'] as num?)?.toDouble() ?? 0,
      radiusM: (map?['radiusM'] as num?)?.toDouble() ?? 100,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
      };
}

class GuardStatus {
  final String siteId;
  final int slot;
  final bool onShift;
  final bool inZone;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final DateTime? updatedAt;

  GuardStatus({
    required this.siteId,
    required this.slot,
    required this.onShift,
    required this.inZone,
    this.lat,
    this.lng,
    this.accuracy,
    this.updatedAt,
  });

  factory GuardStatus.fromMap(String siteId, int slot, Map<String, dynamic>? map) {
    if (map == null) {
      return GuardStatus(siteId: siteId, slot: slot, onShift: false, inZone: false);
    }
    return GuardStatus(
      siteId: siteId,
      slot: slot,
      onShift: map['onShift'] ?? false,
      inZone: map['inZone'] ?? false,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}
