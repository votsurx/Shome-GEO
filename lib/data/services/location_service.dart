import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class LocationService {
  static Future<int> getLastSentAge() async {
    try {
      // Сначала пробуем файл (надёжнее для isolate)
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/last_gps_sent.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lastSent = int.tryParse(content) ?? 0;
        if (lastSent > 0) {
          return DateTime.now().millisecondsSinceEpoch - lastSent;
        }
      }

      // Fallback — SharedPreferences с reload
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final lastSent = prefs.getInt('last_gps_sent') ?? 0;
      if (lastSent == 0) return -1;
      return DateTime.now().millisecondsSinceEpoch - lastSent;
    } catch (e) {
      debugPrint('❌ Ошибка getLastSentAge: $e');
      return -1;
    }
  }

  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('❌ Нет разрешения на GPS');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('❌ Ошибка GPS: $e');
      return null;
    }
  }
}