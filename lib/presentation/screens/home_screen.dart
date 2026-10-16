import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../application/models/geo_settings.dart';
import '../../application/state/geo_settings_provider.dart';
import '../../data/services/foreground_service.dart';
import '../../data/services/presence_service.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PresenceService _presence;
  Timer? _uiTimer;

  // ─── Wi-Fi статус ───
  bool _viaWifi = false;
  int _lastWifiPingOk = 0;

  @override
  void initState() {
    super.initState();
    _presence = PresenceService(ref);

    // Подписываемся на события из фонового сервиса
    FlutterForegroundTask.addTaskDataCallback(_handleServiceEvent);

    // Периодическое обновление UI
    _uiTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _presence.updateStatus();
      await _refreshWifiStatus();
      if (mounted) setState(() {});
    });

    // Следим за изменениями настроек
    ref.listenManual(geoSettingsProvider, (previous, next) {
      debugPrint('🔧 Настройки изменились: enabled=${next.enabled}');
      _onSettingsChanged(previous, next);
    });

    // Автозапуск сервиса
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isRunning = await ForegroundServiceManager.isRunning();
      debugPrint('🔧 Сервис запущен: $isRunning');

      if (!isRunning) {
        final settings = ref.read(geoSettingsProvider);
        if (settings.enabled) {
          debugPrint('⚠️ Сервис не запущен, выключаю ползунок');
          ref.read(geoSettingsProvider.notifier).update(
            settings.copyWith(enabled: false),
          );
        }
      } else {
        // Если сервис запущен, но ползунок выключен — включаем
        final settings = ref.read(geoSettingsProvider);
        if (!settings.enabled) {
          ref.read(geoSettingsProvider.notifier).update(
            settings.copyWith(enabled: true),
          );
        }
        _presence.start();
      }
    });
  }

  /// Обработка событий из фонового сервиса.
  void _handleServiceEvent(Object data) {
    if (data is! Map) return;

    final event = data['event'] as String?;
    debugPrint('📩 event: $event');

    switch (event) {
      case 'heartbeat_ok':
        if (mounted) {
          setState(() {
            _viaWifi = true;
            _lastWifiPingOk = DateTime.now().millisecondsSinceEpoch;
          });
        }
        break;

      case 'heartbeat_fail':
        if (mounted) {
          setState(() => _viaWifi = false);
        }
        break;

      case 'gps_sent':
        final ts = data['ts'] as int?;
        if (ts != null) {
          final age = DateTime.now().millisecondsSinceEpoch - ts;
          _presence.setLastSentAge(age);
          if (mounted) setState(() {});
        }
        break;
    }
  }

  /// Обновляет Wi-Fi статус из SharedPreferences.
  Future<void> _refreshWifiStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _viaWifi = prefs.getBool('is_via_wifi') ?? false;
      _lastWifiPingOk = prefs.getInt('last_home_ts') ?? 0;
    });
  }

  /// Реакция на изменение настроек.
  Future<void> _onSettingsChanged(
      GeoSettings? previous, GeoSettings next) async {
    debugPrint(
        '🔧 _onSettingsChanged: enabled=${next.enabled}, isConfigured=${next.isConfigured}');

    if (next.enabled && next.isConfigured) {
      if (!_presence.isRunning) {
        await _presence.start();
      }
    } else {
      if (_presence.isRunning) {
        _presence.stop();
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // UI WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatusCard() {
    final isRunning = _presence.isRunning;

    return Card(
      color: isRunning ? Colors.green.shade50 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isRunning ? Icons.check_circle : Icons.pause_circle,
              size: 48,
              color: isRunning ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              isRunning ? 'Активно' : 'Не активно',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_presence.lastSentAge >= 0)
              Text(
                'Последняя отправка GPS: ${_formatAge(_presence.lastSentAge)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _presence.lastSentAge < 300000
                      ? Colors.green
                      : Colors.orange,
                ),
              )
            else
              const Text(
                'GPS ещё не отправлялся',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiCard() {
    final age = _lastWifiPingOk > 0
        ? DateTime.now().millisecondsSinceEpoch - _lastWifiPingOk
        : -1;
    final isFresh = age >= 0 && age < 90000;

    return Card(
      child: ListTile(
        leading: Icon(
          _viaWifi ? Icons.wifi : Icons.wifi_off,
          color: _viaWifi ? Colors.green : Colors.grey,
          size: 36,
        ),
        title: Text(
          _viaWifi ? '🏠 Дома (SHome доступен)' : 'Вне дома',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          age < 0
              ? 'Ещё не проверяли'
              : isFresh
              ? 'Heartbeat OK ${_formatAge(age)}'
              : 'Последний OK: ${_formatAge(age)}',
        ),
      ),
    );
  }

  Widget _buildPhoneCard(GeoSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.phone),
        title: Text(
          settings.phoneName.isEmpty ? 'Телефон' : settings.phoneName,
        ),
        subtitle: Text(
          'ID: ${settings.phoneId.isEmpty ? "не задан" : settings.phoneId}',
        ),
      ),
    );
  }

  Widget _buildIntervalCard(GeoSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer),
        title: Text('Интервал: ${settings.updateIntervalSec} сек'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(geoSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHome-GEO'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildWifiCard(),
            const SizedBox(height: 16),
            _buildPhoneCard(settings),
            _buildIntervalCard(settings),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _formatAge(int ms) {
    final sec = ms ~/ 1000;
    if (sec < 60) return 'только что';
    final min = sec ~/ 60;
    if (min < 60) return '$min мин назад';
    final hours = min ~/ 60;
    if (hours < 24) return '$hours ч назад';
    final days = hours ~/ 24;
    return '$days дн назад';
  }
}