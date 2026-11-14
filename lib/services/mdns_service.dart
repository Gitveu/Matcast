import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

class MdnsService {
  Process? _dnsSdCastProcess;
  Process? _dnsSdDisplayProcess;
  RawDatagramSocket? _rawMulticastSocket;
  Timer? _announcementTimer;
  bool _isBroadcasting = false;

  bool get isBroadcasting => _isBroadcasting;

  Future<bool> startBroadcast({
    required String friendlyName,
    required String deviceId,
    int castPort = 8009,
    int rtspPort = 7236,
  }) async {
    if (_isBroadcasting) {
      await stopBroadcast();
    }

    final localIp = await NetworkService.getPrimaryLocalIp();
    final displayName = friendlyName;
    final formattedId = deviceId.toUpperCase().replaceAll('_', '-');

    debugPrint('[mDNS] Starting advertising for $displayName on $localIp (Cast:$castPort, RTSP:$rtspPort)');

    // 1. Register with Apple Bonjour (dns-sd.exe) if available (broadcasts across all physical LAN adapters)
    try {
      final dnsSdPath = 'C:\\Windows\\System32\\dns-sd.exe';
      if (await File(dnsSdPath).exists()) {
        final castArgs = [
          '-R',
          displayName,
          '_googlecast._tcp',
          'local.',
          castPort.toString(),
          'id=$formattedId',
          've=5',
          'ca=201221',
          'st=0',
          'md=Matcast Receiver',
          'fn=$friendlyName',
          'ic=/setup/icon.png',
          'cd=5b4a6cbdf025461e8be02046dc040aca',
          'bs=FFFFFFFFEEF0',
          'nf=1',
        ];

        _dnsSdCastProcess = await Process.start(dnsSdPath, castArgs);
        _dnsSdCastProcess!.stdout.transform(const SystemEncoding().decoder).listen((data) {
          debugPrint('[Bonjour Cast] $data');
        });
        _dnsSdCastProcess!.stderr.transform(const SystemEncoding().decoder).listen((data) {
          debugPrint('[Bonjour Cast ERR] $data');
        });

        final displayArgs = [
          '-R',
          friendlyName,
          '_display._tcp',
          'local.',
          rtspPort.toString(),
          'wfd_video_formats=00000001',
          'wfd_audio_codecs=00000001',
          'fn=$friendlyName',
        ];

        _dnsSdDisplayProcess = await Process.start(dnsSdPath, displayArgs);
        debugPrint('[mDNS] Registered with system Bonjour service');
      }
    } catch (e) {
      debugPrint('[mDNS] Bonjour registration notice: $e');
    }

    // 2. Direct Dart UDP Multicast Broadcaster & Unicast Announcer on Port 5353
    try {
      _rawMulticastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        5353,
        reuseAddress: true,
      );

      try {
        _rawMulticastSocket!.joinMulticast(InternetAddress('224.0.0.251'));
      } catch (e) {
        debugPrint('[mDNS] joinMulticast notice: $e');
      }

      _rawMulticastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _rawMulticastSocket!.receive();
          if (datagram != null) {
            _handleIncomingDnsQuery(datagram, displayName, friendlyName, formattedId, localIp, castPort);
          }
        }
      });

      _sendDnsAnnouncement(displayName, friendlyName, formattedId, localIp, castPort);

      _announcementTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _sendDnsAnnouncement(displayName, friendlyName, formattedId, localIp, castPort);
      });

      _isBroadcasting = true;
      return true;
    } catch (e) {
      debugPrint('[mDNS] Dart raw socket error: $e');
      _isBroadcasting = _dnsSdCastProcess != null;
      return _isBroadcasting;
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
      final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port);
      _rawMulticastSocket?.send(packet, datagram.address, datagram.port);
    } catch (_) {}
  }

  void _sendDnsAnnouncement(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port,
  ) {
    if (_rawMulticastSocket == null) return;

    try {
      final packet = _buildCastMdnsPacket(displayName, friendlyName, deviceId, localIp, port);

      _rawMulticastSocket!.send(packet, InternetAddress('224.0.0.251'), 5353);

      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        _rawMulticastSocket!.send(packet, InternetAddress(subnetBroadcast), 5353);
      }

      if (localIp.startsWith('192.168.10.')) {
        _rawMulticastSocket!.send(packet, InternetAddress('192.168.10.18'), 5353);
      }
    } catch (e) {
      debugPrint('[mDNS] Announcement error: $e');
    }
  }

  Uint8List _buildCastMdnsPacket(
    String displayName,
    String friendlyName,
    String deviceId,
    String localIp,
    int port,
  ) {
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

    // 1. PTR Record
    writeDnsName(serviceType);
    builder.add([0x00, 0x0c]); // Type: PTR
    builder.add([0x80, 0x01]); // Class: IN, Flush
    builder.add([0x00, 0x00, 0x0e, 0x10]); // TTL: 3600

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

    // 2. SRV Record
    writeDnsName(instanceName);
    builder.add([0x00, 0x21]); // Type: SRV
    builder.add([0x80, 0x01]); // Class: IN
    builder.add([0x00, 0x00, 0x00, 0x78]); // TTL: 120
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

    // 3. TXT Record with Cast Screen Mirroring capabilities
    writeDnsName(instanceName);
    builder.add([0x00, 0x10]); // Type: TXT
    builder.add([0x80, 0x01]); // Class: IN
    builder.add([0x00, 0x00, 0x0e, 0x10]); // TTL: 3600

    final txtEntries = [
      'id=$deviceId',
      've=5',
      'ca=201221',
      'st=0',
      'md=Matcast Receiver',
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
    builder.add([0x80, 0x01]); // Class: IN
    builder.add([0x00, 0x00, 0x00, 0x78]); // TTL: 120
    builder.add([0x00, 0x04]); // Length: 4
    for (final octet in localIp.split('.')) {
      builder.addByte(int.parse(octet));
    }

    return builder.toBytes();
  }

  Future<void> stopBroadcast() async {
    _announcementTimer?.cancel();
    _announcementTimer = null;

    try {
      _rawMulticastSocket?.close();
      _rawMulticastSocket = null;
    } catch (_) {}

    try {
      _dnsSdCastProcess?.kill();
      _dnsSdCastProcess = null;
    } catch (_) {}

    try {
      _dnsSdDisplayProcess?.kill();
      _dnsSdDisplayProcess = null;
    } catch (_) {}

    _isBroadcasting = false;
  }
}
