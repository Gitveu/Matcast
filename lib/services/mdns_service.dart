import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

class MdnsService {
  RawDatagramSocket? _rawMulticastSocket;
  RawDatagramSocket? _unicastSendSocket;
  final Set<String> _localIps = {'127.0.0.1', '::1', '0.0.0.0'};
  Timer? _announcementTimer;
  bool _isBroadcasting = false;
  bool _isStreamingActive = false;
  String? _activeStreamingIp;

  String? _lastDisplayName;
  String? _lastFriendlyName;
  String? _lastDeviceId;
  String? _lastLocalIp;
  int? _lastCastPort;

  bool get isBroadcasting => _isBroadcasting;
  bool get isStreamingActive => _isStreamingActive;
  String? get activeStreamingIp => _activeStreamingIp;

  void setStreamingState({required bool isStreaming, String? activeIp}) {
    _isStreamingActive = isStreaming;
    _activeStreamingIp = isStreaming ? activeIp : null;
    debugPrint('[mDNS] setStreamingState: isStreaming=$isStreaming, activeIp=$activeIp');
  }

  MdnsService() {
    _cleanupLegacyZombieProcesses();
  }

  static void _cleanupLegacyZombieProcesses() {
    try {
      if (Platform.isWindows) {
        Process.runSync('taskkill', ['/F', '/IM', 'dns-sd.exe']);
      }
    } catch (_) {}
  }

