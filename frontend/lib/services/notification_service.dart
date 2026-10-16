// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'api_service.dart';
import 'dart:ui' show Color;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _kPush = 'notif_push';
  static const _kReminder = 'notif_reminder';

  static const _reminderHour = 19;
  static const _reminderIds = [101, 102, 103];
  static const _legacyReminderId = 100;

  static const _progressDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'ulearn_progreso', 'Progreso',
      channelDescription: 'Avisos de tu progreso en U-Learn',
      importance: Importance.high, priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFF1D61E7),
    ),
    iOS: DarwinNotificationDetails(
        presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
  );

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'ulearn_recordatorios', 'Recordatorios de estudio',
      channelDescription: 'Avisos para retomar tus guías y exámenes',
      importance: Importance.high, priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFF1D61E7),
    ),
    iOS: DarwinNotificationDetails(
        presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
  );

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return a ?? i ?? false;
  }

  static Future<({bool push, bool reminder})> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    return (push: p.getBool(_kPush) ?? false, reminder: p.getBool(_kReminder) ?? false);
  }

  static Future<void> setPush(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPush, on);
  }

  static Future<void> showProgress(String title, String body) async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kPush) ?? false)) return;
    await init();
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, _progressDetails);
  }

  static Future<void> setReminder(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kReminder, on);
    if (!on) {
      await cancelReminders();
      return;
    }
    List<dynamic>? guias;
    try {
      guias = await ApiService.getUserGuides();
    } catch (_) {
      guias = null;
    }
    await syncStudyReminder(guias);
  }

  static Future<void> refreshReminder() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kReminder) ?? false)) return;
    try {
      await syncStudyReminder(await ApiService.getUserGuides());
    } catch (_) {}
  }

  static Future<void> cancelReminders() async {
    await init();
    await _plugin.cancel(_legacyReminderId);
    for (final id in _reminderIds) {
      await _plugin.cancel(id);
    }
  }

  /// Reprograma los avisos según el avance real.
  /// Los avisos empiezan MAÑANA: si hoy abriste la app, hoy no te molesta.
  /// Si no vuelves a abrirla, llegan hasta 3 avisos y se detienen.
  /// Si ya no tienes nada pendiente, no se programa ninguno.
  static Future<void> syncStudyReminder(List<dynamic>? guias) async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kReminder) ?? false)) return;
    await init();
    await cancelReminders();

    final msgs = _buildMessages(guias);
    final now = DateTime.now();
    for (var i = 0; i < msgs.length && i < _reminderIds.length; i++) {
      final when = DateTime(now.year, now.month, now.day + 1 + i, _reminderHour);
      await _plugin.zonedSchedule(
        _reminderIds[i],
        msgs[i].$1,
        msgs[i].$2,
        tz.TZDateTime.from(when, tz.local),
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static List<(String, String)> _buildMessages(List<dynamic>? guias) {
    if (guias == null || guias.isEmpty) return [];

    int total = 0, guiasConPend = 0, maxEx = 0;
    String? tema;
    for (final g in guias) {
      final ex = _toInt(g['examenes_pendientes']);
      if (ex <= 0) continue;
      total += ex;
      guiasConPend++;
      if (ex > maxEx) {
        maxEx = ex;
        tema = g['nombre_tema']?.toString();
      }
    }
    if (total == 0 || tema == null) return [];

    final cuantos =
        total == 1 ? '1 examen pendiente' : '$total exámenes pendientes';
    final donde = guiasConPend == 1 ? 'en "$tema"' : '(empieza por "$tema")';
    final detalle = 'Tienes $cuantos $donde.';

    return [
      ('Exámenes por presentar 📝', detalle),
      ('Tus exámenes te esperan ⏰', 'Llevas un par de días sin entrar. $detalle'),
      ('Aún tienes pendientes 💙', 'Hace varios días que no presentas un examen. $detalle'),
    ];
  }
}