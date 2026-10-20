import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guard_status.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'role_select_screen.dart';

class GuardScreen extends StatefulWidget {
  final int slot;
  const GuardScreen({super.key, required this.slot});

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  final _firestore = FirestoreService();
  late final LocationService _location;

  bool _onShift = false;
  bool? _inZone;
  double? _distanceToEdge;
  ZoneConfig? _zone;
  String _note = 'Потребуется доступ к геолокации. Держите приложение запущенным во время смены.';

  @override
  void initState() {
    super.initState();
    _location = LocationService(firestore: _firestore, slot: widget.slot);
    _firestore.watchZone().listen((z) {
      _zone = z;
      _location.updateZone(z);
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggleShift() async {
    if (!_onShift) {
      final ok = await _location.ensurePermissions();
      if (!ok) {
        setState(() => _note = 'Нет разрешения на геолокацию. Включите его в настройках телефона.');
        return;
      }
      if (_zone == null) {
        setState(() => _note = 'Начальник ещё не настроил зону объекта.');
      }
      setState(() {
        _onShift = true;
        _note = 'Определяем местоположение…';
      });
      await _location.startShift(onUpdate: (inZone, distanceToEdge) {
        if (!mounted) return;
        setState(() {
          _inZone = inZone;
          _distanceToEdge = distanceToEdge;
        });
      });
    } else {
      await _location.endShift();
      setState(() {
        _onShift = false;
        _inZone = null;
        _note = 'Смена закончена.';
      });
    }
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Color _bannerColor() {
    if (!_onShift) return Colors.grey.shade200;
    if (_inZone == true) return Colors.green.shade50;
    if (_inZone == false) return Colors.red.shade50;
    return Colors.grey.shade200;
  }

  Color _bannerTextColor() {
    if (!_onShift) return Colors.grey.shade700;
    if (_inZone == true) return Colors.green.shade800;
    if (_inZone == false) return Colors.red.shade800;
    return Colors.grey.shade700;
  }

  String _bannerTitle() {
    if (!_onShift) return 'Смена не начата';
    if (_inZone == true) return '✅ В зоне объекта';
    if (_inZone == false) return '⚠️ Вне зоны объекта';
    return 'Определяем местоположение…';
  }

  String _bannerSubtitle() {
    if (!_onShift) return 'Нажмите «Начать смену»';
    if (_distanceToEdge == null) return '';
    if (_inZone == true) return 'До границы зоны: ${_distanceToEdge!.round()} м';
    return 'До зоны: ${(-_distanceToEdge!).round()} м';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Охранник ${widget.slot}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _bannerColor(),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(_bannerTitle(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _bannerTextColor())),
                  const SizedBox(height: 4),
                  Text(_bannerSubtitle(), style: TextStyle(color: _bannerTextColor())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _onShift ? Colors.red : null,
              ),
              onPressed: _toggleShift,
              child: Text(_onShift ? 'Закончить смену' : 'Начать смену', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            Text(_note, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
