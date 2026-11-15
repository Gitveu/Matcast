import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class NetworkService {
  static const _virtualKeywords = [
    'vmnet',
    'virtual',
    'vbox',
    'vethernet',
    'wsl',
    'hyper-v',
    'tailscale',
    'wireguard',
    'zerotier',
    'tap',
    'npcap',
    'bluetooth',
    'docker',
    'loopback',
  ];

  static bool _isVirtualInterface(String name) {
    final lower = name.toLowerCase();
    for (final kw in _virtualKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  static Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        if (_isVirtualInterface(interface.name)) {
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
    } catch (_) {}
    return ips;
  }

  static Future<String> getPrimaryLocalIp() async {
    // 1. First attempt: Ask OS kernel which local address routes outbound
    try {
      final s = await Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 600));
      final ip = s.address.address;
      await s.close();
      if (_isValidLanIp(ip)) {
        return ip;
      }
    } catch (_) {}

    // 2. Iterate network interfaces, prioritizing physical non-virtual LAN adapters
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Pass 1: Physical non-virtual adapters
      for (final iface in interfaces) {
        if (_isVirtualInterface(iface.name)) continue;
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isValidLanIp(ip)) {
            return ip;
          }
        }
      }

      // Pass 2: Any adapter with valid private LAN IP
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isValidLanIp(ip)) {
            return ip;
          }
        }
      }

      // Pass 3: First IPv4 address
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    return '127.0.0.1';
  }

  static bool _isValidLanIp(String ip) {
    if (ip.startsWith('127.') ||
        ip.startsWith('169.254.') ||
        ip == '0.0.0.0' ||
        ip == '255.255.255.255') {
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
