import 'package:flutter/material.dart';
import '../state/settings_provider.dart';

class AppStrings {
  final AppLanguage language;
  final bool isEn;

  AppStrings(this.language, BuildContext context)
      : isEn = language == AppLanguage.en ||
            (language == AppLanguage.system &&
                (View.of(context).platformDispatcher.locale.languageCode.toLowerCase() != 'ru'));

  static AppStrings of(BuildContext context) {
    // We will obtain settings from Provider
    return AppStrings(AppLanguage.system, context);
  }

  // Navigation
  String get tabScreen => isEn ? 'Screen' : 'Экран';
  String get tabDevices => isEn ? 'Devices' : 'Устройства';
  String get tabSettings => isEn ? 'Settings' : 'Настройки';

  // Display View
  String get waitingTitle => isEn ? 'Waiting for Cast Signal' : 'Ожидание сигнала трансляции';
  String waitingSubtitle(String name, String ip) => isEn
      ? 'Pull down the notification shade on Android and tap "Cast".\n'
          '"$name" will appear in the device list.\n'
          'Receiver is listening on $ip.'
      : 'Потяните шторку вниз на телефоне Android и нажмите «Трансляция».\n'
          'В списке устройств появится «$name».\n'
          'Приёмник ожидает подключение на $ip.';

  String get statReceiverName => isEn ? 'RECEIVER NAME (MDNS)' : 'ИМЯ ПРИЁМНИКА (MDNS)';
  String get statLanIp => isEn ? 'LAN IP FOR CONNECTION' : 'LAN IP ДЛЯ ПОДКЛЮЧЕНИЯ';
  String statPorts(int cast, int miracast) => isEn
      ? 'Ports: $cast (Google Cast) / $miracast (RTSP)'
      : 'Порты: $cast (Google Cast) / $miracast (RTSP)';
  String get statDiscovery => isEn ? 'DISCOVERY SERVICE' : 'СЛУЖБА ОБНАРУЖЕНИЯ';
  String get statDiscoveryActive => isEn ? 'Broadcasting active (UDP 5353)' : 'Вещание активно (UDP 5353)';
  String get statDiscoveryStarting => isEn ? 'Starting...' : 'Запуск...';
  String get btnRestartReceiver => isEn ? 'Restart Receiver Service' : 'Перезапустить службу приёмника';

  String get tooltipMute => isEn ? 'Unmute' : 'Включить звук';
  String get tooltipUnmute => isEn ? 'Mute' : 'Выключить звук';
  String tooltipRotate(int angle) => isEn ? 'Rotate Screen ($angle°)' : 'Повернуть экран ($angle°)';
  String get tooltipHud => isEn ? 'Stream Stats (HUD)' : 'Статистика стрима (HUD)';
  String get tooltipFullscreenEnter => isEn ? 'Full Screen (F11)' : 'Во весь экран (F11)';
  String get tooltipFullscreenExit => isEn ? 'Exit Full Screen (Esc)' : 'Выйти из полноэкранного режима (Esc)';
  String get btnDisconnect => isEn ? 'Disconnect' : 'Отключить';

  // Devices View
  String get devicesTitle => isEn ? 'Devices & Activity' : 'Устройства и Активность';
  String get sectionActiveConnection => isEn ? 'ACTIVE CONNECTION' : 'АКТИВНОЕ ПОДКЛЮЧЕНИЕ';
  String get noActiveConnections => isEn ? 'No active connections' : 'Нет активных подключений';
  String get readyPrompt => isEn
      ? 'Receiver is ready. Select this device on your phone.'
      : 'Приёмник готов к трансляции. Выберите устройство на телефоне.';
  String get sectionHistory => isEn ? 'CONNECTION HISTORY' : 'ИСТОРИЯ ПОДКЛЮЧЕНИЙ';
  String get historyEmpty => isEn ? 'History is empty' : 'История пуста';
  String get liveProtocol => isEn ? 'Protocol Journal (Live Protocol)' : 'Журнал обмена данными (Live Protocol)';
  String get btnCopy => isEn ? 'Copy' : 'Копировать';
  String get btnClear => isEn ? 'Clear' : 'Очистить';
  String get noProtocolEvents => isEn
      ? 'No protocol events.\nWaiting for mobile device connection...'
      : 'События протокола отсутствуют.\nОжидание подключения Android-устройства...';
  String get activeStatus => isEn ? 'Streaming active' : 'Идёт трансляция';

