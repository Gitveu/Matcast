import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  String _receiverName = 'Matcast-PC';
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

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final file = File('matcast_settings.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['receiverName'] != null) _receiverName = map['receiverName'].toString();
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
        return;
      }
    } catch (_) {}

    _initDefaults();
  }

  void _saveSettings() {
    try {
      final file = File('matcast_settings.json');
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
      }));
    } catch (_) {}
  }

  void _initDefaults() {
    try {
      final host = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      if (host.isNotEmpty) {
        _receiverName = 'Matcast-$host';
      }
    } catch (_) {}
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
  String get resolutionLabel => '${_targetWidth}x$_targetHeight';

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
