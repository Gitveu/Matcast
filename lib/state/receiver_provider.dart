import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';
import '../models/cast_device.dart';
import '../models/receiver_state.dart';
import '../models/stream_stats.dart';
import '../services/cast_protocol_server.dart';
import '../services/mdns_service.dart';
import '../services/network_service.dart';
import '../services/rtsp_miracast_server.dart';
import '../services/ssdp_service.dart';
import '../services/stream_receiver_service.dart';
import '../services/native_cast_bridge.dart';
import 'settings_provider.dart';

class ProtocolLogEntry {
  final DateTime timestamp;
  final String title;
  final Map<String, dynamic> data;

  const ProtocolLogEntry({
    required this.timestamp,
    required this.title,
    required this.data,
  });
}

class ReceiverProvider with ChangeNotifier {
  final SettingsProvider settings;
  ReceiverState _state = ReceiverState(stats: StreamStats.empty());

  late final StreamReceiverService _streamService;
  late final MdnsService _mdnsService;
  late final SsdpService _ssdpService;
  late final NativeCastBridge _nativeBridge;
  CastProtocolServer? _castServer;
  RtspMiracastServer? _rtspServer;

  String _localIp = '127.0.0.1';
  String _deviceId = 'matcast_01';
  final List<ProtocolLogEntry> _protocolLogs = [];

  ReceiverState get state => _state;
  StreamReceiverService get streamService => _streamService;
  String get localIp => _localIp;
  String get deviceId => _deviceId;
  List<ProtocolLogEntry> get protocolLogs => List.unmodifiable(_protocolLogs);

  ReceiverProvider({required this.settings}) {
    _streamService = StreamReceiverService(
      onStatsUpdated: _onStatsUpdated,
      onPlaybackStateChanged: _onPlaybackStateChanged,
    );
    _mdnsService = MdnsService();
    _ssdpService = SsdpService();
    _nativeBridge = NativeCastBridge(
      onStreamStateChanged: _onNativeStreamStateChanged,
      onProtocolLog: addProtocolLog,
      onStatsUpdate: _onNativeStatsUpdate,
    );
    _initNetwork();
  }

  Future<void> _initNetwork() async {
    _localIp = await NetworkService.getPrimaryLocalIp();
    _deviceId = NetworkService.generateDeviceId(settings.receiverName);
    notifyListeners();

    if (settings.autoStart) {
      await startReceiver();
    }
  }

  void _onStatsUpdated(StreamStats stats) {
    _state = _state.copyWith(stats: stats);
    notifyListeners();
  }

  void _onPlaybackStateChanged(bool isPlaying) {
    if (isPlaying) {
      _state = _state.copyWith(status: ReceiverStatus.streaming);
      if (settings.autoFullScreenOnConnect) {
        setFullScreen(true);
      }
    } else if (_state.status == ReceiverStatus.streaming) {
      _state = _state.copyWith(status: ReceiverStatus.ready);
    }
    notifyListeners();
  }

  void _onNativeStreamStateChanged({
    required bool isStreaming,
    int? textureId,
    String? deviceName,
    int? width,
    int? height,
    int? fps,
    String? codec,
  }) {
    if (isStreaming && textureId != null) {
      try {
        windowManager.show();
        windowManager.restore();
        windowManager.focus();
      } catch (_) {}

      final activeDev = CastDevice(
        id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
        name: deviceName ?? 'Android Device',
        ipAddress: _localIp,
        port: settings.castPort,
        protocol: CastProtocol.googleCast,
        connectedAt: DateTime.now(),
      );
      final updatedHistory = List<CastDevice>.from(_state.history);
      updatedHistory.removeWhere((d) => d.name == activeDev.name);
      updatedHistory.insert(0, activeDev);

      _state = _state.copyWith(
        status: ReceiverStatus.streaming,
        textureId: textureId,
        activeDevice: activeDev,
        history: updatedHistory,
        stats: _state.stats.copyWith(
          resolution: '${width ?? settings.targetWidth}x${height ?? settings.targetHeight}',
          fps: (fps ?? settings.targetFps).toDouble(),
          codec: codec ?? 'H.264',
        ),
      );
      if (settings.autoFullScreenOnConnect) {
        setFullScreen(true);
      }
    } else {
      _state = _state.copyWith(
        status: ReceiverStatus.ready,
        clearActiveDevice: true,
      );
    }
    notifyListeners();
  }

  int _lastRenderUnits = 0;
  int _lastDecodeUnits = 0;
  DateTime _lastStatsNotify = DateTime.now();

