/// Common job positions a worker can register as. "Other" lets them type
/// a custom title (e.g. "электрик") that isn't in this list.
const List<String> kWorkerRoles = [
  'Охранник',
  'Техничка',
  'Сантехник',
  'Другое',
];

enum WorkerStatus { pending, approved, rejected }

WorkerStatus workerStatusFromString(String? s) {
  switch (s) {
    case 'approved':
      return WorkerStatus.approved;
    case 'rejected':
      return WorkerStatus.rejected;
    default:
      return WorkerStatus.pending;
  }
}

/// A registered worker — a guard, cleaner, plumber, or the boss. Stored
/// at workers/{uid}, where uid is the Firebase Auth user id (so login
/// credentials live in Firebase Auth, never in this Firestore document).
class Worker {
  final String id; // == Firebase Auth uid
  final String name;
  final String phone;
  final String role; // one of kWorkerRoles, or a custom string if "Другое"
  final bool isBoss;
  final WorkerStatus status;
  final String? siteId; // null until the boss assigns them to an object
  final DateTime? createdAt;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isBoss,
    required this.status,
    this.siteId,
    this.createdAt,
  });

  factory Worker.fromMap(String id, Map<String, dynamic>? map) {
    return Worker(
      id: id,
      name: map?['name'] as String? ?? '',
      phone: map?['phone'] as String? ?? '',
      role: map?['role'] as String? ?? 'Охранник',
      isBoss: map?['isBoss'] as bool? ?? false,
      status: workerStatusFromString(map?['status'] as String?),
      siteId: map?['siteId'] as String?,
      createdAt: map?['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map!['createdAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'role': role,
        'isBoss': isBoss,
        'status': status.name,
        'siteId': siteId,
        'createdAt': createdAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      };
}
