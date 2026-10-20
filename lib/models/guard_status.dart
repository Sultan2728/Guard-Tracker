class GuardStatus {
  final int slot;
  final bool onShift;
  final bool inZone;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final DateTime? updatedAt;

  GuardStatus({
    required this.slot,
    required this.onShift,
    required this.inZone,
    this.lat,
    this.lng,
    this.accuracy,
    this.updatedAt,
  });

  factory GuardStatus.fromMap(int slot, Map<String, dynamic>? map) {
    if (map == null) {
      return GuardStatus(slot: slot, onShift: false, inZone: false);
    }
    return GuardStatus(
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

class ZoneConfig {
  final double lat;
  final double lng;
  final double radiusM;

  ZoneConfig({required this.lat, required this.lng, required this.radiusM});

  factory ZoneConfig.fromMap(Map<String, dynamic>? map) {
    return ZoneConfig(
      lat: (map?['lat'] as num?)?.toDouble() ?? 0,
      lng: (map?['lng'] as num?)?.toDouble() ?? 0,
      radiusM: (map?['radiusM'] as num?)?.toDouble() ?? 100,
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
}
