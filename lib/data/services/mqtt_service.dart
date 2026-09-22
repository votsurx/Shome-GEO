import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class GeoMqttService {
  MqttServerClient? _client;
  String? _pairId;
  String? _phoneId;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<bool> connect({
    required String host,
    required int port,
    required String phoneId,
    String? user,
    String? password,
  }) async {
    try {
      _phoneId = phoneId;

      final clientId = 'shome_geo_${phoneId}_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient.withPort(host, clientId, port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.connectTimeoutPeriod = 5000;

      if (user != null && user.isNotEmpty) {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(user, password ?? '')
            .startClean();
      } else {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean();
      }

      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _connected = true;
        debugPrint('✅ MQTT подключён: $host:$port');
        return true;
      } else {
        debugPrint('❌ MQTT не подключён');
        _client!.disconnect();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Ошибка MQTT: $e');
      _connected = false;
      return false;
    }
  }

  Future<void> publishLocation({
    required double lat,
    required double lng,
    required double accuracy,
    required int battery,
    String? ssid,
  }) async {
    if (_client == null || !_connected) return;

    final topic = 'home/presence/$_pairId/$_phoneId';
    final payload = jsonEncode({
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'battery': battery,
      'ssid': ssid,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('📤 Отправлено: $payload');
  }

  void disconnect() {
    _client?.disconnect();
    _connected = false;
  }
}