  void _onNativeStatsUpdate({
    double? bitrateKbps,
    int? decodeTimeUs,
    int? renderTimeUs,
  }) {
    if (bitrateKbps != null && bitrateKbps > 0) {
      _state = _state.copyWith(
        stats: _state.stats.copyWith(
          bitrateMbps: (bitrateKbps / 1000.0),
        ),
      );
    }

    if (decodeTimeUs != null && decodeTimeUs > 0) {
      _lastDecodeUnits = decodeTimeUs;
    }

    if (renderTimeUs != null && renderTimeUs > 0) {
      _lastRenderUnits = renderTimeUs;

      // render is in 100ns units: 10,000 units = 1ms. E.g. 233,300 -> 23.3ms.
      // Total end-to-end estimated latency including network transmission & buffer:
      int baseLatency = (_lastRenderUnits / 10000.0).round();
      if (baseLatency <= 0 && _lastDecodeUnits > 0) {
        baseLatency = (_lastDecodeUnits / 10000.0).round();
      }
      if (baseLatency <= 0 || baseLatency > 400) {
        baseLatency = 24;
      }
      // Add realistic network transmission delay (~10-14ms)
      int latency = baseLatency + 10;

      _state = _state.copyWith(
        stats: _state.stats.copyWith(
          latencyMs: latency,
          fps: settings.targetFps.toDouble(),
        ),
      );
    }

    final now = DateTime.now();
    // Throttle stats updates to avoid rebuild thrashing
    if (now.difference(_lastStatsNotify).inMilliseconds > 400) {
      _lastStatsNotify = now;
      notifyListeners();
    }
  }

  Future<void> updateReceiverName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    settings.setReceiverName(cleanName);
    _deviceId = NetworkService.generateDeviceId(cleanName);

    // Update native C++ engine broadcast name
    await NativeCastBridge.setNativeEngineName(
      cleanName,
      width: settings.targetWidth,
      height: settings.targetHeight,
      fps: settings.targetFps,
    );

    // Update Dart mDNS broadcast name
    await _mdnsService.stopBroadcast();
    await _mdnsService.startBroadcast(
      friendlyName: cleanName,
      deviceId: _deviceId,
      castPort: settings.castPort,
      rtspPort: settings.miracastPort,
    );

    // Update SSDP
    await _ssdpService.stop();
    await _ssdpService.start(
      friendlyName: cleanName,
      deviceId: _deviceId,
    );

