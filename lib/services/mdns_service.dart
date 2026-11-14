import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

class MdnsService {
  RawDatagramSocket? _rawMulticastSocket;
  Timer? _announcementTimer;
  bool _isBroadcasting = false;

  String? _lastDisplayName;
  String? _lastFriendlyName;
  String? _lastDeviceId;
  String? _lastLocalIp;
  int? _lastCastPort;

  bool get isBroadcasting => _isBroadcasting;

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

    debugPrint('[mDNS] Broadcasting for $displayName on $localIp:$castPort');

    try {
      _rawMulticastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        5353,
        reuseAddress: true,
      );

      try {
        _rawMulticastSocket!.joinMulticast(InternetAddress('224.0.0.251'));
      } catch (e) {
        debugPrint('[mDNS] joinMulticast: $e');
      }

      _rawMulticastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _rawMulticastSocket!.receive();
          if (datagram != null) {
            _handleIncomingDnsQuery(datagram, displayName, cleanName, formattedId, localIp, castPort);
          }
        }
      });

      // Rapid initial burst (0ms, 120ms, 250ms) for instantaneous discovery on phones
      _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 30);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 30);
        }
      });
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_isBroadcasting) {
          _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 30);
        }
      });

      // Steady state: broadcast every 1.5 seconds with short 30s TTL
      _announcementTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _sendDnsAnnouncement(displayName, cleanName, formattedId, localIp, castPort, ttl: 30);
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
    try {
      final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port, ttl: 30);
      _rawMulticastSocket?.send(packet, datagram.address, datagram.port);
    } catch (_) {}
  }

  void _sendDnsAnnouncement(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port, {
    int ttl = 30,
  }) async {
    if (_rawMulticastSocket == null) return;

    try {
      final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port, ttl: ttl);

      // 1. Multicast Group
      _rawMulticastSocket!.send(packet, InternetAddress('224.0.0.251'), 5353);

      // 2. Primary Subnet Broadcast
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        _rawMulticastSocket!.send(packet, InternetAddress(subnetBroadcast), 5353);
      }

      // 3. Send to all detected active local adapters
      final allIps = await NetworkService.getLocalIpAddresses();
      for (final ip in allIps) {
        final p = ip.split('.');
        if (p.length == 4) {
          final bcast = '${p[0]}.${p[1]}.${p[2]}.255';
          _rawMulticastSocket!.send(packet, InternetAddress(bcast), 5353);
        }
      }
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
    builder.add(ttlBytes);

    final txtEntries = [
      'id=$deviceId',
      've=5',
      'ca=201221',
      'st=0',
      'md=Google Cast',
      'fn=$friendlyName',
      'ic=/setup/icon.png',
      'cd=5b4a6cbdf025461e8be02046dc040aca',
      'bs=FFFFFFFFEEF0',
      'nf=1',
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

    _isBroadcasting = false;
  }
}
