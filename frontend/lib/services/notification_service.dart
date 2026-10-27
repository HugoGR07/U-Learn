// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'api_service.dart';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show ValueNotifier;

/// Notificación guardada en la bandeja de la app (campana de CoursesView).
class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime date;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
      id: id, title: title, body: body, date: date, read: read ?? this.read);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        read: j['read'] == true,
      );
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _kPush = 'notif_push';
  static const _kReminder = 'notif_reminder';

  static const _kInbox = 'notif_inbox';
  static const _kScheduled = 'notif_scheduled';
  static const _kWelcome = 'notif_welcome_done';
  static const _maxInbox = 50;

  /// Bandeja en memoria; la UI la escucha con ValueListenableBuilder.
  static final ValueNotifier<List<AppNotification>> inbox = ValueNotifier([]);

  static int get unreadCount => inbox.value.where((n) => !n.read).length;

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
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _addToInbox(AppNotification(id: id, title: title, body: body, date: DateTime.now()));

    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kPush) ?? false)) return;
    await init();
    await _plugin.show(id, title, body, _progressDetails);
  }

  // ───────────────────────── Bandeja (campana) ─────────────────────────

  /// Cada usuario tiene su propia bandeja en el teléfono.
  static String _userKey(String base) {
    final u = ApiService.currentUser;
    final uid = u?['id_usuario'] ?? u?['id'] ?? u?['correo'] ?? 'anon';
    return '${base}_$uid';
  }

  /// Carga la bandeja guardada y agrega los recordatorios que ya se dispararon.
  static Future<void> loadInbox() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_userKey(_kInbox));
    var list = <AppNotification>[];
    if (raw != null) {
      try {
        list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    inbox.value = list;

    // La bienvenida es una notificación normal: se agrega una sola vez
    // por usuario y, si se borra, ya no vuelve a aparecer.
    if (!(p.getBool(_userKey(_kWelcome)) ?? false)) {
      await p.setBool(_userKey(_kWelcome), true);
      await _addToInbox(AppNotification(
        id: 1,
        title: '¡Bienvenido a U-Learn!',
        body: 'Genera tu primera guía de estudio con IA para comenzar.',
        date: DateTime.now(),
      ));
    }

    await _collectDeliveredReminders();
  }

  static Future<void> markAllAsRead() async {
    if (unreadCount == 0) return;
    inbox.value = inbox.value.map((n) => n.copyWith(read: true)).toList();
    await _saveInbox();
  }

  static Future<void> clearInbox() async {
    inbox.value = [];
    await _saveInbox();
  }

  static Future<void> _addToInbox(AppNotification n) async {
    final list = [n, ...inbox.value.where((e) => e.id != n.id)];
    list.sort((a, b) => b.date.compareTo(a.date));
    inbox.value = list.take(_maxInbox).toList();
    await _saveInbox();
  }

  static Future<void> _saveInbox() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _userKey(_kInbox), jsonEncode(inbox.value.map((e) => e.toJson()).toList()));
  }

  /// Los recordatorios programados llegan con la app cerrada, así que no
  /// podemos "atraparlos". Guardamos cuándo iban a sonar y, al abrir la app,
  /// los que ya pasaron se pasan a la bandeja.
  static Future<void> _collectDeliveredReminders() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_userKey(_kScheduled));
    if (raw == null) return;
    List<dynamic> pending;
    try {
      pending = jsonDecode(raw) as List;
    } catch (_) {
      await p.remove(_userKey(_kScheduled));
      return;
    }
    final now = DateTime.now();
    final remaining = <dynamic>[];
    for (final e in pending) {
      final n = AppNotification.fromJson(Map<String, dynamic>.from(e));
      if (n.date.isAfter(now)) {
        remaining.add(e);
      } else {
        // id único para no chocar con otras notificaciones de la bandeja
        await _addToInbox(AppNotification(
            id: n.date.millisecondsSinceEpoch ~/ 1000 + n.id,
            title: n.title,
            body: n.body,
            date: n.date));
      }
    }
    await p.setString(_userKey(_kScheduled), jsonEncode(remaining));
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
    // Antes de borrar lo programado, rescata los que ya sonaron.
    await _collectDeliveredReminders();
    final p = await SharedPreferences.getInstance();
    await p.remove(_userKey(_kScheduled));
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
    final scheduled = <Map<String, dynamic>>[];
    for (var i = 0; i < msgs.length && i < _reminderIds.length; i++) {
      final when = DateTime(now.year, now.month, now.day + 1 + i, _reminderHour);
      scheduled.add(AppNotification(
              id: _reminderIds[i], title: msgs[i].$1, body: msgs[i].$2, date: when)
          .toJson());
      await _plugin.zonedSchedule(
        _reminderIds[i],
        msgs[i].$1,
        msgs[i].$2,
        tz.TZDateTime.from(when, tz.local),
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    await p.setString(_userKey(_kScheduled), jsonEncode(scheduled));
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