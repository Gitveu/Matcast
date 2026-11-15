enum CastProtocol {
  googleCast('Google Cast'),
  airplay('AirPlay'),
  miracast('Miracast (WFD)'),
  dlna('DLNA'),
  rtsp('RTSP Direct'),
  unknown('Unknown');

  final String label;
  const CastProtocol(this.label);
}

enum DeviceConnectionStatus {
  connected,
  connecting,
  disconnected,
}

class CastDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final CastProtocol protocol;
  final DeviceConnectionStatus status;
  final DateTime connectedAt;
  final int signalLevel; // 1 to 5

  const CastDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.protocol,
    this.status = DeviceConnectionStatus.connected,
    required this.connectedAt,
    this.signalLevel = 4,
  });

  CastDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    CastProtocol? protocol,
    DeviceConnectionStatus? status,
    DateTime? connectedAt,
    int? signalLevel,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      signalLevel: signalLevel ?? this.signalLevel,
    );
  }
}
