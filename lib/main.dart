import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/services/foreground_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Читаем интервал из настроек
  final prefs = await SharedPreferences.getInstance();
  final intervalSec = prefs.getInt('update_interval') ?? 60;
  final safeInterval = intervalSec < 60 ? 60 : intervalSec;
  debugPrint('🔧 Интервал из настроек: $safeInterval сек');

  // Инициализируем сервис с интервалом
  await ForegroundServiceManager.init(intervalMs: safeInterval * 1000);

  FlutterForegroundTask.addTaskDataCallback((data) {
    debugPrint('📩 Из сервиса: $data');
    // Здесь можно обновить состояние
  });

  runApp(const ProviderScope(child: SHomeGeoApp()));
}

class SHomeGeoApp extends StatelessWidget {
  const SHomeGeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHome-GEO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}