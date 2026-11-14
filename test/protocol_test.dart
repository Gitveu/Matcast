import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcast/models/cast_device.dart';
import 'package:matcast/models/stream_stats.dart';
import 'package:matcast/services/cast_protocol_server.dart';
import 'package:matcast/services/network_service.dart';

void main() {
  group('Matcast Protocol & Models Tests', () {
    test('CastMessageData protobuf encode & decode', () {
      final original = CastMessageData(
        protocolVersion: 0,
        sourceId: 'sender-01',
        destinationId: 'receiver-01',
        namespace: 'urn:x-cast:com.google.cast.tp.heartbeat',
        payloadType: 0,
        payloadUtf8: jsonEncode({'type': 'PING'}),
      );

      final encoded = original.encode();
      expect(encoded.length, greaterThan(4));

      // Cut 4-byte length prefix
      final payloadOnly = encoded.sublist(4);
      final decoded = CastMessageData.decode(payloadOnly);

      expect(decoded, isNotNull);
      expect(decoded!.sourceId, equals('sender-01'));
      expect(decoded.destinationId, equals('receiver-01'));
      expect(decoded.namespace, equals('urn:x-cast:com.google.cast.tp.heartbeat'));
      expect(decoded.payloadUtf8, equals('{"type":"PING"}'));
    });

    test('NetworkService device id generation', () {
      final id1 = NetworkService.generateDeviceId('Matcast-PC');
      final id2 = NetworkService.generateDeviceId('Matcast-PC');
      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
    });

    test('StreamStats default values and copyWith', () {
      final stats = StreamStats.empty();
      expect(stats.fps, equals(0.0));
      expect(stats.resolution, equals('0x0'));

      final updated = stats.copyWith(
        fps: 60.0,
        bitrateMbps: 15.2,
        resolution: '1080x2400',
        latencyMs: 35,
      );

      expect(updated.fps, equals(60.0));
      expect(updated.bitrateMbps, equals(15.2));
      expect(updated.resolution, equals('1080x2400'));
      expect(updated.latencyMs, equals(35));
    });

    test('CastDevice copyWith and protocols', () {
      final device = CastDevice(
        id: 'dev_1',
        name: 'Pixel 9 Pro',
        ipAddress: '192.168.1.50',
        port: 8009,
        protocol: CastProtocol.googleCast,
        connectedAt: DateTime.now(),
      );

      expect(device.protocol.label, equals('Google Cast'));
      final updated = device.copyWith(name: 'Pixel 9 Pro XL');
      expect(updated.name, equals('Pixel 9 Pro XL'));
      expect(updated.ipAddress, equals('192.168.1.50'));
    });
  });
}
