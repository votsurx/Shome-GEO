class GeoSettings {
  final String shomeHost;
  final String phoneId;
  final String phoneName;
  final String homeSsid;
  final String cloudMqttHost;
  final int cloudMqttPort;
  final String cloudMqttUser;
  final String cloudMqttPassword;
  final String mailruLogin;
  final String mailruPassword;
  final int updateIntervalSec;
  final bool enabled;

  GeoSettings({
    this.shomeHost = '192.168.1.100',
    this.phoneId = '',
    this.phoneName = '',
    this.homeSsid = '',
    this.cloudMqttHost = '',
    this.cloudMqttPort = 8883,
    this.cloudMqttUser = '',
    this.cloudMqttPassword = '',
    this.mailruLogin = '',
    this.mailruPassword = '',
    this.updateIntervalSec = 30,
    this.enabled = true,
  });

  bool get isConfigured => phoneId.isNotEmpty;

  GeoSettings copyWith({
    String? shomeHost,
    String? phoneId,
    String? phoneName,
    String? homeSsid,
    String? cloudMqttHost,
    int? cloudMqttPort,
    String? cloudMqttUser,
    String? cloudMqttPassword,
    String? mailruLogin,
    String? mailruPassword,
    int? updateIntervalSec,
    bool? enabled,
  }) {
    return GeoSettings(
      shomeHost: shomeHost ?? this.shomeHost,
      phoneId: phoneId ?? this.phoneId,
      phoneName: phoneName ?? this.phoneName,
      homeSsid: homeSsid ?? this.homeSsid,
      cloudMqttHost: cloudMqttHost ?? this.cloudMqttHost,
      cloudMqttPort: cloudMqttPort ?? this.cloudMqttPort,
      cloudMqttUser: cloudMqttUser ?? this.cloudMqttUser,
      cloudMqttPassword: cloudMqttPassword ?? this.cloudMqttPassword,
      mailruLogin: mailruLogin ?? this.mailruLogin,
      mailruPassword: mailruPassword ?? this.mailruPassword,
      updateIntervalSec: updateIntervalSec ?? this.updateIntervalSec,
      enabled: enabled ?? this.enabled,
    );
  }
}