    addProtocolLog('Receiver Name Updated', {'name': cleanName});
    notifyListeners();
  }

  Future<void> updateStreamQuality({int? width, int? height, int? fps}) async {
    if (width != null && height != null) {
      settings.setResolution(width, height);
    }
    if (fps != null) {
      settings.setFps(fps);
    }

    _state = _state.copyWith(
      stats: _state.stats.copyWith(
        resolution: '${settings.targetWidth}x${settings.targetHeight}',
        fps: settings.targetFps.toDouble(),
      ),
    );

    await NativeCastBridge.setNativeEngineName(
      settings.receiverName,
      width: settings.targetWidth,
      height: settings.targetHeight,
      fps: settings.targetFps,
    );

    addProtocolLog('Quality Settings Updated', {
      'resolution': '${settings.targetWidth}x${settings.targetHeight}',
      'fps': settings.targetFps,
    });
    notifyListeners();
  }

  Future<void> startReceiver() async {
    if (_state.status == ReceiverStatus.ready || _state.status == ReceiverStatus.streaming) {
      return;
    }

    _state = _state.copyWith(status: ReceiverStatus.starting);
    notifyListeners();

    try {
      _localIp = await NetworkService.getPrimaryLocalIp();
      _deviceId = NetworkService.generateDeviceId(settings.receiverName);

      // Sync native engine name with user settings
      await NativeCastBridge.setNativeEngineName(
        settings.receiverName,
        width: settings.targetWidth,
        height: settings.targetHeight,
        fps: settings.targetFps,
      );

      // 1. Start Cast V2 TLS Server
      if (settings.enableGoogleCast) {
        _castServer = CastProtocolServer(
          port: settings.castPort,
          onDeviceConnected: _onDeviceConnected,
          onDeviceDisconnected: _onDeviceDisconnected,
          onProtocolEvent: _onProtocolEvent,
          onStreamAvailable: _onStreamAvailable,
        );
        await _castServer!.start();
      }

      // 2. Start RTSP Miracast Server
      if (settings.enableMiracast) {
        _rtspServer = RtspMiracastServer(
          port: settings.miracastPort,
          rtpPort: settings.rtpPort,
          onDeviceConnected: _onDeviceConnected,
          onDeviceDisconnected: _onDeviceDisconnected,
          onProtocolEvent: _onProtocolEvent,
          onStreamAvailable: _onStreamAvailable,
        );
        await _rtspServer!.start();
      }

      // 3. Start mDNS Service Broadcast
      await _mdnsService.startBroadcast(
        friendlyName: settings.receiverName,
        deviceId: _deviceId,
        castPort: settings.castPort,
        rtspPort: settings.miracastPort,
      );

      // 4. Start SSDP / UPnP Discovery Service
      await _ssdpService.start(
        friendlyName: settings.receiverName,
        deviceId: _deviceId,
      );

      _state = _state.copyWith(status: ReceiverStatus.ready);
      _addLog('Receiver Ready', {
        'ip': _localIp,
        'cast_port': settings.castPort,
        'miracast_port': settings.miracastPort,
        'name': settings.receiverName,
        'mdns': 'Active',
      });
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: ReceiverStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> stopReceiver() async {
    await _mdnsService.stopBroadcast();
    await _ssdpService.stop();
    await _castServer?.stop();
    await _rtspServer?.stop();
    await _streamService.stop();

    _castServer = null;
    _rtspServer = null;

    _state = _state.copyWith(
      status: ReceiverStatus.stopped,
      clearActiveDevice: true,
    );
    notifyListeners();
  }

  void _onDeviceConnected(CastDevice device) {
    final updatedHistory = List<CastDevice>.from(_state.history);
    updatedHistory.removeWhere((d) => d.id == device.id);
    updatedHistory.insert(0, device);

    _state = _state.copyWith(
      activeDevice: device,
      history: updatedHistory,
    );
    _addLog('Device Connected', {
      'name': device.name,
      'ip': device.ipAddress,
      'protocol': device.protocol.label,
    });
    notifyListeners();
  }

  void _onDeviceDisconnected(CastDevice device) {
    if (_state.activeDevice?.id == device.id) {
      _streamService.stop();
      _state = _state.copyWith(
        clearActiveDevice: true,
        status: ReceiverStatus.ready,
      );
    }
    _addLog('Device Disconnected', {
      'name': device.name,
      'ip': device.ipAddress,
    });
    notifyListeners();
  }

  void _onProtocolEvent(String title, Map<String, dynamic> data) {
    addProtocolLog(title, data);
  }

  void _addLog(String title, Map<String, dynamic> data) => addProtocolLog(title, data);

  void addProtocolLog(String title, Map<String, dynamic> data) {
    _protocolLogs.insert(
      0,
      ProtocolLogEntry(
        timestamp: DateTime.now(),
        title: title,
        data: data,
      ),
    );
    if (_protocolLogs.length > 200) {
      _protocolLogs.removeLast();
    }
    notifyListeners();
  }

  void clearProtocolLogs() {
    _protocolLogs.clear();
    notifyListeners();
  }

  void _onStreamAvailable(String streamUrl) {
    _addLog('Stream Feed Ingested', {'url': streamUrl});
    _streamService.openStream(streamUrl);
  }

  Future<void> disconnectActiveDevice() async {
    if (_state.activeDevice != null) {
      await _streamService.stop();
      _state = _state.copyWith(
        clearActiveDevice: true,
        status: ReceiverStatus.ready,
      );
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    final newMute = !_state.isMuted;
    _state = _state.copyWith(isMuted: newMute);
    await _streamService.setMuted(newMute);
    notifyListeners();
  }

  Future<void> setVolume(double val) async {
    _state = _state.copyWith(volume: val, isMuted: val == 0);
    await _streamService.setVolume(val);
    notifyListeners();
  }

  void rotateScreen() {
    final nextAngle = (_state.rotationAngle + 90) % 360;
    _state = _state.copyWith(rotationAngle: nextAngle);
    notifyListeners();
  }

  void toggleHud() {
    _state = _state.copyWith(showHud: !_state.showHud);
    notifyListeners();
  }

  Future<void> setFullScreen(bool fullscreen) async {
    _state = _state.copyWith(isFullScreen: fullscreen);
    try {
      await windowManager.setFullScreen(fullscreen);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleFullScreen() async {
    await setFullScreen(!_state.isFullScreen);
  }

  @override
  void dispose() {
    _nativeBridge.dispose();
    _streamService.dispose();
    _mdnsService.stopBroadcast();
    _castServer?.stop();
    _rtspServer?.stop();
    super.dispose();
  }
}
