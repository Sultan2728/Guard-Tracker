import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result returned by [MapPickerScreen]: the chosen center point and radius.
class MapPickResult {
  final double lat;
  final double lng;
  final double radiusM;
  MapPickResult({required this.lat, required this.lng, required this.radiusM});
}

/// A Yandex.Taxi-style map picker: the map pans freely underneath a pin
/// that stays fixed in the center of the screen. A slider controls the
/// zone radius, drawn live as a circle around the pin. Used by the boss
/// to set a site's geofence without typing coordinates by hand.
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double initialRadiusM;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadiusM = 100,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _center;
  late double _radiusM;
  bool _locating = false;

  // Default to Kyzylorda, Kazakhstan when there's no existing site and no
  // GPS fix yet, so the map doesn't open somewhere irrelevant.
  static const _defaultCenter = LatLng(44.8488, 65.4823);

  @override
  void initState() {
    super.initState();
    _center = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _defaultCenter;
    _radiusM = widget.initialRadiusM;
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final newCenter = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = newCenter);
      _mapController.move(newCenter, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить местоположение: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите зону на карте'),
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            onPressed: _locating ? null : _useMyLocation,
            tooltip: 'Моё текущее место',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    onMapEvent: (event) {
                      setState(() => _center = event.camera.center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.guard_tracker',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center,
                          radius: _radiusM,
                          useRadiusInMeter: true,
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          '© OpenStreetMap contributors',
                        ),
                      ],
                    ),
                  ],
                ),
                // Fixed pin in the exact center of the screen — the map
                // moves underneath it, the pin never does. The padding
                // nudges it up so the TIP of the pin (not its center)
                // marks the actual chosen point.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.location_pin, size: 48, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Радиус зоны: ${_radiusM.round()} м'),
                  ],
                ),
                Slider(
                  value: _radiusM,
                  min: 20,
                  max: 1000,
                  divisions: 98,
                  label: '${_radiusM.round()} м',
                  onChanged: (v) => setState(() => _radiusM = v),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      MapPickResult(lat: _center.latitude, lng: _center.longitude, radiusM: _radiusM),
                    );
                  },
                  child: const Text('Подтвердить это место'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
