import 'package:flutter/material.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';

/// Boss's employee management screen: new registrations waiting for
/// approval, approved workers who still need a site assigned, and a
/// quick way to reassign or remove someone.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сотрудники')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Новые заявки'),
          StreamBuilder<List<Worker>>(
            stream: _firestore.watchPendingWorkers(),
            builder: (context, snap) {
              final workers = snap.data ?? [];
              if (workers.isEmpty) {
                return const _EmptyNote('Новых заявок нет.');
              }
              return Column(children: workers.map((w) => _PendingCard(worker: w, firestore: _firestore)).toList());
            },
          ),
          const SizedBox(height: 20),
          _SectionHeader('Одобрены, но без объекта'),
          StreamBuilder<List<Worker>>(
            stream: _firestore.watchUnassignedWorkers(),
            builder: (context, snap) {
              final workers = snap.data ?? [];
              if (workers.isEmpty) {
                return const _EmptyNote('Все одобренные сотрудники назначены на объекты.');
              }
              return Column(
                children: workers.map((w) => _UnassignedCard(worker: w, firestore: _firestore)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickSiteDialog(BuildContext context, FirestoreService firestore) async {
  final sites = await firestore.watchSites().first;
  if (sites.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте хотя бы один объект на экране «Объекты».')),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('На какой объект назначить?'),
      children: sites
          .map((s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s.id),
                child: Text(s.name),
              ))
          .toList(),
    ),
  );
}

class _PendingCard extends StatelessWidget {
  final Worker worker;
  final FirestoreService firestore;
  const _PendingCard({required this.worker, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(worker.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text('${worker.role} · ${worker.phone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final siteId = await _pickSiteDialog(context, firestore);
                      if (siteId != null) {
                        await firestore.approveAndAssign(worker.id, siteId);
                      }
                    },
                    child: const Text('Одобрить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => firestore.rejectWorker(worker.id),
                    child: const Text('Отклонить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnassignedCard extends StatelessWidget {
  final Worker worker;
  final FirestoreService firestore;
  const _UnassignedCard({required this.worker, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${worker.role} · ${worker.phone}'),
        trailing: FilledButton(
          onPressed: () async {
            final siteId = await _pickSiteDialog(context, firestore);
            if (siteId != null) {
              await firestore.assignToSite(worker.id, siteId);
            }
          },
          child: const Text('Назначить'),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}
