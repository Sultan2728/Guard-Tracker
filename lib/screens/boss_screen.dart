import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guard_status.dart';
import '../services/firestore_service.dart';
import 'role_select_screen.dart';

class BossScreen extends StatefulWidget {
  const BossScreen({super.key});

  @override
  State<BossScreen> createState() => _BossScreenState();
}

class _BossScreenState extends State<BossScreen> {
  final _firestore = FirestoreService();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '100');
  String _zoneNote = '';

  static const _typeLabels = {
    'enter': 'вошёл в зону',
    'exit': 'вышел из зоны',
    'shift_start': 'начал смену',
    'shift_end': 'закончил смену',
  };

  @override
  void initState() {
    super.initState();
    _firestore.watchZone().listen((z) {
      if (z == null || !mounted) return;
      _latCtrl.text = z.lat.toStringAsFixed(6);
      _lngCtrl.text = z.lng.toStringAsFixed(6);
      _radiusCtrl.text = z.radiusM.toStringAsFixed(0);
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _zoneNote = 'Определяем ваше местоположение…');
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      setState(() => _zoneNote = 'Местоположение подставлено. Нажмите «Сохранить зону».');
    } catch (e) {
      setState(() => _zoneNote = 'Ошибка: $e');
    }
  }

  Future<void> _saveZone() async {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final radius = double.tryParse(_radiusCtrl.text) ?? 100;
    if (lat == null || lng == null) {
      setState(() => _zoneNote = 'Укажите корректные координаты.');
      return;
    }
    await _firestore.saveZone(ZoneConfig(lat: lat, lng: lng, radiusM: radius));
    setState(() => _zoneNote = 'Зона сохранена ✓');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👔 Панель начальника'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard('Охранники', _guardList()),
          const SizedBox(height: 14),
          _sectionCard('Зона объекта', _zoneSetup()),
          const SizedBox(height: 14),
          _sectionCard('Журнал событий', _eventsLog()),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _guardList() {
    return Column(
      children: [1, 2, 3].map((slot) {
        return StreamBuilder<GuardStatus>(
          stream: _firestore.watchGuard(slot),
          builder: (context, snap) {
            final s = snap.data;
            String label = 'Нет данных';
            MaterialColor color = Colors.grey;
            String meta = '';
            if (s != null) {
              if (!s.onShift) {
                label = 'Не на смене';
                color = Colors.grey;
              } else if (s.inZone) {
                label = 'В зоне';
                color = Colors.green;
              } else {
                label = 'Вне зоны';
                color = Colors.red;
              }
              if (s.updatedAt != null) {
                meta = 'Обновлено: ${_fmtTime(s.updatedAt!)}';
              }
            }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Охранник $slot', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: meta.isNotEmpty ? Text(meta, style: const TextStyle(fontSize: 12)) : null,
              trailing: Chip(
                label: Text(label, style: TextStyle(color: color.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: color.shade50,
                side: BorderSide.none,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _zoneSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _latCtrl, decoration: const InputDecoration(labelText: 'Широта (latitude)')),
        const SizedBox(height: 8),
        TextField(controller: _lngCtrl, decoration: const InputDecoration(labelText: 'Долгота (longitude)')),
        const SizedBox(height: 8),
        TextField(
          controller: _radiusCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Радиус зоны, метров'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _useMyLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Моё текущее место'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveZone, child: const Text('Сохранить зону')),
        if (_zoneNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_zoneNote, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _eventsLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestore.watchEvents(),
          builder: (context, snap) {
            final events = snap.data ?? [];
            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Событий пока нет.', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: events.map((e) {
                final ts = DateTime.fromMillisecondsSinceEpoch(e['timestamp']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Охранник ${e['slot']} — ${_typeLabels[e['type']] ?? e['type']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(_fmtTime(ts), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _firestore.clearEvents, child: const Text('Очистить журнал')),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