  // Settings View
  String get sectionGeneral => isEn ? 'GENERAL & DISCOVERY' : 'ОБЩИЕ И СЕТЕВОЕ ОБНАРУЖЕНИЕ';
  String get receiverNameTitle => isEn ? 'Receiver Name on Network' : 'Имя приёмника в сети';
  String get autoStartTitle => isEn ? 'Autostart receiver on launch' : 'Автозапуск приёмника при старте приложения';
  String get autoStartSubtitle => isEn ? 'Start Cast services automatically on startup' : 'Автоматически поднимать серверы Cast и RTSP';
  String get autoFullscreenTitle => isEn ? 'Fullscreen on connect' : 'Полноэкранный режим при подключении';
  String get autoFullscreenSubtitle => isEn ? 'Expand window to full screen when stream starts' : 'Разворачивать окно на весь экран при начале стрима';

  String get sectionVideo => isEn ? 'VIDEO & DECODING' : 'ВИДЕО И ДЕКОДИРОВАНИЕ';
  String get hwAccelTitle => isEn ? 'Hardware Acceleration (GPU)' : 'Аппаратное ускорение (GPU)';
  String get hwAccelSubtitle => isEn ? 'Use Direct3D 11 / DXVA2 for H.264/HEVC decoding' : 'Использовать Direct3D 11 / DXVA2 для декодирования H.264/HEVC';
  String get resolutionTitle => isEn ? 'Stream Resolution' : 'Разрешение трансляции';
  String get resolutionSubtitle => isEn ? 'Target resolution for stream receiver engine' : 'Целевое разрешение для движка приёма потока';
  String get fpsTitle => isEn ? 'Target Frame Rate (FPS)' : 'Частота кадров (FPS)';
  String get fpsSubtitle => isEn ? 'Target display refresh rate' : 'Целевая частота обновления экрана';
  String get showHudTitle => isEn ? 'Stream Stats Overlay (HUD)' : 'Оверлей статистики потока (HUD)';
  String get showHudSubtitle => isEn ? 'Show real-time FPS, bitrate, and latency on stream' : 'Отображать FPS, битрейт и задержку поверх видео';

  String get sectionAppearance => isEn ? 'APPEARANCE & LANGUAGE' : 'ВНЕШНИЙ ВИД И ЯЗЫК';
  String get themeTitle => isEn ? 'Color Theme' : 'Тема оформления';
  String get themeDark => isEn ? 'Dark' : 'Тёмная';
  String get themeLight => isEn ? 'Light' : 'Светлая';
  String get themeSystem => isEn ? 'System' : 'Системная';
  String get languageTitle => isEn ? 'Language' : 'Язык интерфейса';
  String get langSystem => isEn ? 'System' : 'Системный';
  String get langEn => 'English';
  String get langRu => 'Русский';

  String get sectionPorts => isEn ? 'NETWORK PORTS & ENGINES' : 'СЕТЕВЫЕ ПОРТЫ И ПРОТОКОЛЫ';
  String get castPortTitle => isEn ? 'Google Cast V2 Port' : 'Порт Google Cast V2';
  String get airplayPortTitle => isEn ? 'Apple AirPlay RTSP Port' : 'Порт Apple AirPlay RTSP';
  String get miracastPortTitle => isEn ? 'Miracast RTSP Port' : 'Порт Miracast RTSP';

  // Section About
  String get sectionAbout => isEn ? 'ABOUT & SOURCE CODE' : 'О ПРОГРАММЕ И ИСХОДНЫЙ КОД';
  String get repositorySubtitle => isEn ? 'GitHub Repository' : 'Репозиторий на GitHub';

  // Dialogs
  String get editNameTitle => isEn ? 'Edit Receiver Name' : 'Изменить имя приёмника';
  String get editNameHint => isEn ? 'e.g. Living-Room-PC' : 'например, Matcast-PC';
  String get renameDeviceTitle => isEn ? 'Rename Device' : 'Переименовать устройство';
  String get renameDeviceHint => isEn ? 'e.g. My Phone, Living Room Tablet' : 'например, Мой телефон, Планшет';
  String get durationLabel => isEn ? 'Duration' : 'Длительность';
  String get connectedLabel => isEn ? 'Connected' : 'Подключено';
  String get btnCancel => isEn ? 'Cancel' : 'Отмена';
  String get btnSave => isEn ? 'Save' : 'Сохранить';
  String get restartRequiredTitle => isEn ? 'Restart Required' : 'Требуется перезапуск';
  String get restartRequiredMessage => isEn
      ? 'To broadcast the new receiver name to phones and AirPlay, the application needs to restart.'
      : 'Чтобы применить новое имя приёмника в сети для телефонов и AirPlay, приложению требуется перезапуск.';
  String get btnRestartNow => isEn ? 'Restart Now' : 'Перезапустить сейчас';
  String get btnLater => isEn ? 'Later' : 'Позже';
  String get copiedSnackbar => isEn ? 'Logs copied to clipboard' : 'Журнал скопирован в буфер обмена';
}
