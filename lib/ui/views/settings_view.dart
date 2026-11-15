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
    final strings = settings.tr(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tabSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Section 1: General Settings
          Text(
            strings.sectionGeneral,
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
                  title: Text(strings.receiverNameTitle),
                  subtitle: Text(settings.receiverName),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: strings.editNameTitle,
                    onPressed: () => _showEditNameDialog(context, settings),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(strings.languageTitle),
                  trailing: SegmentedButton<AppLanguage>(
                    segments: [
                      ButtonSegment(value: AppLanguage.system, label: Text(strings.langSystem)),
                      ButtonSegment(value: AppLanguage.en, label: Text(strings.langEn)),
                      ButtonSegment(value: AppLanguage.ru, label: Text(strings.langRu)),
                    ],
                    selected: {settings.appLanguage},
                    onSelectionChanged: (set) => settings.setAppLanguage(set.first),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: Text(strings.autoStartTitle),
                  subtitle: Text(strings.autoStartSubtitle),
                  value: settings.autoStart,
                  onChanged: (val) => settings.setAutoStart(val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fullscreen),
                  title: Text(strings.autoFullscreenTitle),
                  subtitle: Text(strings.autoFullscreenSubtitle),
                  value: settings.autoFullScreenOnConnect,
                  onChanged: (val) => settings.setAutoFullScreenOnConnect(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Video & Hardware Acceleration
          Text(
            strings.sectionVideo,
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
                  title: Text(strings.hwAccelTitle),
                  subtitle: Text(strings.hwAccelSubtitle),
                  value: settings.hardwareDecoding,
                  onChanged: (val) => settings.setHardwareDecoding(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.aspect_ratio),
                  title: Text(strings.resolutionTitle),
                  subtitle: Text(strings.resolutionSubtitle),
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
                  title: Text(strings.fpsTitle),
                  subtitle: Text(strings.fpsSubtitle),
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
                  title: Text(strings.bufferTitle),
                  subtitle: Text(strings.bufferSubtitle),
                  trailing: Chip(
                    label: const Text('Low Latency'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Material 3 Appearance & Language
          Text(
            strings.sectionAppearance,
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
                // Theme
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.brightness_4_outlined),
                      const SizedBox(width: 16),
                      Text(
                        strings.themeTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(value: ThemeMode.dark, label: Text(strings.themeDark), icon: const Icon(Icons.dark_mode)),
                          ButtonSegment(value: ThemeMode.light, label: Text(strings.themeLight), icon: const Icon(Icons.light_mode)),
                          ButtonSegment(value: ThemeMode.system, label: Text(strings.themeSystem), icon: const Icon(Icons.brightness_auto)),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (set) => settings.setThemeMode(set.first),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Network Ports
          Text(
            strings.sectionPorts,
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
                  title: Text(strings.castPortTitle),
                  subtitle: const Text('Google Cast V2 TLS (TCP)'),
                  trailing: Text('${settings.castPort}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: Text(strings.miracastPortTitle),
                  subtitle: const Text('Wi-Fi Display RTSP (TCP)'),
                  trailing: Text('${settings.miracastPort}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider settings) {
    final strings = settings.tr(context);
    final controller = TextEditingController(text: settings.receiverName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.editNameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: strings.editNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.btnCancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<ReceiverProvider>().updateReceiverName(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(strings.btnSave),
          ),
        ],
      ),
    );
  }
}
