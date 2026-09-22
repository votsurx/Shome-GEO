import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/models/geo_settings.dart';
import '../../application/state/geo_settings_provider.dart';
import '../../data/services/foreground_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(geoSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Включение ───
          SwitchListTile(
            title: const Text('Включить отслеживание'),
            subtitle: const Text('Автоматически отправлять координаты'),
            value: settings.enabled,
            onChanged: (val) {
              debugPrint('💾 Ползунок: enabled=$val');
              ref
                  .read(geoSettingsProvider.notifier)
                  .update(settings.copyWith(enabled: val));
            },
          ),
          const Divider(height: 32),

          // ─── Связка ───
          _buildCard(
            context: context,
            icon: Icons.phone_android,
            color: Colors.blue,
            title: 'Связка',
            subtitle: settings.phoneId.isEmpty
                ? 'Не настроено'
                : '${settings.phoneName} (${settings.phoneId})',
            onTap: () => _showPhoneDialog(context, ref, settings),
          ),

          // ─── Mail.ru ───
          _buildCard(
            context: context,
            icon: Icons.cloud,
            color: Colors.lightBlue,
            title: 'Mail.ru Cloud',
            subtitle: settings.mailruLogin.isEmpty
                ? 'Не настроено'
                : settings.mailruLogin,
            onTap: () => _showMailruDialog(context, ref, settings),
          ),

          // ─── Локальный MQTT ───
          _buildCard(
            context: context,
            icon: Icons.router,
            color: Colors.cyan,
            title: 'Shome (планшет)',
            subtitle: settings.shomeHost.isEmpty
                ? 'Не настроено'
                : settings.shomeHost,
            onTap: () => _showShomeHostDialog(context, ref, settings),
          ),

          // ─── Облачный MQTT ───
          _buildCard(
            context: context,
            icon: Icons.cloud_queue,
            color: Colors.purple,
            title: 'MQTT (облачный)',
            subtitle: settings.cloudMqttHost.isEmpty
                ? 'Не настроено'
                : '${settings.cloudMqttHost}:${settings.cloudMqttPort}',
            onTap: () => _showCloudMqttDialog(context, ref, settings),
          ),

          // ─── Интервал ───
          _buildCard(
            context: context,
            icon: Icons.timer,
            color: Colors.orange,
            title: 'Интервал отправки',
            subtitle: '${settings.updateIntervalSec} сек',
            onTap: () => _showIntervalDialog(context, ref, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ─── ДИАЛОГИ ───

  void _showPhoneDialog(
      BuildContext context, WidgetRef ref, GeoSettings settings) {
    final idCtrl = TextEditingController(text: settings.phoneId);
    final nameCtrl = TextEditingController(text: settings.phoneName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Связка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone ID',
                hintText: 'phone_1',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Мой телефон',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newId = idCtrl.text.trim();
              final newName = nameCtrl.text.trim();
              debugPrint('💾 Phone ID: $newId, Name: $newName');
              ref.read(geoSettingsProvider.notifier).update(
                settings.copyWith(
                  phoneId: newId,
                  phoneName: newName,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showMailruDialog(
      BuildContext context, WidgetRef ref, GeoSettings settings) {
    final loginCtrl = TextEditingController(text: settings.mailruLogin);
    final passCtrl = TextEditingController(text: settings.mailruPassword);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mail.ru Cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loginCtrl,
              decoration: const InputDecoration(
                labelText: 'Логин',
                hintText: 'user@mail.ru',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(
                labelText: 'Пароль для внешних приложений',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('💾 Mail.ru логин: ${loginCtrl.text.trim()}');
              ref.read(geoSettingsProvider.notifier).update(
                settings.copyWith(
                  mailruLogin: loginCtrl.text.trim(),
                  mailruPassword: passCtrl.text,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showShomeHostDialog(
      BuildContext context, WidgetRef ref, GeoSettings settings) {
    final ctrl = TextEditingController(text: settings.shomeHost);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shome (планшет)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'IP адрес',
            hintText: '192.168.1.100',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(geoSettingsProvider.notifier).update(
                settings.copyWith(shomeHost: ctrl.text.trim()),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }


  void _showCloudMqttDialog(
      BuildContext context, WidgetRef ref, GeoSettings settings) {
    final hostCtrl = TextEditingController(text: settings.cloudMqttHost);
    final portCtrl =
    TextEditingController(text: settings.cloudMqttPort.toString());
    final userCtrl = TextEditingController(text: settings.cloudMqttUser);
    final passCtrl = TextEditingController(text: settings.cloudMqttPassword);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Облачный MQTT'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: 'xxx.hivemq.cloud',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '8883',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(geoSettingsProvider.notifier).update(
                settings.copyWith(
                  cloudMqttHost: hostCtrl.text.trim(),
                  cloudMqttPort: int.tryParse(portCtrl.text) ?? 8883,
                  cloudMqttUser: userCtrl.text.trim(),
                  cloudMqttPassword: passCtrl.text,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showIntervalDialog(
      BuildContext context, WidgetRef ref, GeoSettings settings) {
    final ctrl =
    TextEditingController(text: settings.updateIntervalSec.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final interval = int.tryParse(ctrl.text) ?? 0;
          final isValid = interval >= 60;

          return AlertDialog(
            title: const Text('Интервал отправки'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Секунды',
                    hintText: '60',
                    helperText: 'Минимум 60 секунд',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setDialogState(() {});
                  },
                ),
                if (!isValid && ctrl.text.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Минимум 60 секунд',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: !isValid
                    ? null
                    : () async {
                  // Сохраняем настройки
                  await ref.read(geoSettingsProvider.notifier).update(
                    settings.copyWith(updateIntervalSec: interval),
                  );

                  // Перезапускаем сервис, если он запущен
                  if (await ForegroundServiceManager.isRunning()) {
                    debugPrint('🔄 Перезапуск сервиса');
                    await ForegroundServiceManager.restart(
                      intervalMs: interval * 1000,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}