import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OnStreamStateChanged = void Function({
  required bool isStreaming,
  int? textureId,
  String? deviceName,
  String? clientIp,
  int? width,
  int? height,
  int? fps,
  String? codec,
});

typedef OnStatsUpdate = void Function({
  double? bitrateKbps,
  int? decodeTimeUs,
  int? renderTimeUs,
});

typedef OnProtocolLog = void Function(String title, Map<String, dynamic> data);

class NativeCastBridge {
  static const MethodChannel _castChannel = MethodChannel('cast');
  static const MethodChannel _engineChannel = MethodChannel('matcast/native_engine');

  final OnStreamStateChanged onStreamStateChanged;
  final OnProtocolLog onProtocolLog;
  final OnStatsUpdate? onStatsUpdate;

  bool _isCurrentlyStreaming = false;
  bool get isCurrentlyStreaming => _isCurrentlyStreaming;
  int? _activeTextureId;
  String _activeDeviceName = 'Android Cast';
  String _activeClientIp = '';
  int _width = 1920;
  int _height = 1080;
  DateTime _lastDecodeLog = DateTime.fromMillisecondsSinceEpoch(0);

  NativeCastBridge({
    required this.onStreamStateChanged,
    required this.onProtocolLog,
    this.onStatsUpdate,
  }) {
    _initChannels();
  }

