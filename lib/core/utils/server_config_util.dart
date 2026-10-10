import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

Future<void> generateServerConfig(int port) async {
  try {
    // 1. Network interfaces ki list nikalen
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    // 2. Wi-Fi adapter dhundhein (Windows par ye usually 'Wi-Fi' hota hai)
    // Agar Wi-Fi na mile toh pehla available interface le lein
    final activeInterface = interfaces.firstWhere(
            (i) => i.name.toLowerCase().contains('wi-fi'),
        orElse: () => interfaces.first
    );

    final String ip = activeInterface.addresses.first.address;

    // 3. Config object taiyaar karein
    final config = {
      "server_ip": ip,
      "port": port,
      "generated_at": DateTime.now().toIso8601String()
    };

    // 4. Root folder mein 'server_config.json' save karein
    final file = File('server_config.json');
    await file.writeAsString(jsonEncode(config));

    debugPrint("🚀 [Master]: IP $ip saved to server_config.json on port $port!");
  } catch (e) {
    debugPrint("❌ [Config Error]: Could not generate config - $e");
  }
}