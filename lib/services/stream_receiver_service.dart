import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/stream_stats.dart';

class StreamReceiverService {
  late final Player player;
  late final VideoController controller;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  StreamStats _currentStats = StreamStats.empty();
  Timer? _monitorTimer;

  final Function(StreamStats) onStatsUpdated;
  final Function(bool isPlaying) onPlaybackStateChanged;

  StreamReceiverService({
    required this.onStatsUpdated,
    required this.onPlaybackStateChanged,
  }) {
    MediaKit.ensureInitialized();
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024, // 16MB low latency
        logLevel: MPVLogLevel.warn,
      ),
    );
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _initListeners();
  }

  void _initListeners() {
    player.stream.playing.listen((isPlaying) {
      onPlaybackStateChanged(isPlaying);
    });

    player.stream.videoParams.listen((params) {
      final width = params.w ?? 0;
      final height = params.h ?? 0;
      if (width > 0 && height > 0) {
        _currentStats = _currentStats.copyWith(
          resolution: '${width}x$height',
          timestamp: DateTime.now(),
        );
        onStatsUpdated(_currentStats);
      }
    });

    // Monitor real playback state
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (player.state.playing) {
        final w = player.state.width ?? 0;
        final h = player.state.height ?? 0;
        if (w > 0 && h > 0) {
          _currentStats = _currentStats.copyWith(
            resolution: '${w}x$h',
            timestamp: DateTime.now(),
          );
          onStatsUpdated(_currentStats);
        }
      }
    });

    _isInitialized = true;
  }

  Future<void> openStream(String url) async {
    try {
      debugPrint('[StreamReceiver] Opening stream: $url');
      await player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'Matcast-Receiver/1.0',
          },
        ),
      );
      await player.play();
    } catch (e) {
      debugPrint('[StreamReceiver] Error opening stream: $e');
    }
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {}
    _currentStats = StreamStats.empty();
    onStatsUpdated(_currentStats);
  }

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume * 100);
  }

  Future<void> setMuted(bool muted) async {
    if (muted) {
      await player.setVolume(0);
    } else {
      await player.setVolume(100);
    }
  }

  void dispose() {
    _monitorTimer?.cancel();
    player.dispose();
  }
}
