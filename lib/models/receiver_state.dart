import 'cast_device.dart';
import 'stream_stats.dart';

enum ReceiverStatus {
  stopped,
  starting,
  ready,
  streaming,
  error,
}

class ReceiverState {
  final ReceiverStatus status;
  final String? errorMessage;
  final CastDevice? activeDevice;
  final List<CastDevice> history;
  final StreamStats stats;
  final bool isMuted;
  final double volume;
  final bool isFullScreen;
  final bool showHud;
  final int rotationAngle; // 0, 90, 180, 270
  final int? textureId;

  const ReceiverState({
    this.status = ReceiverStatus.stopped,
    this.errorMessage,
    this.activeDevice,
    this.history = const [],
    required this.stats,
    this.isMuted = false,
    this.volume = 1.0,
    this.isFullScreen = false,
    this.showHud = true,
    this.rotationAngle = 0,
    this.textureId,
  });

  ReceiverState copyWith({
    ReceiverStatus? status,
    String? errorMessage,
    CastDevice? activeDevice,
    bool clearActiveDevice = false,
    List<CastDevice>? history,
    StreamStats? stats,
    bool? isMuted,
    double? volume,
    bool? isFullScreen,
    bool? showHud,
    int? rotationAngle,
    int? textureId,
  }) {
    return ReceiverState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      activeDevice: clearActiveDevice ? null : (activeDevice ?? this.activeDevice),
      history: history ?? this.history,
      stats: stats ?? this.stats,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      showHud: showHud ?? this.showHud,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      textureId: textureId ?? this.textureId,
    );
  }
}
