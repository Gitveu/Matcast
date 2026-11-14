import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/cast_device.dart';
import 'cast_certificates.dart';
import 'network_service.dart';

class CastMessageData {
  final int protocolVersion;
  final String sourceId;
  final String destinationId;
  final String namespace;
  final int payloadType; // 0: String, 1: Binary
  final String? payloadUtf8;
  final Uint8List? payloadBinary;

  CastMessageData({
    this.protocolVersion = 0,
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    this.payloadType = 0,
    this.payloadUtf8,
    this.payloadBinary,
  });

  Uint8List encode() {
    final buffer = BytesBuilder();

    // Helper for varint
    void writeVarint(int value) {
      while (value >= 0x80) {
        buffer.addByte((value & 0x7f) | 0x80);
        value >>= 7;
      }
      buffer.addByte(value & 0x7f);
    }

    void writeString(int tag, String str) {
      final bytes = utf8.encode(str);
      writeVarint((tag << 3) | 2); // Length-delimited
      writeVarint(bytes.length);
      buffer.add(bytes);
    }

    // 1. protocol_version (tag 1, varint)
    writeVarint((1 << 3) | 0);
    writeVarint(protocolVersion);

    // 2. source_id (tag 2, string)
    writeString(2, sourceId);

    // 3. destination_id (tag 3, string)
    writeString(3, destinationId);

    // 4. namespace (tag 4, string)
    writeString(4, namespace);

    // 5. payload_type (tag 5, varint)
    writeVarint((5 << 3) | 0);
    writeVarint(payloadType);

    // 6. payload_utf8 (tag 6, string)
    if (payloadUtf8 != null) {
      writeString(6, payloadUtf8!);
    }

    // 7. payload_binary (tag 7, bytes)
    if (payloadBinary != null && payloadBinary!.isNotEmpty) {
      writeVarint((7 << 3) | 2);
      writeVarint(payloadBinary!.length);
      buffer.add(payloadBinary!);
    }

    final msgBytes = buffer.toBytes();
    // Wrap with 4-byte big endian length prefix
    final framed = BytesBuilder();
    final lenData = ByteData(4)..setUint32(0, msgBytes.length, Endian.big);
    framed.add(lenData.buffer.asUint8List());
    framed.add(msgBytes);

    return framed.toBytes();
  }

  static CastMessageData? decode(Uint8List bytes) {
    try {
      int offset = 0;
      int protocolVersion = 0;
      String sourceId = '';
      String destinationId = '';
      String namespace = '';
      int payloadType = 0;
      String? payloadUtf8;
      Uint8List? payloadBinary;

      int readVarint() {
        int result = 0;
        int shift = 0;
        while (offset < bytes.length) {
          final b = bytes[offset++];
          result |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        return result;
      }

      while (offset < bytes.length) {
        final key = readVarint();
        final tag = key >> 3;
        final wireType = key & 0x07;

        if (wireType == 0) {
          // Varint
          final val = readVarint();
          if (tag == 1) protocolVersion = val;
          if (tag == 5) payloadType = val;
        } else if (wireType == 2) {
          // Length-delimited
          final len = readVarint();
          if (offset + len > bytes.length) break;
          final sub = bytes.sublist(offset, offset + len);
          offset += len;

          if (tag == 2) sourceId = utf8.decode(sub, allowMalformed: true);
          if (tag == 3) destinationId = utf8.decode(sub, allowMalformed: true);
          if (tag == 4) namespace = utf8.decode(sub, allowMalformed: true);
          if (tag == 6) payloadUtf8 = utf8.decode(sub, allowMalformed: true);
          if (tag == 7) payloadBinary = sub;
        } else {
          // Skip other wire types
          break;
        }
      }

      return CastMessageData(
        protocolVersion: protocolVersion,
        sourceId: sourceId,
        destinationId: destinationId,
        namespace: namespace,
        payloadType: payloadType,
        payloadUtf8: payloadUtf8,
        payloadBinary: payloadBinary,
      );
    } catch (e) {
      debugPrint('Error decoding CastMessage: $e');
      return null;
    }
  }
}

class CastProtocolServer {
  SecureServerSocket? _server;
  final int port;
  final Function(CastDevice) onDeviceConnected;
  final Function(CastDevice) onDeviceDisconnected;
  final Function(String event, Map<String, dynamic> data) onProtocolEvent;
  final Function(String streamUrl) onStreamAvailable;

  final List<SecureSocket> _activeSockets = [];
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  CastProtocolServer({
    this.port = 8009,
    required this.onDeviceConnected,
    required this.onDeviceDisconnected,
    required this.onProtocolEvent,
    required this.onStreamAvailable,
  });

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      final context = SecurityContext(withTrustedRoots: false);
      context.useCertificateChainBytes(utf8.encode(CastCertificates.certPem));
      context.usePrivateKeyBytes(utf8.encode(CastCertificates.keyPem));

      _server = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        context,
        shared: true,
      );

      _isRunning = true;
      debugPrint('[CastProtocolServer] Listening on port $port');
      _server!.listen(
        _handleClient,
        onError: (e) {
          debugPrint('CastProtocolServer socket error: $e');
        },
        onDone: () {
          _isRunning = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to start CastProtocolServer: $e');
      _isRunning = false;
      return false;
    }
  }

