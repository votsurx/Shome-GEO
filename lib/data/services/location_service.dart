import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static Future<int> getLastSentAge() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSent = prefs.getInt('last_gps_sent') ?? 0;
    if (lastSent == 0) return -1; // никогда
    return DateTime.now().millisecondsSinceEpoch - lastSent;
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