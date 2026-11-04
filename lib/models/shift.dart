/// One work shift of one worker: from "Начать смену" to "Закончить смену".
/// Stored at shifts/{id}. [inZoneMs] is how long the worker was actually
/// inside the site's zone during the shift.
class Shift {
  final String id;
  final String workerId;
  final String workerName;
  final String role;
  final String siteId;
  final DateTime startedAt;
  final DateTime? endedAt; // null while the shift is still running
  final int inZoneMs;

  Shift({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.role,
    required this.siteId,
    required this.startedAt,
    required this.endedAt,
    required this.inZoneMs,
  });

  factory Shift.fromMap(String id, Map<String, dynamic> m) {
    return Shift(
      id: id,
      workerId: m['workerId'] as String? ?? '',
      workerName: m['workerName'] as String? ?? '',
      role: m['role'] as String? ?? '',
      siteId: m['siteId'] as String? ?? '',
      startedAt: DateTime.fromMillisecondsSinceEpoch((m['startedAt'] as num?)?.toInt() ?? 0),
      endedAt: m['endedAt'] != null ? DateTime.fromMillisecondsSinceEpoch((m['endedAt'] as num).toInt()) : null,
      inZoneMs: (m['inZoneMs'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isOpen => endedAt == null;

  /// Shift length. A shift that was never closed (phone died, app killed)
  /// and is older than 16 h is not counted as 16+ hours of work; we fall
  /// back to the time known to be in the zone instead.
  int durationMs([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (endedAt != null) return endedAt!.difference(startedAt).inMilliseconds;
    final open = n.difference(startedAt).inMilliseconds;
    return open > 16 * 3600 * 1000 ? inZoneMs : open;
  }
}

String fmtDuration(int ms) {
  final totalMin = ms ~/ 60000;
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return h == 0 ? '$m мин' : '$h ч $m мин';
}

DateTime startOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime startOfWeek() {
  final t = startOfToday();
  return t.subtract(Duration(days: t.weekday - 1)); // Monday
}

DateTime startOfMonth() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, 1);
}
