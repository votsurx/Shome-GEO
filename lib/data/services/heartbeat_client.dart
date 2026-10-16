import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Клиент для отправки heartbeat в SHome.
class HeartbeatClient {
  final String shomeHost;
  final int port;
  final String phoneId;
  final String phoneName;

  HeartbeatClient({
    required this.shomeHost,
    this.port = 7777,
    required this.phoneId,
    required this.phoneName,
  });

  /// Отправляет heartbeat. Возвращает true если SHome доступен.
  /// 3 попытки с интервалом 2 сек внутри одного вызова.
  Future<bool> sendHeartbeat({
    required int battery,
    String? ssid,
  }) async {
    const attempts = 3;
    const retryDelay = Duration(seconds: 2);
    const timeout = Duration(seconds: 3);

    final url = Uri.parse(
      'http://$shomeHost:$port/heartbeat?phoneId=$phoneId',
    );

    for (var i = 0; i < attempts; i++) {
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phoneId': phoneId,
            'phoneName': phoneName,
            'status': 'home',
            'battery': battery,
            'ssid': ssid,
          }),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          debugPrint('💓 Heartbeat OK (попытка ${i + 1})');
          return true;
        }
      } catch (e) {
        debugPrint('💔 Heartbeat FAIL ${i + 1}/$attempts: $e');
        if (i < attempts - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }

    debugPrint('💔 Heartbeat: все $attempts попытки провалились');
    return false;
  }

  /// Простая проверка /ping (без body).
  Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse('http://$shomeHost:$port/ping'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}