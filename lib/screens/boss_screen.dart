import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guard_status.dart';
import '../services/firestore_service.dart';
import 'role_select_screen.dart';
import 'site_detail_screen.dart';

/// Boss's home screen: the list of all managed sites (e.g. several ЖК),
/// each with a quick status summary. Tap a site to see its guards, zone
/// settings and event log; use the + button to add a new site.
class BossScreen extends StatefulWidget {
  const BossScreen({super.key});

  @override
  State<BossScreen> createState() => _BossScreenState();
}

class _BossScreenState extends State<BossScreen> {
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👔 Объекты'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSiteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Объект'),
      ),
      body: StreamBuilder<List<Site>>(
        stream: _firestore.watchSites(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sites = snap.data!;
          if (sites.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Пока нет ни одного объекта.\nНажмите «+ Объект», чтобы добавить первый (например, ЖК).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: sites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SiteCard(site: sites[i], firestore: _firestore),
          );
        },
      ),
    );
  }

  void _showAddSiteDialog() {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '100');
    String note = '';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Новый объект'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название (например, ЖК Достар)'),
                ),
                const SizedBox(height: 8),
                TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Широта (latitude)')),
                const SizedBox(height: 8),
                TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Долгота (longitude)')),
                const SizedBox(height: 8),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Радиус зоны, метров'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    setDialogState(() => note = 'Определяем местоположение…');
                    try {
                      LocationPermission perm = await Geolocator.checkPermission();
                      if (perm == LocationPermission.denied) {
                        perm = await Geolocator.requestPermission();
                      }
                      final pos = await Geolocator.getCurrentPosition();
                      latCtrl.text = pos.latitude.toStringAsFixed(6);
                      lngCtrl.text = pos.longitude.toStringAsFixed(6);
                      setDialogState(() => note = 'Местоположение подставлено.');
                    } catch (e) {
                      setDialogState(() => note = 'Ошибка: $e');
                    }
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Моё текущее место'),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final lat = double.tryParse(latCtrl.text);
                final lng = double.tryParse(lngCtrl.text);
                final radius = double.tryParse(radiusCtrl.text) ?? 100;
                if (name.isEmpty || lat == null || lng == null) {
                  setDialogState(() => note = 'Заполните название и корректные координаты.');
                  return;
                }
                await _firestore.addSite(name: name, lat: lat, lng: lng, radiusM: radius);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A summary card for one site: name, radius, and a compact row showing
/// each of the 3 guard slots' current status.
class _SiteCard extends StatelessWidget {
  final Site site;
  final FirestoreService firestore;
  const _SiteCard({required this.site, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(site.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text('Радиус зоны: ${site.radiusM.round()} м',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [1, 2, 3].map((slot) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StreamBuilder<GuardStatus>(
                      stream: firestore.watchGuard(site.id, slot),
                      builder: (context, snap) {
                        final s = snap.data;
                        MaterialColor color = Colors.grey;
                        if (s != null && s.onShift) {
                          color = s.inZone ? Colors.green : Colors.red;
                        }
                        return Chip(
                          label: Text('$slot', style: TextStyle(color: color.shade800, fontWeight: FontWeight.bold)),
                          backgroundColor: color.shade50,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
