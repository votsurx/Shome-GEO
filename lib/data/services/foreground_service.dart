import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mailru_service.dart';

/// Точка входа для фонового сервиса.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PresenceTaskHandler());
}

/// Обработчик фоновых задач.
class PresenceTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🚀 Foreground service started');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Читаем интервал из настроек (в секундах)
      final intervalSec = prefs.getInt('update_interval') ?? 30;
      final lastSent = prefs.getInt('last_gps_sent') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Проверяем, прошло ли достаточно времени
      if (now - lastSent < intervalSec * 1000) {
        debugPrint(
            '⏳ Ещё рано: прошло ${(now - lastSent) ~/ 1000} сек, нужно $intervalSec сек');
        return;
      }

      debugPrint('⏰ Пора отправлять');

      // 1. Получаем GPS
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      debugPrint('📍 GPS: ${pos.latitude}, ${pos.longitude}');

      // 2. Получаем настройки
      final phoneId = prefs.getString('phone_id') ?? '';
      final mailruLogin = prefs.getString('mailru_login') ?? '';
      final mailruPassword = prefs.getString('mailru_password') ?? '';

      if (phoneId.isEmpty) {
        debugPrint('⚠️ Phone ID не задан');
        return;
      }

      if (mailruLogin.isEmpty || mailruPassword.isEmpty) {
        debugPrint('⚠️ Mail.ru логин/пароль не заданы');
        return;
      }

      // 3. Подключаемся к Mail.ru
      await MailruService.connect(
        login: mailruLogin,
        password: mailruPassword,
      );

      // 4. Отправляем координаты
      final data = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'battery': 0,
        'ts': now,
      };

      final path = 'SHome/presence/$phoneId.json';
      final success = await MailruService.uploadFile(path, jsonEncode(data));

      if (success) {
        // 5. Пишем статус
        await prefs.setInt('last_gps_sent', now);
        await prefs.setDouble('last_lat', pos.latitude);
        await prefs.setDouble('last_lng', pos.longitude);
        debugPrint('✅ Отправлено через Mail.ru');
      } else {
        debugPrint('❌ Ошибка отправки');
      }
    } catch (e) {
      debugPrint('❌ Ошибка в onRepeatEvent: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🛑 Foreground service stopped');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

/// Менеджер foreground service.
class ForegroundServiceManager {
  /// Инициализация (вызывать в main()).
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shome_geo_service',
        channelName: 'SHome-GEO',
        channelDescription: 'Отправка координат в SHome',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(120000), // 2 минуты
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Запуск сервиса.
  static Future<bool> start() async {
    // Запрашиваем разрешение на уведомления
    final permission =
    await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('ℹ️ Сервис уже запущен');
      return true;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'SHome-GEO активно',
      notificationText: 'Отправка координат',
      callback: startCallback,
      serviceTypes: [ForegroundServiceTypes.location],
    );

    debugPrint('✅ Сервис запущен');
    return true;
  }

  /// Остановка сервиса.
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    debugPrint('⏹ Сервис остановлен');
  }

  /// Проверка, запущен ли сервис.
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}