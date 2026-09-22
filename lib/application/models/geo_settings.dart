class GeoSettings {
  final String phoneId;
  final String phoneName;
  final String homeSsid;
  final String localMqttHost;
  final int localMqttPort;
  final String cloudMqttHost;
  final int cloudMqttPort;
  final String cloudMqttUser;
  final String cloudMqttPassword;
  final String mailruLogin;
  final String mailruPassword;
  final int updateIntervalSec;
  final bool enabled;

  GeoSettings({
    this.phoneId = '',
    this.phoneName = '',
    this.homeSsid = '',
    this.localMqttHost = '192.168.1.100',
    this.localMqttPort = 1883,
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
    String? phoneId,
    String? phoneName,
    String? homeSsid,
    String? localMqttHost,
    int? localMqttPort,
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
      phoneId: phoneId ?? this.phoneId,
      phoneName: phoneName ?? this.phoneName,
      homeSsid: homeSsid ?? this.homeSsid,
      localMqttHost: localMqttHost ?? this.localMqttHost,
      localMqttPort: localMqttPort ?? this.localMqttPort,
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