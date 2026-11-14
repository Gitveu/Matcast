import 'package:flutter/material.dart';

class GuideView extends StatelessWidget {
  const GuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Руководство по трансляции из шторки Android'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Intro Alert Card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Как устроена нативная трансляция в Android',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Шторка быстрых настроек Android использует два независимых протокола:\n'
                          '• Google Cast (Chromecast v2): вещание mDNS _googlecast._tcp на порту 8009.\n'
                          '• Miracast / Wi-Fi Display (WFD): сигнальный протокол RTSP на порту 7236.\n'
                          'Оба протокола работают в Matcast параллельно без заглушек.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: AOSP / Custom ROMs
          _buildDeviceSection(
            context,
            icon: Icons.android,
            title: '1. AOSP-подобные прошивки (LineageOS, crDroid, Pixel, чистый Android)',
            color: Colors.green,
            steps: [
              'Убедитесь, что ПК и телефон в одной Wi-Fi сети (или телефон в той же подсети, что и ПК).',
              'Смахните шторку быстрых настроек и нажмите «Трансляция экрана».',
              'Если устройства не найдены («Поиск устройств...»), нажмите кнопку «Настройки» в диалоге.',
              'В открывшемся окне нажмите три точки в правом верхнем углу (Меню).',
              'ОБЯЗАТЕЛЬНО отметьте галочку «Включить беспроводной дисплей» (Enable wireless display). Это активирует Miracast/WFD поиск в AOSP!',
              'В списке появится «Matcast-PC». Нажмите для запуска трансляции.',
            ],
            note: 'В чистом AOSP без установленной галочки «Включить беспроводной дисплей» сканирование Wi-Fi Display выключено на уровне системы!',
          ),
          const SizedBox(height: 20),

          // Section 2: Samsung Galaxy
          _buildDeviceSection(
            context,
            icon: Icons.smartphone,
            title: '2. Samsung Galaxy (One UI)',
            color: Colors.blueAccent,
            steps: [
              'Смахните панель быстрых настроек двумя пальцами.',
              'Нажмите на плитку «Smart View».',
              'Телефон начнёт поиск Miracast / Wi-Fi Display приёмников.',
              'Выберите «Matcast-PC» в списке доступных экранов.',
              'Нажмите «Начать сейчас». Поток RTSP пойдёт на порт 7236.',
            ],
          ),
          const SizedBox(height: 20),

          // Section 3: Xiaomi / Redmi / POCO
          _buildDeviceSection(
            context,
            icon: Icons.cell_tower,
            title: '3. Xiaomi / POCO / Redmi (HyperOS / MIUI)',
            color: Colors.deepOrangeAccent,
            steps: [
              'Откройте шторку Центра управления.',
              'Нажмите плитку «Трансляция» (или «Беспроводной дисплей» в Подключение и общий доступ).',
              'Выберите «Matcast-PC» в списке.',
            ],
          ),
          const SizedBox(height: 20),

          // Section 4: Troubleshooting
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
                      const Icon(Icons.build_circle_outlined, color: Colors.amber),
                      const SizedBox(width: 12),
                      Text(
                        'Чек-лист решения проблем с обнаружением',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _troubleshootItem('Компьютер подключён по кабелю (Ethernet), а телефон по Wi-Fi', 'Убедитесь, что в роутере не включена «Изоляция клиентов» (AP Isolation / Client Isolation) и локальная сеть не разделена на гостевую.'),
                  _troubleshootItem('В Windows не открываются настройки проецирования', 'В Windows 11 по умолчанию отсутствует компонент «Беспроводной дисплей». Перейдите во вкладку «Протоколы» и нажмите «Установить через DISM».'),
                  _troubleshootItem('Брандмауэр Windows', 'Нажмите «Разрешить порты в брандмауэре» во вкладке «Протоколы», чтобы открыть порты TCP 8009, 7236 и UDP 5353, 19999.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<String> steps,
    String? note,
  }) {
    final theme = Theme.of(context);

    return Card(
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (note != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  note,
                  style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _troubleshootItem(String problem, String solution) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $problem:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(solution, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
