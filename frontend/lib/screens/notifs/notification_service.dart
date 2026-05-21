import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    // Request permissions on Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Core notification sender ─────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'avatar_alerts',
      'AVATAR Alerts',
      channelDescription: 'Asthma monitoring alerts from AVATAR OS',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Show a notification based on a risk score (0.0 – 1.0).
  Future<void> afficherSelonScore(double score) async {
    if (score >= 0.8) {
      await _show(
        id: 3,
        title: '🚨 ALERTE CRITIQUE — AVATAR OS',
        body:
            'Paramètres vitaux critiques détectés. Intervention immédiate requise.',
      );
    } else if (score >= 0.6) {
      await _show(
        id: 2,
        title: '⚠️ ALERTE — AVATAR OS',
        body: 'Paramètres vitaux anormaux. Vérification recommandée.',
      );
    } else if (score >= 0.4) {
      await _show(
        id: 1,
        title: '⚡ VIGILANCE — AVATAR OS',
        body: 'Paramètres légèrement élevés. Surveillance accrue conseillée.',
      );
    }
    // score < 0.4 → normal, no notification
  }

  /// Show a notification based on a status string.
  Future<void> afficherSelonStatus(String? status) async {
    switch (status?.toLowerCase()) {
      case 'critical':
        await afficherSelonScore(0.9);
        break;
      case 'warning':
        await afficherSelonScore(0.65);
        break;
      case 'normal':
      default:
        break;
    }
  }
}
