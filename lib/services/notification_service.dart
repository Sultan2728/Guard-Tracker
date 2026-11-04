import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firestore_service.dart';

/// Notifies the boss when a worker enters/leaves a zone or starts/ends a
/// shift.
///
/// Two layers, both keyed by the event id so the same event never shows
/// twice (same notification tag replaces itself):
///  1. While the boss's app is alive, a Firestore listener on new events
///     shows a local notification right away (no server needed).
///  2. The boss's FCM token is saved to Firestore so the Cloud Function in
///     functions/index.js can push to the phone even when the app is
///     closed (needs the Firebase Blaze plan).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'zone_events';
  static const _channelName = 'События на объектах';
  static const _labels = {
    'enter': 'вошёл(а) в зону объекта',
    'exit': 'вышел(а) из зоны объекта',
    'shift_start': 'начал(а) смену',
    'shift_end': 'закончил(а) смену',
  };

  final _plugin = FlutterLocalNotificationsPlugin();
  final _firestore = FirestoreService();
  bool _initialized = false;
  StreamSubscription? _eventsSub;
  StreamSubscription<String>? _tokenSub;
  final _siteNames = <String, String>{};

  Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    ));
    await android?.requestNotificationsPermission();
    await FirebaseMessaging.instance.requestPermission();
    _initialized = true;
  }

  /// Call when a boss signs in / the boss screen opens.
  Future<void> startForBoss(String bossUid) async {
    try {
      await _init();
    } catch (_) {
      return; // notifications are a bonus; never block the app
    }

    // Layer 2: register this phone for server push.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _firestore.saveFcmToken(bossUid, token, isBoss: true);
      _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => _firestore.saveFcmToken(bossUid, t, isBoss: true));
    } catch (_) {}

    // Layer 1: live alerts while the app is running.
    _eventsSub?.cancel();
    _eventsSub = _firestore.watchNewEvents(DateTime.now().millisecondsSinceEpoch).listen(_onEvent);
  }

  Future<void> _onEvent(Map<String, dynamic> e) async {
    final label = _labels[e['type']];
    if (label == null) return;
    final siteId = e['siteId'] as String?;
    var site = siteId == null ? null : _siteNames[siteId];
    if (siteId != null && site == null) {
      final doc = await FirebaseFirestore.instance.collection('sites').doc(siteId).get();
      site = (doc.data()?['name'] as String?) ?? '';
      _siteNames[siteId] = site;
    }
    final who = '${e['workerName'] ?? 'Сотрудник'}${e['role'] != null ? ' (${e['role']})' : ''}';
    await _plugin.show(
      0,
      who,
      '$label${site != null && site.isNotEmpty ? ' «$site»' : ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          tag: e['id'] as String?,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Call on logout so a previous boss's alerts don't keep firing.
  Future<void> stop() async {
    await _eventsSub?.cancel();
    await _tokenSub?.cancel();
    _eventsSub = null;
    _tokenSub = null;
  }
}
