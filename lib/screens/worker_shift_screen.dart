import 'dart:async';
import 'package:flutter/material.dart';
import '../models/guard_status.dart';
import '../models/worker.dart';
import '../models/shift.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// A worker's (guard, cleaner, plumber, …) shift screen: start/stop the
/// shift, see whether they're currently inside their assigned site's
/// zone. Replaces the old slot-based GuardScreen — a worker is now tied
/// to their own account and whichever site the boss assigned them to.
class WorkerShiftScreen extends StatefulWidget {
  final Worker worker;
  const WorkerShiftScreen({super.key, required this.worker});

  @override
  State<WorkerShiftScreen> createState() => _WorkerShiftScreenState();
}

class _WorkerShiftScreenState extends State<WorkerShiftScreen> {
  final _firestore = FirestoreService();
  late final LocationService _location;

  bool _onShift = false;
  bool? _inZone;
  double? _distanceToEdge;
  Site? _site;
  Timer? _clock; // refreshes the running shift's hours every minute
  String _note = 'Потребуется доступ к геолокации. Держите приложение запущенным во время смены.';

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _onShift) setState(() {});
    });
    _location = LocationService(
      firestore: _firestore,
      workerId: widget.worker.id,
      workerName: widget.worker.name,
      role: widget.worker.role,
      siteId: widget.worker.siteId!,
    );
    _firestore.watchSite(widget.worker.siteId!).listen((site) {
      _site = site;
      _location.updateSite(site);
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
      if (_site == null) {
        setState(() => _note = 'Объект не найден — возможно, начальник его удалил.');
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
    _clock?.cancel();
    _location.dispose();
    super.dispose();
  }

  Color _bannerColor() {
    if (!_onShift) return const Color(0xFF1A2740);
    if (_inZone == true) return OnsiteColors.ok.withValues(alpha: 0.16);
    if (_inZone == false) return OnsiteColors.bad.withValues(alpha: 0.16);
    return const Color(0xFF1A2740);
  }

  Color _bannerTextColor() {
    if (!_onShift) return OnsiteColors.muted;
    if (_inZone == true) return OnsiteColors.ok;
    if (_inZone == false) return OnsiteColors.bad;
    return OnsiteColors.muted;
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

  Widget _hoursCard() {
    return StreamBuilder<List<Shift>>(
      stream: _firestore.watchShiftsForWorker(widget.worker.id),
      builder: (context, snap) {
        final shifts = snap.data ?? [];
        int sum(DateTime from) => shifts
            .where((s) => !s.startedAt.isBefore(from))
            .fold<int>(0, (a, s) => a + s.durationMs());
        Widget cell(String label, int ms) => Expanded(
              child: Column(
                children: [
                  Text(fmtDuration(ms), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: OnsiteColors.muted, fontSize: 12)),
                ],
              ),
            );
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                cell('Сегодня', sum(startOfToday())),
                cell('Неделя', sum(startOfWeek())),
                cell('Месяц', sum(startOfMonth())),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.worker.role} · ${_site?.name ?? '…'}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => AuthService().signOut()),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Здравствуйте, ${widget.worker.name}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _bannerColor(),
                borderRadius: BorderRadius.circular(24),
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
            const SizedBox(height: 14),
            _hoursCard(),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _onShift ? OnsiteColors.bad : null,
                foregroundColor: _onShift ? Colors.white : null,
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
