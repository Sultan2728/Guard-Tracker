import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/worker.dart';

/// Wraps Firebase Authentication for login/registration, and keeps the
/// matching Firestore `workers/{uid}` profile document in sync.
///
/// Workers log in with a phone number + password. Firebase Auth only
/// speaks email/password, so phone numbers are turned into a synthetic
/// email (digits only + a fixed domain) purely as an Auth identifier —
/// the real phone number is what's shown everywhere in the UI, and it
/// lives in the Firestore profile, not in the synthetic email.
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  CollectionReference get _workersRef => _db.collection('workers');

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String normalizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  String _emailForPhone(String phone) => '${normalizePhone(phone)}@guardtracker.local';

  /// Registers a new worker (or boss) account. Boss accounts are
  /// auto-approved; worker accounts start as 'pending' until the boss
  /// approves them and assigns a site.
  Future<void> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    required bool isBoss,
  }) async {
    final email = _emailForPhone(phone);
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final worker = Worker(
      id: uid,
      name: name.trim(),
      phone: phone.trim(),
      role: role,
      isBoss: isBoss,
      status: isBoss ? WorkerStatus.approved : WorkerStatus.pending,
      siteId: null,
      createdAt: DateTime.now(),
    );
    await _workersRef.doc(uid).set(worker.toMap());
  }

  Future<void> login({required String phone, required String password}) async {
    final email = _emailForPhone(phone);
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Live stream of the signed-in user's own worker profile. Emits null
  /// when signed out or if the profile document hasn't been created yet.
  Stream<Worker?> watchCurrentWorker() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _workersRef.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Worker.fromMap(snap.id, snap.data() as Map<String, dynamic>?);
    });
  }
}

/// Turns a FirebaseAuthException into a short Russian message suitable
/// for showing directly under a form field.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Этот номер телефона уже зарегистрирован.';
    case 'weak-password':
      return 'Пароль слишком короткий — минимум 6 символов.';
    case 'invalid-email':
      return 'Некорректный номер телефона.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Неверный номер телефона или пароль.';
    case 'too-many-requests':
      return 'Слишком много попыток. Подождите немного и попробуйте снова.';
    case 'network-request-failed':
      return 'Нет подключения к интернету.';
    default:
      return 'Ошибка: ${e.message ?? e.code}';
  }
}
