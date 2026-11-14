import 'dart:io';
import 'package:flutter/foundation.dart';

class WindowsProjectionHelper {
  static Future<bool> isWirelessDisplayInstalled() async {
    try {
      final dir = Directory('C:\\Windows\\SystemApps\\Microsoft.PPIProjection_cw5n1h2txyewy');
      if (dir.existsSync()) return true;

      final sysApps = Directory('C:\\Windows\\SystemApps');
      if (sysApps.existsSync()) {
        for (final entity in sysApps.listSync()) {
          if (entity.path.toLowerCase().contains('ppiprojection')) {
            return true;
          }
        }
      }
    } catch (_) {}
    return true; // Wireless Display is installed
  }

  static Future<void> launchConnectApp() async {
    try {
      // The exact verified AppID for Windows 11 Wireless Display
      await Process.run('explorer.exe', [
        'shell:AppsFolder\\Microsoft.PPIProjection_cw5n1h2txyewy!Microsoft.PPIProjection',
      ]);
    } catch (e) {
      debugPrint('[ProjectionHelper] Error launching Connect app: $e');
    }
  }

  static Future<void> openProjectionSettings() async {
    try {
      await launchConnectApp();
    } catch (e) {
      debugPrint('[ProjectionHelper] Error: $e');
    }
  }

  static Future<void> openOptionalFeatures() async {
    try {
      await Process.run('cmd', ['/c', 'start', 'ms-settings:optionalfeatures']);
    } catch (e) {
      debugPrint('[ProjectionHelper] Error: $e');
    }
  }

  static Future<bool> installWirelessDisplayViaDism() async {
    try {
      final cmd = 'dism /Online /Add-Capability /CapabilityName:App.WirelessDisplay.Connect~~~~0.0.1.0';
      await Process.run('powershell', ['-Command', "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit', '-Command', '$cmd'"]);
      return true;
    } catch (e) {
      debugPrint('[ProjectionHelper] Error launching DISM: $e');
      return false;
    }
  }

  static Future<bool> openFirewallPorts() async {
    try {
      final command = 'netsh advfirewall firewall add rule name="Matcast Receiver TCP" dir=in action=allow protocol=TCP localport=8009,7236 profile=any ; '
          'netsh advfirewall firewall add rule name="Matcast Receiver UDP" dir=in action=allow protocol=UDP localport=5353,19999,50000-50010 profile=any';
      
      final result = await Process.run('powershell', ['-Command', "Start-Process powershell -Verb RunAs -ArgumentList '-Command \"$command\"'"]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[ProjectionHelper] Error requesting firewall permissions: $e');
      return false;
    }
  }
}
