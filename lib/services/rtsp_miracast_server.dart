import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cast_device.dart';

class RtspMiracastServer {
  ServerSocket? _server;
  final int port;
  final int rtpPort;
  final Function(CastDevice) onDeviceConnected;
  final Function(CastDevice) onDeviceDisconnected;
  final Function(String event, Map<String, dynamic> data) onProtocolEvent;
  final Function(String streamUrl) onStreamAvailable;

  final List<Socket> _activeSockets = [];
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  RtspMiracastServer({
    this.port = 7236, // Standard Wi-Fi Display / Miracast RTSP port
    this.rtpPort = 19999,
    required this.onDeviceConnected,
    required this.onDeviceDisconnected,
    required this.onProtocolEvent,
    required this.onStreamAvailable,
  });

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      _isRunning = true;
      _server!.listen(
        _handleClient,
        onError: (e) {
          debugPrint('RtspMiracastServer socket error: $e');
        },
        onDone: () {
          _isRunning = false;
        },
      );

      debugPrint('RtspMiracastServer listening on port $port');
      return true;
    } catch (e) {
      debugPrint('Failed to start RtspMiracastServer: $e');
      _isRunning = false;
      return false;
    }
  }

  void _handleClient(Socket socket) {
    final clientIp = socket.remoteAddress.address;
    final clientPort = socket.remotePort;
    final device = CastDevice(
      id: 'miracast_${clientIp.replaceAll('.', '_')}',
      name: 'Android Miracast ($clientIp)',
      ipAddress: clientIp,
      port: clientPort,
      protocol: CastProtocol.miracast,
      connectedAt: DateTime.now(),
    );

    _activeSockets.add(socket);
    onDeviceConnected(device);

    final stringBuffer = StringBuffer();

    socket.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        stringBuffer.write(text);
        _processRtspBuffer(stringBuffer, socket, device);
      },
      onError: (e) {
        debugPrint('Miracast client socket error: $e');
        _cleanupSocket(socket, device);
      },
      onDone: () {
        _cleanupSocket(socket, device);
      },
    );
  }

  void _processRtspBuffer(StringBuffer buffer, Socket socket, CastDevice device) {
    final content = buffer.toString();
    final requests = content.split('\r\n\r\n');

    if (requests.length > 1) {
      for (int i = 0; i < requests.length - 1; i++) {
        final req = requests[i].trim();
        if (req.isNotEmpty) {
          _handleRtspRequest(req, socket, device);
        }
      }
      buffer.clear();
      buffer.write(requests.last);
    }
  }

  void _handleRtspRequest(String request, Socket socket, CastDevice device) {
    final lines = request.split('\r\n');
    if (lines.isEmpty) return;

    final requestLine = lines[0].split(' ');
    if (requestLine.length < 3) return;

    final method = requestLine[0];
    final uri = requestLine[1];
    int cseq = 1;

    for (final line in lines) {
      if (line.toLowerCase().startsWith('cseq:')) {
        cseq = int.tryParse(line.split(':')[1].trim()) ?? 1;
      }
    }

    onProtocolEvent('RTSP $method', {
      'method': method,
      'uri': uri,
      'cseq': cseq,
      'device': device.ipAddress,
    });

    switch (method) {
      case 'OPTIONS':
        _sendRtspResponse(socket, cseq, [
          'Public: org.wfa.wfd1.0, OPTIONS, GET_PARAMETER, SET_PARAMETER, SETUP, PLAY, TEARDOWN',
        ]);
        break;

      case 'GET_PARAMETER':
        final body = 'wfd_video_formats: 00 00 02 02 00000040 00000000 00000000 00 0000 0000 00 none none\r\n'
            'wfd_audio_codecs: AAC 00000001 00\r\n'
            'wfd_client_rtpports: RTP/AVP/UDP;unicast $rtpPort 0 mode=play\r\n'
            'wfd_connector_type: 05\r\n'
            'wfd_uibc_capability: none\r\n';

        _sendRtspResponse(socket, cseq, [
          'Content-Type: text/parameters',
          'Content-Length: ${body.length}',
        ], body: body);
        break;

      case 'SET_PARAMETER':
        _sendRtspResponse(socket, cseq, []);
        break;

      case 'SETUP':
        _sendRtspResponse(socket, cseq, [
          'Session: 184572;timeout=60',
          'Transport: RTP/AVP/UDP;unicast;client_port=$rtpPort;server_port=$rtpPort',
        ]);
        break;

      case 'PLAY':
        _sendRtspResponse(socket, cseq, [
          'Session: 184572',
          'Range: npt=now-',
        ]);
        // Trigger media playback
        onStreamAvailable('udp://@:$rtpPort');
        break;

      case 'TEARDOWN':
        _sendRtspResponse(socket, cseq, [
          'Session: 184572',
        ]);
        break;

      default:
        _sendRtspResponse(socket, cseq, []);
        break;
    }
  }

  void _sendRtspResponse(
    Socket socket,
    int cseq,
    List<String> headers, {
    String? body,
  }) {
    final response = StringBuffer();
    response.write('RTSP/1.0 200 OK\r\n');
    response.write('CSeq: $cseq\r\n');
    for (final h in headers) {
      response.write('$h\r\n');
    }
    response.write('\r\n');
    if (body != null) {
      response.write(body);
    }

    try {
      socket.write(response.toString());
    } catch (e) {
      debugPrint('Failed to send RTSP response: $e');
    }
  }

  void _cleanupSocket(Socket socket, CastDevice device) {
    _activeSockets.remove(socket);
    try {
      socket.destroy();
    } catch (_) {}
    onDeviceDisconnected(device);
  }

  Future<void> stop() async {
    for (final s in _activeSockets) {
      try {
        s.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();
    await _server?.close();
    _server = null;
    _isRunning = false;
  }
}
