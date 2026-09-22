import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/state/geo_settings_provider.dart';
import 'foreground_service.dart';
import 'location_service.dart';

class PresenceService {
  final WidgetRef ref;
  bool _running = false;
  int _lastSentAge = -1;

  PresenceService(this.ref);

  bool get isRunning => _running;
  int get lastSentAge => _lastSentAge;

  void setLastSentAge(int age) {
    _lastSentAge = age;
  }

  Future<void> start() async {
    debugPrint('▶️ start() вызван');
    if (_running) {
      debugPrint('⚠️ Уже запущено');
      return;
    }

    final settings = ref.read(geoSettingsProvider);
    if (!settings.isConfigured) {
      debugPrint('⚠️ Настройки не заполнены');
      return;
    }

    final hasGpsPermission = await LocationService.requestPermission();
    if (!hasGpsPermission) {
      debugPrint('⚠️ Нет разрешения GPS');
      return;
    }

    await ForegroundServiceManager.start();

    _running = true;
    await updateStatus();

    debugPrint('✅ PresenceService запущен');
  }

  Future<void> updateStatus() async {
    _lastSentAge = await LocationService.getLastSentAge();
  }

  void stop() {
    ForegroundServiceManager.stop();
    _running = false;
    debugPrint('⏹ PresenceService остановлен');
  }
}