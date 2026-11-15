import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

enum AppLanguage { system, en, ru }

class SettingsProvider with ChangeNotifier {
  String _receiverName = 'Matcast';
  bool _autoStart = true;
  int _castPort = 8009;
  int _miracastPort = 7236;
  int _rtpPort = 19999;
  bool _enableGoogleCast = true;
  bool _enableMiracast = true;
  bool _hardwareDecoding = true;
  bool _autoFullScreenOnConnect = false;
  ThemeMode _themeMode = ThemeMode.dark;
  int _targetWidth = 1920;
  int _targetHeight = 1080;
  int _targetFps = 60;
  AppLanguage _appLanguage = AppLanguage.system;
  Map<String, String> _deviceAliases = {};

  SettingsProvider() {
    _loadSettings();
  }

  static File _getSettingsFile() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final file = File('$exeDir/matcast_settings.json');
      if (file.existsSync()) return file;
      final cur = File('matcast_settings.json');
      if (cur.existsSync()) return cur;
      return file;
    } catch (_) {
      return File('matcast_settings.json');
    }
  }

  void _loadSettings() {
    try {
      final file = _getSettingsFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['receiverName'] != null) {
          final n = map['receiverName'].toString().trim();
          if (n.isNotEmpty) _receiverName = n;
        }
        if (map['autoStart'] != null) _autoStart = map['autoStart'] as bool;
        if (map['castPort'] != null) _castPort = (map['castPort'] as num).toInt();
        if (map['miracastPort'] != null) _miracastPort = (map['miracastPort'] as num).toInt();
        if (map['rtpPort'] != null) _rtpPort = (map['rtpPort'] as num).toInt();
        if (map['enableGoogleCast'] != null) _enableGoogleCast = map['enableGoogleCast'] as bool;
        if (map['enableMiracast'] != null) _enableMiracast = map['enableMiracast'] as bool;
        if (map['hardwareDecoding'] != null) _hardwareDecoding = map['hardwareDecoding'] as bool;
        if (map['autoFullScreenOnConnect'] != null) _autoFullScreenOnConnect = map['autoFullScreenOnConnect'] as bool;
        if (map['themeMode'] != null) {
          final idx = (map['themeMode'] as num).toInt();
          if (idx >= 0 && idx < ThemeMode.values.length) {
            _themeMode = ThemeMode.values[idx];
          }
        }
        if (map['targetWidth'] != null) _targetWidth = (map['targetWidth'] as num).toInt();
        if (map['targetHeight'] != null) _targetHeight = (map['targetHeight'] as num).toInt();
        if (map['targetFps'] != null) _targetFps = (map['targetFps'] as num).toInt();
        if (map['appLanguage'] != null) {
          final lIdx = (map['appLanguage'] as num).toInt();
          if (lIdx >= 0 && lIdx < AppLanguage.values.length) {
            _appLanguage = AppLanguage.values[lIdx];
          }
        }
        if (map['deviceAliases'] != null && map['deviceAliases'] is Map) {
          _deviceAliases = Map<String, String>.from(
            (map['deviceAliases'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
        return;
      }
    } catch (_) {}

    _initDefaults();
  }

  void _saveSettings() {
    try {
      final file = _getSettingsFile();
      file.writeAsStringSync(jsonEncode({
        'receiverName': _receiverName,
        'autoStart': _autoStart,
        'castPort': _castPort,
        'miracastPort': _miracastPort,
        'rtpPort': _rtpPort,
        'enableGoogleCast': _enableGoogleCast,
        'enableMiracast': _enableMiracast,
        'hardwareDecoding': _hardwareDecoding,
        'autoFullScreenOnConnect': _autoFullScreenOnConnect,
        'themeMode': _themeMode.index,
        'targetWidth': _targetWidth,
        'targetHeight': _targetHeight,
        'targetFps': _targetFps,
        'appLanguage': _appLanguage.index,
        'deviceAliases': _deviceAliases,
      }));
    } catch (_) {}
  }

  void _initDefaults() {
    _receiverName = 'Matcast';
    _saveSettings();
  }

  String get receiverName => _receiverName;
  bool get autoStart => _autoStart;
  int get castPort => _castPort;
  int get miracastPort => _miracastPort;
  int get rtpPort => _rtpPort;
  bool get enableGoogleCast => _enableGoogleCast;
  bool get enableMiracast => _enableMiracast;
  bool get hardwareDecoding => _hardwareDecoding;
  bool get autoFullScreenOnConnect => _autoFullScreenOnConnect;
  ThemeMode get themeMode => _themeMode;
  int get targetWidth => _targetWidth;
  int get targetHeight => _targetHeight;
  int get targetFps => _targetFps;
  AppLanguage get appLanguage => _appLanguage;
  String get resolutionLabel => '${_targetWidth}x$_targetHeight';
  Map<String, String> get deviceAliases => Map.unmodifiable(_deviceAliases);

  String? getDeviceAlias(String ip) => _deviceAliases[ip];

  void setDeviceAlias(String ip, String alias) {
    final clean = alias.trim();
    if (clean.isEmpty) {
      _deviceAliases.remove(ip);
    } else {
      _deviceAliases[ip] = clean;
    }
    _saveSettings();
    notifyListeners();
  }

  AppStrings tr(BuildContext context) => AppStrings(_appLanguage, context);

  void setResolution(int width, int height) {
    _targetWidth = width;
    _targetHeight = height;
    _saveSettings();
    notifyListeners();
  }

  void setFps(int fps) {
    _targetFps = fps;
    _saveSettings();
    notifyListeners();
  }

  void setAppLanguage(AppLanguage lang) {
    _appLanguage = lang;
    _saveSettings();
    notifyListeners();
  }

  void setReceiverName(String name) {
    final clean = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    if (clean.isNotEmpty) {
      _receiverName = clean;
      _saveSettings();
      notifyListeners();
    }
  }

  void setAutoStart(bool value) {
    _autoStart = value;
    _saveSettings();
    notifyListeners();
  }

  void setCastPort(int port) {
    _castPort = port;
    _saveSettings();
    notifyListeners();
  }

  void setMiracastPort(int port) {
    _miracastPort = port;
    _saveSettings();
    notifyListeners();
  }

  void setRtpPort(int port) {
    _rtpPort = port;
    _saveSettings();
    notifyListeners();
  }

  void setEnableGoogleCast(bool value) {
    _enableGoogleCast = value;
    _saveSettings();
    notifyListeners();
  }

  void setEnableMiracast(bool value) {
    _enableMiracast = value;
    _saveSettings();
    notifyListeners();
  }

  void setHardwareDecoding(bool value) {
    _hardwareDecoding = value;
    _saveSettings();
    notifyListeners();
  }

  void setAutoFullScreenOnConnect(bool value) {
    _autoFullScreenOnConnect = value;
    _saveSettings();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }
}
