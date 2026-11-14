import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/receiver_provider.dart';
import '../../state/settings_provider.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки Matcast'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Section 1: General Settings
          Text(
            'ОСНОВНЫЕ ПАРАМЕТРЫ',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Имя приёмника в сети'),
                  subtitle: Text(settings.receiverName),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditNameDialog(context, settings),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: const Text('Автозапуск серверов при открытии'),
                  subtitle: const Text('Автоматически поднимать mDNS и сетевые сокеты при старте приложения'),
                  value: settings.autoStart,
                  onChanged: (val) => settings.setAutoStart(val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fullscreen),
                  title: const Text('Автоматический полный экран'),
                  subtitle: const Text('Разворачивать окно на весь экран при начале трансляции'),
                  value: settings.autoFullScreenOnConnect,
                  onChanged: (val) => settings.setAutoFullScreenOnConnect(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Video & Hardware Acceleration
          Text(
            'ВИДЕО И ДЕКОДИРОВАНИЕ',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.memory),
                  title: const Text('Аппаратное ускорение (GPU)'),
                  subtitle: const Text('Использовать Direct3D 11 / DXVA2 для декодирования H.264/HEVC'),
                  value: settings.hardwareDecoding,
                  onChanged: (val) => settings.setHardwareDecoding(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.aspect_ratio),
                  title: const Text('Разрешение трансляции'),
                  subtitle: const Text('Целевое разрешение для движка приёма потока'),
                  trailing: DropdownButton<String>(
                    value: '${settings.targetWidth}x${settings.targetHeight}',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: '1920x1080',
                        child: Text('1080p (1920×1080)'),
                      ),
                      DropdownMenuItem(
                        value: '1280x720',
                        child: Text('720p (1280×720)'),
                      ),
                      DropdownMenuItem(
                        value: '2560x1440',
                        child: Text('2K (2560×1440)'),
                      ),
                      DropdownMenuItem(
                        value: '3840x2160',
                        child: Text('4K (3840×2160)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final parts = val.split('x');
                        final w = int.parse(parts[0]);
                        final h = int.parse(parts[1]);
                        context.read<ReceiverProvider>().updateStreamQuality(width: w, height: h);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.slow_motion_video),
                  title: const Text('Частота кадров (FPS)'),
                  subtitle: const Text('Целевая частота обновления экрана'),
                  trailing: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30 FPS')),
                      ButtonSegment(value: 60, label: Text('60 FPS')),
                    ],
                    selected: {settings.targetFps},
                    onSelectionChanged: (set) {
                      context.read<ReceiverProvider>().updateStreamQuality(fps: set.first);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('Буфер потока низких задержек'),
                  subtitle: const Text('32 МБ для минимального инпут-лага при зеркалировании'),
                  trailing: Chip(
                    label: const Text('Low Latency'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Material 3 Appearance
          Text(
            'ВНЕШНИЙ ВИД (MATERIAL DESIGN 3)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.brightness_4_outlined),
                  const SizedBox(width: 16),
                  Text(
                    'Тема оформления',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная'), icon: Icon(Icons.dark_mode)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Светлая'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.system, label: Text('Системная'), icon: Icon(Icons.brightness_auto)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) => settings.setThemeMode(set.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Network Ports
          Text(
            'СЕТЕВЫЕ ПОРТЫ СЕРВЕРОВ',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: const Text('Google Cast TLS Port'),
                  subtitle: const Text('Стандартный порт протокола Google Cast V2'),
                  trailing: Text('${settings.castPort}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: const Text('Miracast RTSP Port'),
                  subtitle: const Text('Порт сигнализации Wi-Fi Display (WFD1.0)'),
                  trailing: Text('${settings.miracastPort}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: const Text('RTP Streaming UDP Port'),
                  subtitle: const Text('Порт приёма видеопотока MPEG-TS H.264'),
                  trailing: Text('${settings.rtpPort}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.receiverName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Имя приёмника'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Название в шторке Android',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<ReceiverProvider>().updateReceiverName(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
