import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class NetworkService {
  static Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('vmnet') ||
            name.contains('virtual') ||
            name.contains('vethernet') ||
            name.contains('bluetooth')) {
          continue;
        }
        for (final address in interface.addresses) {
          final ip = address.address;
          if (!address.isLoopback &&
              address.type == InternetAddressType.IPv4 &&
              _isValidLanIp(ip)) {
            ips.add(ip);
          }
        }
      }
    } catch (_) {
      ips.add('192.168.10.11');
    }
    return ips;
  }

  static Future<String> getPrimaryLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // 1. Search for primary physical Ethernet / Wi-Fi
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('vmnet') ||
            name.contains('virtual') ||
            name.contains('vethernet') ||
            name.contains('bluetooth')) {
          continue;
        }

        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isValidLanIp(ip)) {
            return ip;
          }
        }
      }

      // 2. Secondary pass
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isValidLanIp(ip) && !ip.startsWith('192.168.207.') && !ip.startsWith('192.168.50.')) {
            return ip;
          }
        }
      }
    } catch (_) {}

    return '192.168.10.11';
  }

  static bool _isValidLanIp(String ip) {
    if (ip.startsWith('127.') ||
        ip.startsWith('169.254.') ||
        ip == '0.0.0.0' ||
        ip == '8.8.8.8' ||
        ip.startsWith('192.168.207.') ||
        ip.startsWith('192.168.50.')) {
      return false;
    }
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(ip);
  }

  static Future<bool> isLocalAddress(String ip) async {
    if (ip == '127.0.0.1' || ip == '::1' || ip == 'localhost' || ip == '0.0.0.0') {
      return true;
    }
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: true);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.address == ip) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  static String generateDeviceId(String machineName) {
    final clean = machineName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final bytes = utf8.encode(clean + Platform.localHostname);
    return md5.convert(bytes).toString();
  }
}
