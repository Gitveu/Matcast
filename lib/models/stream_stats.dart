class StreamStats {
  final double fps;
  final double bitrateMbps;
  final String resolution;
  final int latencyMs;
  final String codec;
  final int droppedFrames;
  final DateTime timestamp;

  const StreamStats({
    this.fps = 0.0,
    this.bitrateMbps = 0.0,
    this.resolution = '0x0',
    this.latencyMs = 0,
    this.codec = 'H.264',
    this.droppedFrames = 0,
    required this.timestamp,
  });

  factory StreamStats.empty() {
    return StreamStats(
      timestamp: DateTime.now(),
    );
  }

  StreamStats copyWith({
    double? fps,
    double? bitrateMbps,
    String? resolution,
    int? latencyMs,
    String? codec,
    int? droppedFrames,
    DateTime? timestamp,
  }) {
    return StreamStats(
      fps: fps ?? this.fps,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      resolution: resolution ?? this.resolution,
      latencyMs: latencyMs ?? this.latencyMs,
      codec: codec ?? this.codec,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
