import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guard_status.dart';
import '../services/firestore_service.dart';
import 'guard_screen.dart';

/// Lets a guard pick which site (e.g. which ЖК) they are working at this
/// shift, then which guard slot (1/2/3) they are. Guards are not fixed to
/// one site — they choose it fresh before every shift.
class SiteSelectScreen extends StatelessWidget {
  const SiteSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите объект')),
      body: StreamBuilder<List<Site>>(
        stream: firestore.watchSites(),
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
                  'Начальник ещё не добавил ни одного объекта.\nПопросите его настроить зону в своей панели.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final site = sites[i];
              return Card(
                child: ListTile(
                  title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Радиус зоны: ${site.radiusM.round()} м'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickSlot(context, site),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _pickSlot(BuildContext context, Site site) async {
    final slot = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Вы — какой охранник на объекте «${site.name}»?'),
        children: [1, 2, 3]
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Text('Охранник $s'),
                ))
            .toList(),
      ),
    );
    if (slot == null || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'guard');
    await prefs.setString('siteId', site.id);
    await prefs.setString('siteName', site.name);
    await prefs.setInt('slot', slot);

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GuardScreen(siteId: site.id, siteName: site.name, slot: slot),
      ),
    );
  }
}
