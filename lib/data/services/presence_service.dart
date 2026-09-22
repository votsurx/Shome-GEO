import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/state/geo_settings_provider.dart';
import 'foreground_service.dart';
import 'location_service.dart';

class PresenceService {
  final WidgetRef ref;
  bool _running = false;
  Timer? _statusTimer;
  int _lastSentAge = 0;

  PresenceService(this.ref);

  bool get isRunning => _running;
  int get lastSentAge => _lastSentAge;

  Future<void> start() async {
    debugPrint('▶️ start() вызван');
    if (_running) {
      debugPrint('⚠️ Уже запущено');
      return;
    }

    final settings = ref.read(geoSettingsProvider);
    debugPrint('🔧 isConfigured: ${settings.isConfigured}');
    debugPrint('🔧 Phone ID: ${settings.phoneId}');

    if (!settings.isConfigured) {
      debugPrint('⚠️ Настройки не заполнены');
      return;
    }

    // Запрос разрешений GPS
    final hasGpsPermission = await LocationService.requestPermission();
    debugPrint('🔧 GPS разрешение: $hasGpsPermission');
    if (!hasGpsPermission) {
      debugPrint('⚠️ Нет разрешения GPS');
      return;
    }

    // Запускаем foreground service
    await ForegroundServiceManager.start();

    _running = true;
    _startStatusTimer();

    debugPrint('✅ PresenceService запущен');
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _updateStatus(),
    );
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final age = await LocationService.getLastSentAge();
    _lastSentAge = age;
  }

  void stop() {
    ForegroundServiceManager.stop();
    _statusTimer?.cancel();
    _statusTimer = null;
    _running = false;
    debugPrint('⏹ PresenceService остановлен');
  }
}