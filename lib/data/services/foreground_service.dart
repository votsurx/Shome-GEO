import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
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
    debugPrint('🚀 onStart: $timestamp');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    debugPrint('⏰ onRepeatEvent');

    try {
      final prefs = await SharedPreferences.getInstance();
      final shomeHost = prefs.getString('shome_host') ?? '192.168.1.100';
      final phoneId = prefs.getString('phone_id') ?? '';
      final mailruLogin = prefs.getString('mailru_login') ?? '';
      final mailruPassword = prefs.getString('mailru_password') ?? '';

      if (phoneId.isEmpty) {
        debugPrint('⚠️ Phone ID не задан');
        return;
      }

      // 1. Пингуем Shome
      final isHome = await _pingHost(shomeHost);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (isHome) {
        // Дома — обновляем timestamp
        await prefs.setInt('last_home_ts', now);
        debugPrint('📍 Дома — GPS не нужен');
        return;
      }

      // 2. Пинг провалился — проверяем, сколько прошло
      final lastHomeTs = prefs.getInt('last_home_ts') ?? 0;
      final minutesSinceHome = lastHomeTs == 0
          ? 999
          : (now - lastHomeTs) ~/ 60000;

      debugPrint('⏳ Нет пинга уже $minutesSinceHome мин');

      if (minutesSinceHome < 3) {
        debugPrint('⏳ Ждём (меньше 3 мин)');
        return;
      }

      // 3. Точно ушёл — отправляем GPS
      debugPrint('🚶 Вне дома → отправляем GPS');

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 60),
      );

      debugPrint('📍 GPS: ${pos.latitude}, ${pos.longitude}');

      // Mail.ru
      if (mailruLogin.isNotEmpty && mailruPassword.isNotEmpty) {
        await MailruService.connect(
          login: mailruLogin,
          password: mailruPassword,
        );

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
          await prefs.setInt('last_gps_sent', now);
          try {
            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/last_gps_sent.txt');
            await file.writeAsString(now.toString());
          } catch (_) {}
          debugPrint('✅ Отправлено через Mail.ru');
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
    }
  }

  Future<bool> _pingHost(String host) async {
    try {
      final result = await Process.run(
        'ping',
        ['-c', '1', '-W', '2', host],
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('❌ Ошибка ping: $e');
      return false;
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
  static int _intervalMs = 60000;

  /// Инициализация (вызывать в main()).
  static Future<void> init({int intervalMs = 60000}) async {
    _intervalMs = intervalMs < 60000 ? 60000 : intervalMs;

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
        eventAction: ForegroundTaskEventAction.repeat(_intervalMs),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    debugPrint('🔧 ForegroundServiceManager.init: interval=$_intervalMs мс');
  }

  /// Запуск сервиса.
  static Future<bool> start() async {
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
      notificationText:
      'Отправка координат. Остановить — в приложении',
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

  /// Перезапуск сервиса с новым интервалом.
  static Future<void> restart({required int intervalMs}) async {
    debugPrint('🔄 Перезапуск сервиса с интервалом $intervalMs мс');
    await stop();
    await init(intervalMs: intervalMs);
    await start();
  }

  /// Проверка, запущен ли сервис.
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}