  void _handleClient(SecureSocket socket) async {
    final clientIp = socket.remoteAddress.address;
    if (await NetworkService.isLocalAddress(clientIp)) {
      debugPrint('[CastProtocolServer] Local loopback/interface probe ignored: $clientIp');
      socket.destroy();
      return;
    }

    final clientPort = socket.remotePort;
    final device = CastDevice(
      id: 'android_${clientIp.replaceAll('.', '_')}',
      name: 'Android Device ($clientIp)',
      ipAddress: clientIp,
      port: clientPort,
      protocol: CastProtocol.googleCast,
      connectedAt: DateTime.now(),
    );

    _activeSockets.add(socket);
    onDeviceConnected(device);

    final buffer = BytesBuilder();

    socket.listen(
      (data) {
        buffer.add(data);
        _processBuffer(buffer, socket, device);
      },
      onError: (e) {
        debugPrint('Client socket error: $e');
        _cleanupSocket(socket, device);
      },
      onDone: () {
        _cleanupSocket(socket, device);
      },
    );
  }

  void _processBuffer(BytesBuilder buffer, SecureSocket socket, CastDevice device) {
    Uint8List current = buffer.toBytes();
    while (current.length >= 4) {
      final byteData = ByteData.sublistView(current);
      final payloadLen = byteData.getUint32(0, Endian.big);

      if (current.length < 4 + payloadLen) {
        // Incomplete message, wait for more chunks
        break;
      }

      final messageBytes = current.sublist(4, 4 + payloadLen);
      final remaining = current.sublist(4 + payloadLen);

      buffer.clear();
      buffer.add(remaining);
      current = remaining;

      final castMsg = CastMessageData.decode(messageBytes);
      if (castMsg != null) {
        _handleCastMessage(castMsg, socket, device);
      }
    }
  }

  void _handleCastMessage(
    CastMessageData msg,
    SecureSocket socket,
    CastDevice device,
  ) {
    onProtocolEvent(msg.namespace, {
      'source': msg.sourceId,
      'destination': msg.destinationId,
      'payload': msg.payloadUtf8,
    });

    // 1. Heartbeat namespace: Ping -> Pong
    if (msg.namespace == 'urn:x-cast:com.google.cast.tp.heartbeat') {
      try {
        final json = jsonDecode(msg.payloadUtf8 ?? '{}');
        if (json['type'] == 'PING') {
          final pong = CastMessageData(
            sourceId: msg.destinationId,
            destinationId: msg.sourceId,
            namespace: msg.namespace,
            payloadType: 0,
            payloadUtf8: jsonEncode({'type': 'PONG'}),
          );
          socket.add(pong.encode());
        }
      } catch (_) {}
    }

    // 2. Connection namespace: CONNECT
    if (msg.namespace == 'urn:x-cast:com.google.cast.tp.connection') {
      try {
        final json = jsonDecode(msg.payloadUtf8 ?? '{}');
        if (json['type'] == 'CONNECT') {
          debugPrint('Android device CONNECT request received from ${device.ipAddress}');
        }
      } catch (_) {}
    }

    // 3. Receiver namespace: GET_STATUS
    if (msg.namespace == 'urn:x-cast:com.google.cast.receiver') {
      try {
        final json = jsonDecode(msg.payloadUtf8 ?? '{}');
        final requestId = json['requestId'] ?? 1;

        if (json['type'] == 'GET_STATUS') {
          final responsePayload = {
            'type': 'RECEIVER_STATUS',
            'requestId': requestId,
            'status': {
              'volume': {
                'level': 1.0,
                'muted': false,
                'controlType': 'attenuation',
                'stepInterval': 0.05,
              },
              'applications': [
                {
                  'appId': '00000000',
                  'displayName': 'Android Screen Mirror',
                  'sessionId': 'matcast-session-${device.id}',
                  'statusText': 'Active Mirroring',
                  'isIdleScreen': false,
                  'namespaces': [
                    {'name': 'urn:x-cast:com.google.cast.streaming.session'},
                    {'name': 'urn:x-cast:com.google.cast.webrtc'},
                    {'name': 'urn:x-cast:com.google.cast.media'},
                  ],
                }
              ],
            },
          };

          final responseMsg = CastMessageData(
            sourceId: msg.destinationId,
            destinationId: msg.sourceId,
            namespace: msg.namespace,
            payloadType: 0,
            payloadUtf8: jsonEncode(responsePayload),
          );
          socket.add(responseMsg.encode());
        }
      } catch (_) {}
    }

    // 4. Device Authentication challenge
    if (msg.namespace == 'urn:x-cast:com.google.cast.tp.deviceauth') {
      debugPrint('DeviceAuth challenge received from Android device ${device.ipAddress}');
      // Respond with authentication acknowledgment
      final authResponse = CastMessageData(
        sourceId: msg.destinationId,
        destinationId: msg.sourceId,
        namespace: msg.namespace,
        payloadType: 0,
        payloadUtf8: jsonEncode({
          'type': 'DEVICE_AUTH_RESPONSE',
          'status': 'OK',
        }),
      );
      socket.add(authResponse.encode());
    }

    // 5. Mirroring / WebRTC / Streaming session namespace
    if (msg.namespace == 'urn:x-cast:com.google.cast.webrtc' ||
        msg.namespace == 'urn:x-cast:com.google.cast.streaming.session') {
      debugPrint('Streaming offer received from Android: ${msg.payloadUtf8}');
      try {
        final json = jsonDecode(msg.payloadUtf8 ?? '{}');
        if (json['type'] == 'OFFER' || json['type'] == 'PRESENTATION_OFFER') {
          // If SDP or stream port provided:
          onStreamAvailable('udp://@:50000');
        }
      } catch (_) {}
    }
  }

  void _cleanupSocket(SecureSocket socket, CastDevice device) {
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
