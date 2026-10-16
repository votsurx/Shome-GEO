import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'heartbeat_client.dart';
import 'mailru_service.dart';

/// Точка входа для фонового сервиса.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PresenceTaskHandler());
}

/// Обработчик фоновых задач.
class PresenceTaskHandler extends TaskHandler {
  int _consecutiveFails = 0;
  HeartbeatClient? _client;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final prefs = await SharedPreferences.getInstance();
    _client = HeartbeatClient(
      shomeHost: prefs.getString('shome_host') ?? '192.168.1.100',
      phoneId: prefs.getString('phone_id') ?? '',
      phoneName: prefs.getString('phone_name') ?? 'Телефон',
    );
    debugPrint('🚀 PresenceTaskHandler запущен');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final battery = await _getBattery();

      // 1. Отправляем heartbeat в SHome
      final ok = await _client!.sendHeartbeat(battery: battery);

      if (ok) {
        // ДОМА — сбрасываем счётчик, ничего в облако не пишем
        _consecutiveFails = 0;
        await prefs.setInt(
          'last_home_ts',
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setBool('is_via_wifi', true);

        FlutterForegroundTask.sendDataToMain({
          'event': 'heartbeat_ok',
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
        return;
      }

      // 2. FAIL — увеличиваем счётчик
      _consecutiveFails++;
      await prefs.setBool('is_via_wifi', false);

      FlutterForegroundTask.sendDataToMain({
        'event': 'heartbeat_fail',
        'fails': _consecutiveFails,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('❌ FAIL #$_consecutiveFails');

      // 3. Нужно 3 подряд FAIL (90 сек) чтобы признать "ушёл"
      if (_consecutiveFails < 3) {
        debugPrint('⏳ Ждём подтверждения (нужно 3)');
        return;
      }

      // 4. Уверены что ушёл — получаем GPS
      debugPrint('🚶 УШЁЛ (3 FAIL подряд) → получаем GPS');

      double? lat;
      double? lng;
      double? accuracy;

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        accuracy = pos.accuracy;
      } catch (e) {
        debugPrint('❌ GPS ошибка: $e');
      }

      // 5. Пишем в облако
      final mailruLogin = prefs.getString('mailru_login') ?? '';
      final mailruPassword = prefs.getString('mailru_password') ?? '';
      final phoneId = prefs.getString('phone_id') ?? '';

      if (mailruLogin.isNotEmpty && mailruPassword.isNotEmpty) {
        await MailruService.ensureConnected(
          login: mailruLogin,
          password: mailruPassword,
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        final data = {
          'phoneId': phoneId,
          'status': 'away',
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy,
          'battery': battery,
          'ts': now,
          'companionVersion': '1.0.0',
        };

        final path = 'SHome/presence/$phoneId.json';
        final success = await MailruService.uploadFile(path, jsonEncode(data));

        if (success) {
          await prefs.setInt('last_gps_sent', now);
          FlutterForegroundTask.sendDataToMain({
            'event': 'gps_sent',
            'ts': now,
          });
          debugPrint('✅ Away отправлен в облако');
        }
      }
    } catch (e, st) {
      debugPrint('❌ onRepeatEvent error: $e\n$st');
    }
  }

  Future<int> _getBattery() async {
    try {
      // TODO: подключить battery_plus
      return 0;
    } catch (_) {
      return 0;
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
      notificationText: 'Отправка координат. Остановить — в приложении',
      callback: startCallback,
      serviceTypes: [ForegroundServiceTypes.location],
    );

    debugPrint('✅ Сервис запущен');
    return true;
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    debugPrint('⏹ Сервис остановлен');
  }

  static Future<void> restart({required int intervalMs}) async {
    debugPrint('🔄 Перезапуск сервиса с интервалом $intervalMs мс');
    await stop();
    await init(intervalMs: intervalMs);
    await start();
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}