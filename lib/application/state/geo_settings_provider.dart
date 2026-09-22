import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/geo_settings.dart';

final geoSettingsProvider =
NotifierProvider<GeoSettingsNotifier, GeoSettings>(() {
  return GeoSettingsNotifier();
});

class GeoSettingsNotifier extends Notifier<GeoSettings> {
  @override
  GeoSettings build() {
    _load();
    return GeoSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = GeoSettings(
      phoneId: prefs.getString('phone_id') ?? '',
      phoneName: prefs.getString('phone_name') ?? '',
      localMqttHost: prefs.getString('local_mqtt_host') ?? '192.168.1.100',
      localMqttPort: prefs.getInt('local_mqtt_port') ?? 1883,
      cloudMqttHost: prefs.getString('cloud_mqtt_host') ?? '',
      cloudMqttPort: prefs.getInt('cloud_mqtt_port') ?? 8883,
      cloudMqttUser: prefs.getString('cloud_mqtt_user') ?? '',
      cloudMqttPassword: prefs.getString('cloud_mqtt_password') ?? '',
      mailruLogin: prefs.getString('mailru_login') ?? '',
      mailruPassword: prefs.getString('mailru_password') ?? '',
      updateIntervalSec: prefs.getInt('update_interval') ?? 30,
      enabled: prefs.getBool('enabled') ?? false,
    );
  }

  Future<void> update(GeoSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone_id', settings.phoneId);
    await prefs.setString('phone_name', settings.phoneName);
    await prefs.setString('local_mqtt_host', settings.localMqttHost);
    await prefs.setInt('local_mqtt_port', settings.localMqttPort);
    await prefs.setString('cloud_mqtt_host', settings.cloudMqttHost);
    await prefs.setInt('cloud_mqtt_port', settings.cloudMqttPort);
    await prefs.setString('cloud_mqtt_user', settings.cloudMqttUser);
    await prefs.setString('cloud_mqtt_password', settings.cloudMqttPassword);
    await prefs.setString('mailru_login', settings.mailruLogin);
    await prefs.setString('mailru_password', settings.mailruPassword);
    await prefs.setInt('update_interval', settings.updateIntervalSec);
    await prefs.setBool('enabled', settings.enabled);
  }
}