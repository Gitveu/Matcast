import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/cast_device.dart';
import '../../state/receiver_provider.dart';

class DevicesView extends StatelessWidget {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ReceiverProvider>();
    final state = provider.state;
    final activeDevice = state.activeDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства и Активность'),
        actions: [
          if (provider.protocolLogs.isNotEmpty) ...[
            FilledButton.tonalIcon(
              onPressed: () {
                final logText = provider.protocolLogs.map((e) =>
                    '[${e.timestamp.toIso8601String()}] ${e.title}: ${e.data}').join('\n');
                Clipboard.setData(ClipboardData(text: logText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Журнал скопирован в буфер обмена')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Копировать'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Очистить журнал',
              onPressed: () {
                provider.clearProtocolLogs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Журнал очищен')),
                );
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Active & Recent Devices
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'АКТИВНОЕ ПОДКЛЮЧЕНИЕ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (activeDevice != null)
                  _buildActiveDeviceCard(context, provider, activeDevice)
                else
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phonelink_off,
                            size: 36,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Нет активных подключений',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Приёмник готов к трансляции. Выберите устройство на телефоне.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                Text(
                  'ИСТОРИЯ ПОДКЛЮЧЕНИЙ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (state.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'История пуста',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  )
                else
                  ...state.history.map((device) => _buildHistoryTile(context, device)),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // Right Column: Protocol Event Stream Log
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Журнал обмена данными (Live Protocol)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Badge(
                        label: Text('${provider.protocolLogs.length}'),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: provider.protocolLogs.isEmpty
                      ? Center(
                          child: Text(
                            'События протокола отсутствуют.\nОжидание подключения Android-устройства...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.protocolLogs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = provider.protocolLogs[index];
                            return _buildLogCard(context, log);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeviceCard(
    BuildContext context,
    ReceiverProvider provider,
    CastDevice device,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.phone_android, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IP: ${device.ipAddress}:${device.port}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(device.protocol.label),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Подключено: ${device.connectedAt.hour.toString().padLeft(2, '0')}:${device.connectedAt.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Отключить'),
                  onPressed: () => provider.disconnectActiveDevice(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, CastDevice device) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainer,
      child: ListTile(
        leading: const Icon(Icons.devices_other),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${device.ipAddress} • ${device.protocol.label}'),
        trailing: Text(
          '${device.connectedAt.hour.toString().padLeft(2, '0')}:${device.connectedAt.minute.toString().padLeft(2, '0')}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, dynamic log) {
    final theme = Theme.of(context);
    final isError = log.title.toLowerCase().contains('error');
    final isAuth = log.title.toLowerCase().contains('auth');

    Color badgeColor = theme.colorScheme.surfaceContainerHighest;
    if (isError) badgeColor = theme.colorScheme.errorContainer;
    if (isAuth) badgeColor = theme.colorScheme.tertiaryContainer;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        title: Text(
          log.title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.black.withValues(alpha: 0.2),
            child: Text(
              log.data.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
