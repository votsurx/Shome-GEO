import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/models/geo_settings.dart';
import '../../application/state/geo_settings_provider.dart';
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

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 HomeScreen initState');
    _presence = PresenceService(ref);

    // Таймер обновления UI каждые 5 секунд
    _uiTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    // Следим за изменениями настроек
    ref.listenManual(geoSettingsProvider, (previous, next) {
      debugPrint('🔧 Настройки изменились: enabled=${next.enabled}');
      _onSettingsChanged(previous, next);
    });

    // Автозапуск
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      final settings = ref.read(geoSettingsProvider);
      debugPrint(
          '🔧 Автозапуск: enabled=${settings.enabled}, isConfigured=${settings.isConfigured}');
      if (settings.enabled && settings.isConfigured) {
        await _presence.start();
        if (!mounted) return;
        setState(() {});
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(geoSettingsProvider);
    final presence = _presence;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус
            Card(
              color: presence.isRunning
                  ? Colors.green.shade50
                  : Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      presence.isRunning
                          ? Icons.check_circle
                          : Icons.pause_circle,
                      size: 48,
                      color: presence.isRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      presence.isRunning ? 'Активно' : 'Не активно',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Последняя отправка
                    if (presence.lastSentAge >= 0)
                      Text(
                        'Последняя отправка: ${_formatAge(presence.lastSentAge)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: presence.lastSentAge < 300000
                              ? Colors.green
                              : Colors.orange,
                        ),
                      )
                    else
                      const Text(
                        'Данные ещё не отправлялись',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Инфо о телефоне
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: Text(
                  settings.phoneName.isEmpty
                      ? 'Телефон'
                      : settings.phoneName,
                ),
                subtitle: Text(
                  'ID: ${settings.phoneId.isEmpty ? "не задан" : settings.phoneId}',
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer),
                title: Text('Интервал: ${settings.updateIntervalSec} сек'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAge(int ms) {
    final sec = ms ~/ 1000;
    if (sec < 60) return '$sec сек назад';
    final min = sec ~/ 60;
    if (min < 60) return '$min мин назад';
    final hours = min ~/ 60;
    return '$hours ч назад';
  }
}