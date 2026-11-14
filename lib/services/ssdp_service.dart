import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

class SsdpService {
  RawDatagramSocket? _ssdpSocket;
  HttpServer? _httpServer;
  Timer? _notifyTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  static const String ssdpMulticast = '239.255.255.250';
  static const int ssdpPort = 1900;
  static const int httpPort = 8008;

  Future<bool> start({
    required String friendlyName,
    required String deviceId,
  }) async {
    if (_isRunning) return true;

    final localIp = await NetworkService.getPrimaryLocalIp();
    debugPrint('[SSDP] Starting discovery service on $localIp:$ssdpPort');

    // 1. Start HTTP description server on port 8008
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, httpPort, shared: true);
      _httpServer!.listen((request) => _handleHttpRequest(request, friendlyName, deviceId, localIp));
      debugPrint('[SSDP HTTP] Device descriptor server running on $localIp:$httpPort');
    } catch (e) {
      debugPrint('[SSDP HTTP] Could not bind port $httpPort: $e');
    }

    // 2. Start UDP SSDP socket on port 1900
    try {
      _ssdpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        ssdpPort,
        reuseAddress: true,
      );

      try {
        _ssdpSocket!.joinMulticast(InternetAddress(ssdpMulticast));
      } catch (e) {
        debugPrint('[SSDP] joinMulticast notice: $e');
      }

      _ssdpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _ssdpSocket!.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram, friendlyName, deviceId, localIp);
          }
        }
      });

      // Send initial announcement
      _sendSsdpNotify(friendlyName, deviceId, localIp);

      // Periodically announce every 5 seconds
      _notifyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendSsdpNotify(friendlyName, deviceId, localIp);
      });

      _isRunning = true;
      return true;
    } catch (e) {
      debugPrint('[SSDP] Socket error: $e');
      _isRunning = _httpServer != null;
      return _isRunning;
    }
  }

  void _handleHttpRequest(HttpRequest request, String friendlyName, String deviceId, String localIp) {
    request.response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    final path = request.uri.path;
    if (path.contains('device-desc.xml') || path == '/' || path.contains('setup')) {
      final xml = '''<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>$friendlyName</friendlyName>
    <manufacturer>Matcast Systems</manufacturer>
    <modelName>Matcast Windows Receiver</modelName>
    <modelNumber>MD3-2026</modelNumber>
    <UDN>uuid:$deviceId</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/avt.xml</SCPDURL>
        <controlURL>/avt</controlURL>
        <eventSubURL>/avt_event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <SCPDURL>/rc.xml</SCPDURL>
        <controlURL>/rc</controlURL>
        <eventSubURL>/rc_event</eventSubURL>
      </service>
    </serviceList>
  </device>
</root>''';
      request.response.write(xml);
    } else {
      request.response.write('<root></root>');
    }
    request.response.close();
  }

  void _handleIncomingPacket(Datagram datagram, String friendlyName, String deviceId, String localIp) {
    try {
      final message = utf8.decode(datagram.data, allowMalformed: true);
      if (message.startsWith('M-SEARCH')) {
        debugPrint('[SSDP] M-SEARCH query from ${datagram.address.address}:${datagram.port}');
        _sendSearchResponse(datagram.address, datagram.port, friendlyName, deviceId, localIp);
      }
    } catch (_) {}
  }

  void _sendSearchResponse(InternetAddress target, int port, String friendlyName, String deviceId, String localIp) {
    final response = 'HTTP/1.1 200 OK\r\n'
        'CACHE-CONTROL: max-age=1800\r\n'
        'DATE: ${HttpDate.format(DateTime.now())}\r\n'
        'EXT:\r\n'
        'LOCATION: http://$localIp:$httpPort/ssdp/device-desc.xml\r\n'
        'SERVER: Windows/11 UPnP/1.0 Matcast/1.0\r\n'
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        'USN: uuid:$deviceId::urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        'BOOTID.UPNP.ORG: 1\r\n'
        'CONFIGID.UPNP.ORG: 1\r\n\r\n';

    final bytes = utf8.encode(response);
    _ssdpSocket?.send(bytes, target, port);
  }

  void _sendSsdpNotify(String friendlyName, String deviceId, String localIp) {
    if (_ssdpSocket == null) return;

    final notify = 'NOTIFY * HTTP/1.1\r\n'
        'HOST: $ssdpMulticast:$ssdpPort\r\n'
        'CACHE-CONTROL: max-age=1800\r\n'
        'LOCATION: http://$localIp:$httpPort/ssdp/device-desc.xml\r\n'
        'NT: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        'NTS: ssdp:alive\r\n'
        'SERVER: Windows/11 UPnP/1.0 Matcast/1.0\r\n'
        'USN: uuid:$deviceId::urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        'BOOTID.UPNP.ORG: 1\r\n'
        'CONFIGID.UPNP.ORG: 1\r\n\r\n';

    final bytes = utf8.encode(notify);

    try {
      // 1. Multicast to standard UPnP group
      _ssdpSocket!.send(bytes, InternetAddress(ssdpMulticast), ssdpPort);

      // 2. Broadcast on local subnet
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        _ssdpSocket!.send(bytes, InternetAddress(subnetBroadcast), ssdpPort);
      }

      // 3. Unicast directly to phone (192.168.10.18) if in same subnet
      if (localIp.startsWith('192.168.10.')) {
        _ssdpSocket!.send(bytes, InternetAddress('192.168.10.18'), ssdpPort);
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _notifyTimer?.cancel();
    _notifyTimer = null;

    try {
      _ssdpSocket?.close();
      _ssdpSocket = null;
    } catch (_) {}

    try {
      await _httpServer?.close(force: true);
      _httpServer = null;
    } catch (_) {}

    _isRunning = false;
  }
}
