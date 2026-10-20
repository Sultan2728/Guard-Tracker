import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/guard_status.dart';
import '../services/firestore_service.dart';

/// Boss's view of a single site (e.g. one ЖК): its geofence settings,
/// the live status of its 3 guard slots, and its event log.
class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  final _firestore = FirestoreService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _radiusCtrl;
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
    _nameCtrl = TextEditingController(text: widget.site.name);
    _latCtrl = TextEditingController(text: widget.site.lat.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: widget.site.lng.toStringAsFixed(6));
    _radiusCtrl = TextEditingController(text: widget.site.radiusM.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
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
      setState(() => _zoneNote = 'Местоположение подставлено. Нажмите «Сохранить».');
    } catch (e) {
      setState(() => _zoneNote = 'Ошибка: $e');
    }
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final radius = double.tryParse(_radiusCtrl.text) ?? 100;
    final name = _nameCtrl.text.trim();
    if (lat == null || lng == null || name.isEmpty) {
      setState(() => _zoneNote = 'Заполните название и корректные координаты.');
      return;
    }
    await _firestore.updateSite(Site(id: widget.site.id, name: name, lat: lat, lng: lng, radiusM: radius));
    setState(() => _zoneNote = 'Сохранено ✓');
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить объект?'),
        content: Text('«${widget.site.name}» и статусы его охранников будут удалены безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.deleteSite(widget.site.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
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
          stream: _firestore.watchGuard(widget.site.id, slot),
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
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Название объекта')),
        const SizedBox(height: 8),
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
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
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
          stream: _firestore.watchEvents(widget.site.id),
          builder: (context, snap) {
            final events = snap.data ?? [];
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Не удалось загрузить журнал. Если ошибка упоминает '
                  '"index", откройте ссылку из неё в логах Android Studio '
                  'и нажмите "Create index" в Firebase.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              );
            }
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
        OutlinedButton(
          onPressed: () => _firestore.clearEvents(widget.site.id),
          child: const Text('Очистить журнал'),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
