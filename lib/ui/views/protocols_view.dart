import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/windows_projection_helper.dart';
import '../../state/receiver_provider.dart';

class ProtocolsView extends StatelessWidget {
  const ProtocolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ReceiverProvider>();
    final settings = provider.settings;
    final strings = settings.tr(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.protocolsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            strings.sectionProtocols,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Google Cast V2 Card
          _buildProtocolCard(
            context,
            icon: Icons.cast,
            title: 'Google Cast V2 Engine',
            subtitle: strings.googleCastDesc,
            isActive: settings.enableGoogleCast,
            statusBadge: 'mDNS + TLS :${settings.castPort}',
            color: Colors.blueAccent,
            details: [
              _detailRow(strings.discoveryServiceLabel, 'mDNS (_googlecast._tcp.local) on ${provider.localIp}'),
              _detailRow(strings.controlPortLabel, '${settings.castPort} (TLS Socket)'),
              _detailRow(strings.cryptoCertLabel, 'RSA 2048-bit (assets/certs/cert.pem)'),
              _detailRow(strings.supportedChannelsLabel, 'Heartbeat, Connection, Receiver, WebRTC Stream'),
            ],
            onToggle: (val) {
              settings.setEnableGoogleCast(val);
              provider.stopReceiver().then((_) => provider.startReceiver());
            },
          ),
          const SizedBox(height: 16),

          // 2. Apple AirPlay / Screen Mirroring
          _buildProtocolCard(
            context,
            icon: Icons.apple,
            title: 'Apple AirPlay (Screen Mirroring & Audio)',
            subtitle: strings.airplayDesc,
            isActive: true,
            statusBadge: 'RTSP :7000 | RAOP :7000',
            color: Colors.orangeAccent,
            details: [
              _detailRow(strings.discoveryServiceLabel, 'Bonjour / mDNS (_airplay._tcp & _raop._tcp)'),
              _detailRow(strings.mirrorPortLabel, '7000 (RTSP / AirPlay)'),
              _detailRow(strings.audioProtocolLabel, 'RAOP (Remote Audio Output Protocol)'),
              _detailRow(strings.hwRenderingLabel, 'DirectX 11 (Hardware Texture DXVA2)'),
            ],
            onToggle: null,
          ),
          const SizedBox(height: 16),

          // 3. Miracast / Wi-Fi Display Card
          _buildProtocolCard(
            context,
            icon: Icons.settings_remote,
            title: 'Miracast (Wi-Fi Display / RTSP)',
            subtitle: strings.miracastDesc,
            isActive: settings.enableMiracast,
            statusBadge: 'RTSP :${settings.miracastPort} | RTP :${settings.rtpPort}',
            color: Colors.deepPurpleAccent,
            details: [
              _detailRow(strings.controlPortLabel, '${settings.miracastPort} (RTSP TCP)'),
              _detailRow('RTP Video Port', '${settings.rtpPort} (UDP)'),
              _detailRow(strings.videoFormatLabel, 'H.264 MPEG-TS / AAC-LC'),
              _detailRow(strings.connTypeLabel, 'Wi-Fi Direct / Miracast over Infrastructure (MS-MICE)'),
            ],
            onToggle: (val) {
              settings.setEnableMiracast(val);
              provider.stopReceiver().then((_) => provider.startReceiver());
            },
          ),
          const SizedBox(height: 16),

          // 3. Windows Native Projection Integration
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.screen_share, color: Colors.teal),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Подсистема беспроводного дисплея Windows (Miracast Receiver)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Системный компонент «Беспроводной дисплей» (Connect) установлен в Windows',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: const Text('Установлен'),
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => WindowsProjectionHelper.launchConnectApp(),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Запустить «Беспроводной дисплей» Windows'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => WindowsProjectionHelper.openOptionalFeatures(),
                        icon: const Icon(Icons.extension),
                        label: const Text('Дополнительные компоненты Windows'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Windows Firewall Assistant
          Card(
            elevation: 1,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security, color: Colors.amber),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Брандмауэр Windows (Firewall Permissions)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Для приёма трансляции открыты порты TCP 8009, 7236 и UDP 5353, 19999',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final ok = await WindowsProjectionHelper.openFirewallPorts();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Правила брандмауэра успешно зарегистрированы!'
                                      : 'Запрос на открытие портов выполнен.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.shield, size: 18),
                        label: const Text('Разрешить порты в брандмауэре'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required String statusBadge,
    required Color color,
    required List<Widget> details,
    ValueChanged<bool>? onToggle,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusBadge),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 8),
                if (onToggle != null)
                  Switch(
                    value: isActive,
                    onChanged: onToggle,
                  )
                else
                  Chip(
                    label: const Text('Включен'),
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...details,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
