import 'package:flutter/material.dart';
import '../models/guard_status.dart';
import '../models/shift.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

/// Boss's report: how many hours each worker worked in a period, and how
/// much of that time they were actually inside the site's zone.
class HoursReportScreen extends StatefulWidget {
  const HoursReportScreen({super.key});

  @override
  State<HoursReportScreen> createState() => _HoursReportScreenState();
}

enum _Period { today, week, month }

class _HoursReportScreenState extends State<HoursReportScreen> {
  final _firestore = FirestoreService();
  _Period _period = _Period.today;
  String? _siteId; // null = all sites

  DateTime get _from {
    switch (_period) {
      case _Period.today:
        return startOfToday();
      case _Period.week:
        return startOfWeek();
      case _Period.month:
        return startOfMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёт по часам')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.today, label: Text('Сегодня')),
                ButtonSegment(value: _Period.week, label: Text('Неделя')),
                ButtonSegment(value: _Period.month, label: Text('Месяц')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
          ),
          StreamBuilder<List<Site>>(
            stream: _firestore.watchSites(),
            builder: (context, snap) {
              final sites = snap.data ?? [];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DropdownButtonFormField<String?>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(labelText: 'Объект'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Все объекты')),
                    ...sites.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _siteId = v),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Shift>>(
              stream: _firestore.watchShiftsSince(_from.millisecondsSinceEpoch),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final shifts = snap.data!.where((s) => _siteId == null || s.siteId == _siteId).toList();
                if (shifts.isEmpty) {
                  return const Center(
                    child: Text('За этот период смен нет.', style: TextStyle(color: OnsiteColors.muted)),
                  );
                }
                final byWorker = <String, List<Shift>>{};
                for (final s in shifts) {
                  byWorker.putIfAbsent(s.workerId, () => []).add(s);
                }
                final rows = byWorker.entries.map((e) {
                  final list = e.value;
                  return _Row(
                    name: list.first.workerName,
                    role: list.first.role,
                    shifts: list.length,
                    workedMs: list.fold<int>(0, (a, s) => a + s.durationMs()),
                    inZoneMs: list.fold<int>(0, (a, s) => a + s.inZoneMs),
                    running: list.any((s) => s.isOpen),
                  );
                }).toList()
                  ..sort((a, b) => b.workedMs.compareTo(a.workedMs));
                final totalMs = rows.fold<int>(0, (a, r) => a + r.workedMs);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Всего: ${fmtDuration(totalMs)} · сотрудников: ${rows.length}',
                          style: const TextStyle(color: OnsiteColors.muted)),
                    ),
                    ...rows.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _WorkerHoursCard(row: r))),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String name, role;
  final int shifts, workedMs, inZoneMs;
  final bool running;
  _Row({
    required this.name,
    required this.role,
    required this.shifts,
    required this.workedMs,
    required this.inZoneMs,
    required this.running,
  });
}

class _WorkerHoursCard extends StatelessWidget {
  final _Row row;
  const _WorkerHoursCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (row.running) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 9, color: OnsiteColors.ok),
                        const SizedBox(width: 4),
                        const Text('на смене', style: TextStyle(color: OnsiteColors.ok, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${row.role} · смен: ${row.shifts}',
                      style: const TextStyle(color: OnsiteColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtDuration(row.workedMs), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('в зоне: ${fmtDuration(row.inZoneMs)}',
                    style: const TextStyle(color: OnsiteColors.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