  static dynamic _sanitizeValue(dynamic val) {
    if (val is String) {
      return val
          .replaceAll(RegExp(r'pigeon_cast', caseSensitive: false), 'matcast_sys')
          .replaceAll(RegExp(r'pigeoncast', caseSensitive: false), 'Matcast')
          .replaceAll(RegExp(r'pigeon', caseSensitive: false), 'Matcast');
    } else if (val is Map) {
      return _sanitizeData(Map<String, dynamic>.from(val));
    } else if (val is List) {
      return val.map(_sanitizeValue).toList();
    }
    return val;
  }

  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> source) {
    final clean = <String, dynamic>{};
    source.forEach((k, v) {
      final cleanKey = k
          .replaceAll(RegExp(r'pigeon_cast', caseSensitive: false), 'matcast_sys')
          .replaceAll(RegExp(r'pigeoncast', caseSensitive: false), 'Matcast')
          .replaceAll(RegExp(r'pigeon', caseSensitive: false), 'Matcast');
      clean[cleanKey] = _sanitizeValue(v);
    });
    return clean;
  }

  void _log(String title, Map<String, dynamic> data) {
    final cleanTitle = title
        .replaceAll(RegExp(r'pigeon_cast', caseSensitive: false), 'matcast_sys')
        .replaceAll(RegExp(r'pigeoncast', caseSensitive: false), 'Matcast')
        .replaceAll(RegExp(r'pigeon', caseSensitive: false), 'Matcast');
    final cleanData = _sanitizeData(data);
    debugPrint('[NativeCastBridge] $cleanTitle: $cleanData');
    try {
      final line = '${DateTime.now().toIso8601String()} [$cleanTitle] ${jsonEncode(cleanData)}\n';
      File('matcast_dart.log').writeAsStringSync(line, mode: FileMode.append);
    } catch (_) {}
    onProtocolLog(cleanTitle, cleanData);
  }

  void _initChannels() {
    _castChannel.setMethodCallHandler(_handleCastPluginCall);
    _engineChannel.setMethodCallHandler(_handleNativeEngineCall);
  }

  Future<dynamic> _handleNativeEngineCall(MethodCall call) async {
    _log('NativeEngine Call: ${call.method}', {'arguments': call.arguments});
    return null;
  }

  Future<dynamic> _handleCastPluginCall(MethodCall call) async {
    if (call.method == 'json_call') {
      Map<String, dynamic> payload = {};
      if (call.arguments is String) {
        try {
          payload = jsonDecode(call.arguments as String);
        } catch (_) {}
      } else if (call.arguments is Map) {
        payload = Map<String, dynamic>.from(call.arguments as Map);
      }

      final rawType = payload['type']?.toString() ?? '';
      final rawData = payload['data'] is Map ? Map<String, dynamic>.from(payload['data'] as Map) : <String, dynamic>{};

      // Sanitize PigeonCast mentions to Matcast
      String type = rawType;
      if (type == 'OnPigeoncastRegistered' || type.toLowerCase().contains('pigeon')) {
        type = 'OnCastRegistered';
      }
      final data = _sanitizeData(rawData);

      // Log all state and control events immediately
      if (type != 'DecodeUpdate') {
        _log('CastPlugin Call: json_call', {'type': type, 'data': data});
      }

      switch (type) {
        case 'OnSetup':
          if (data['name'] != null) {
            _activeClientIp = data['name'].toString().trim();
            _activeDeviceName = _activeClientIp;
          }
          break;

        case 'OnVideoBegin':
        case 'DecodeStart':
          _isCurrentlyStreaming = true;
          break;

        case 'OnVideoSize':
          final textureVal = data['texture'];
          if (textureVal != null) {
            _activeTextureId = (textureVal as num).toInt();
          }
          if (data['width'] != null) {
            _width = (data['width'] as num).toInt();
          }
          if (data['height'] != null) {
            _height = (data['height'] as num).toInt();
          }
          final codec = data['codec']?.toString();

          _isCurrentlyStreaming = true;
          _log('Video Stream Initialized', {
            'textureId': _activeTextureId,
            'resolution': '${_width}x$_height',
            'codec': codec,
            'device': _activeDeviceName,
            'clientIp': _activeClientIp,
          });

          // Resync hardware texture pipeline in cast_plugin
          requestTextureResync();
          Future.delayed(const Duration(milliseconds: 150), () {
            requestTextureResync();
          });

          onStreamStateChanged(
            isStreaming: true,
            textureId: _activeTextureId,
            deviceName: _activeDeviceName,
            clientIp: _activeClientIp,
            width: _width,
            height: _height,
            fps: 60,
            codec: codec,
          );
          break;

        case 'DecodeUpdate':
          onStatsUpdate?.call(
            bitrateKbps: data['bitrate'] != null ? (data['bitrate'] as num).toDouble() : null,
            decodeTimeUs: data['decode'] != null ? (data['decode'] as num).toInt() : null,
            renderTimeUs: data['render'] != null ? (data['render'] as num).toInt() : null,
          );
          final now = DateTime.now();
          if (now.difference(_lastDecodeLog).inMilliseconds >= 250) {
            _lastDecodeLog = now;
            onProtocolLog('CastPlugin Call: json_call', {
              'type': 'DecodeUpdate',
              'data': data,
            });
          }
          break;

        case 'OnConnEnd':
        case 'OnConnClose':
        case 'OnStop':
        case 'MirrorStop':
        case 'MirrorFailed':
          _log('Stream Ended ($type)', {});
          _isCurrentlyStreaming = false;
          _activeTextureId = null;
          _activeClientIp = '';
          onStreamStateChanged(isStreaming: false);
          break;

        default:
          break;
      }
    } else {
      _log('CastPlugin Raw Call: ${call.method}', {'arguments': call.arguments});
    }

    return null;
  }

  static Future<bool> setNativeEngineName(
    String name, {
    int width = 1920,
    int height = 1080,
    int fps = 60,
  }) async {
    try {
      final res = await _engineChannel.invokeMethod('startEngine', {
        'name': name,
        'width': width,
        'height': height,
        'fps': fps,
      });
      return res == true;
    } catch (e) {
      debugPrint('[NativeCastBridge] setNativeEngineName error: $e');
      return false;
    }
  }

  Future<void> requestTextureResync() async {
    try {
      await _castChannel.invokeMethod('RequestReceiverMirrorTextureResync');
    } catch (e) {
      debugPrint('[NativeCastBridge] requestTextureResync error: $e');
    }
  }

  void dispose() {
    _castChannel.setMethodCallHandler(null);
    _engineChannel.setMethodCallHandler(null);
  }
}