  Future<bool> startBroadcast({
    required String friendlyName,
    required String deviceId,
    int castPort = 8009,
    int rtspPort = 7236,
  }) async {
    final cleanName = friendlyName.trim();
    final displayName = cleanName;
    final formattedId = deviceId.toUpperCase().replaceAll('_', '-');
    final localIp = await NetworkService.getPrimaryLocalIp();

    // 1. If previously broadcasting under a different name, announce goodbye for the old one
    if (_isBroadcasting && _lastDisplayName != null && _lastDisplayName != displayName) {
      await _sendGoodbyePacket(
        _lastDisplayName!,
        _lastFriendlyName ?? _lastDisplayName!,
        _lastDeviceId ?? formattedId,
        _lastLocalIp ?? localIp,
        _lastCastPort ?? castPort,
      );
    }

    if (_isBroadcasting) {
      await stopBroadcast(sendGoodbye: false);
    }

    _lastDisplayName = displayName;
    _lastFriendlyName = cleanName;
    _lastDeviceId = formattedId;
    _lastLocalIp = localIp;
    _lastCastPort = castPort;

    _localIps.add(localIp);
    try {
      final ifaces = await NetworkInterface.list(includeLoopback: true);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          _localIps.add(addr.address);
        }
      }
    } catch (_) {}

    debugPrint('[mDNS] Broadcasting for $displayName on $localIp:$castPort');

    try {
      _rawMulticastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        5353,
        reuseAddress: true,
      );

      // Join multicast group and enable broadcasting
      try {
        _rawMulticastSocket!.broadcastEnabled = true;
        _rawMulticastSocket!.multicastHops = 255;
      } catch (_) {}

      // Explicitly join multicast group on physical adapter
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          final name = iface.name.toLowerCase();
          if (name.contains('vmnet') || name.contains('virtual') || name.contains('bluetooth')) {
            continue;
          }
          for (final addr in iface.addresses) {
            if (addr.address == localIp) {
              try {
                _rawMulticastSocket!.joinMulticast(InternetAddress('224.0.0.251'), iface);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
      try {
        _rawMulticastSocket!.joinMulticast(InternetAddress('224.0.0.251'));
      } catch (_) {}

      // Dedicated sender socket bound strictly to local physical LAN IP
      try {
        _unicastSendSocket = await RawDatagramSocket.bind(
          InternetAddress(localIp),
          0,
        );
        _unicastSendSocket!.broadcastEnabled = true;
        _unicastSendSocket!.multicastHops = 255;
      } catch (e) {
        debugPrint('[mDNS] _unicastSendSocket bind: $e');
      }

      _rawMulticastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _rawMulticastSocket!.receive();
          if (datagram != null) {
            _handleIncomingDnsQuery(datagram, displayName, cleanName, formattedId, localIp, castPort);
          }
        }
      });

      // Rapid initial burst (0ms, 100ms, 250ms, 500ms, 1000ms) for instantaneous discovery on phones
      _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
        }
      });
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
        }
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
        }
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
        }
      });

      // Steady state: broadcast every 10 seconds with realistic 120s TTL (prevents Android mDNS flood throttling)
      _announcementTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 120);
      });

      _isBroadcasting = true;
      return true;
    } catch (e) {
      debugPrint('[mDNS] Socket bind error: $e');
      _isBroadcasting = false;
      return false;
    }
  }

  void _handleIncomingDnsQuery(
    Datagram datagram,
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port,
  ) {
    if (_localIps.contains(datagram.address.address)) {
      return;
    }
    try {
      final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port, ttl: 120);
      // Respond directly to the querying client over unicast (bypasses router multicast filtering)
      _unicastSendSocket?.send(packet, datagram.address, datagram.port);
      _rawMulticastSocket?.send(packet, datagram.address, datagram.port);
    } catch (_) {}
  }

  void _sendDnsAnnouncement(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port, {
    int ttl = 120,
  }) async {
    final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port, ttl: ttl);

    try {
      // 1. Multicast via dedicated LAN-bound socket
      _unicastSendSocket?.send(packet, InternetAddress('224.0.0.251'), 5353);

      // 2. Primary Subnet Directed Broadcast (ensures Wi-Fi devices receive even if IGMP snooping is on)
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        _unicastSendSocket?.send(packet, InternetAddress(subnetBroadcast), 5353);
      }

      // 3. Multicast via raw socket
      _rawMulticastSocket?.send(packet, InternetAddress('224.0.0.251'), 5353);
    } catch (e) {
      debugPrint('[mDNS] Announcement error: $e');
    }
  }

  Future<void> _sendGoodbyePacket(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port,
  ) async {
    if (_rawMulticastSocket == null) return;
    try {
      debugPrint('[mDNS] Sending Goodbye packet (TTL=0) for previous instance $displayName');
      _sendDnsAnnouncement(displayName, friendlyName, deviceId, localIp, port, ttl: 0);
      await Future.delayed(const Duration(milliseconds: 60));
      _sendDnsAnnouncement(displayName, friendlyName, deviceId, localIp, port, ttl: 0);
    } catch (_) {}
  }

  Uint8List _buildCastMdnsPacket(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port, {
    int ttl = 30,
  }) {
    final builder = BytesBuilder();

    builder.add([0x00, 0x00]); // ID: 0
    builder.add([0x84, 0x00]); // Flags: Standard response, Authoritative
    builder.add([0x00, 0x00]); // Questions: 0
    builder.add([0x00, 0x01]); // Answer RRs: 1 (PTR)
    builder.add([0x00, 0x00]); // Authority RRs: 0
    builder.add([0x00, 0x03]); // Additional RRs: 3 (SRV, TXT, A)

    void writeDnsName(String name) {
      for (final part in name.split('.')) {
        if (part.isNotEmpty) {
          final b = Uint8List.fromList(part.codeUnits);
          builder.addByte(b.length);
          builder.add(b);
        }
      }
      builder.addByte(0);
    }

    final serviceType = '_googlecast._tcp.local';
    final safeInstance = displayName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final instanceName = '$safeInstance._googlecast._tcp.local';
    final hostName = '$safeInstance.local';

    final ttlBytes = [
      (ttl >> 24) & 0xff,
      (ttl >> 16) & 0xff,
      (ttl >> 8) & 0xff,
      ttl & 0xff,
    ];

    // 1. PTR Record (Shared, no flush bit)
    writeDnsName(serviceType);
    builder.add([0x00, 0x0c]); // Type: PTR
    builder.add([0x00, 0x01]); // Class: IN (Shared)
    builder.add(ttlBytes);

    final ptrBuilder = BytesBuilder();
    for (final part in instanceName.split('.')) {
      if (part.isNotEmpty) {
        final b = Uint8List.fromList(part.codeUnits);
        ptrBuilder.addByte(b.length);
        ptrBuilder.add(b);
      }
    }
    ptrBuilder.addByte(0);
    final ptrBytes = ptrBuilder.toBytes();
    builder.add([0x00, ptrBytes.length]);
    builder.add(ptrBytes);

    // 2. SRV Record (Unique, flush bit 0x80)
    writeDnsName(instanceName);
    builder.add([0x00, 0x21]); // Type: SRV
    builder.add([0x80, 0x01]); // Class: IN, Flush
    builder.add(ttlBytes);

    final srvData = BytesBuilder();
    srvData.add([0x00, 0x00]); // Priority: 0
    srvData.add([0x00, 0x00]); // Weight: 0
    srvData.addByte((port >> 8) & 0xff);
    srvData.addByte(port & 0xff);
    for (final part in hostName.split('.')) {
      if (part.isNotEmpty) {
        final b = Uint8List.fromList(part.codeUnits);
        srvData.addByte(b.length);
        srvData.add(b);
      }
    }
    srvData.addByte(0);
    final srvBytes = srvData.toBytes();
    builder.addByte((srvBytes.length >> 8) & 0xff);
    builder.addByte(srvBytes.length & 0xff);
    builder.add(srvBytes);

    // 3. TXT Record with Cast Mirroring metadata
    writeDnsName(instanceName);
    builder.add([0x00, 0x10]); // Type: TXT
    builder.add([0x80, 0x01]); // Class: IN, Flush
    final txtTtl = ttl > 0 ? 4500 : 0;
    builder.add([
      (txtTtl >> 24) & 0xff,
      (txtTtl >> 16) & 0xff,
      (txtTtl >> 8) & 0xff,
      txtTtl & 0xff,
    ]);

    final txtEntries = [
      'id=$deviceId',
      'cd=5b4a6cbdf025461e8be02046dc040aca',
      'rm=',
      've=05',
      'md=Google Cast',
      'ic=/setup/icon.png',
      'fn=$friendlyName',
      'ca=266757',
      'st=0',
      'nf=1',
      'ct=F9A7E5',
      'rs=',
    ];

    final txtData = BytesBuilder();
    for (final entry in txtEntries) {
      final eb = Uint8List.fromList(entry.codeUnits);
      txtData.addByte(eb.length);
      txtData.add(eb);
    }
    final txtBytes = txtData.toBytes();
    builder.addByte((txtBytes.length >> 8) & 0xff);
    builder.addByte(txtBytes.length & 0xff);
    builder.add(txtBytes);

    // 4. A Record (IPv4)
    writeDnsName(hostName);
    builder.add([0x00, 0x01]); // Type: A
    builder.add([0x80, 0x01]); // Class: IN, Flush
    builder.add(ttlBytes);
    builder.add([0x00, 0x04]); // Length: 4
    for (final octet in localIp.split('.')) {
      builder.addByte(int.parse(octet));
    }

    return builder.toBytes();
  }

  Future<void> stopBroadcast({bool sendGoodbye = true}) async {
    _announcementTimer?.cancel();
    _announcementTimer = null;

    if (sendGoodbye &&
        _lastDisplayName != null &&
        _lastFriendlyName != null &&
        _lastDeviceId != null &&
        _lastLocalIp != null &&
        _lastCastPort != null) {
      await _sendGoodbyePacket(
        _lastDisplayName!,
        _lastFriendlyName!,
        _lastDeviceId!,
        _lastLocalIp!,
        _lastCastPort!,
      );
    }

    try {
      _rawMulticastSocket?.close();
      _rawMulticastSocket = null;
    } catch (_) {}
    try {
      _unicastSendSocket?.close();
      _unicastSendSocket = null;
    } catch (_) {}

    _isBroadcasting = false;
  }
}
