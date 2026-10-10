import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/utils/app_routes.dart';
import '../../../../core/utils/secure_storage_util.dart';
import '../../../../core/network/api_client.dart';

class ConfigLoaderPage extends StatefulWidget {
  const ConfigLoaderPage({super.key});

  @override
  State<ConfigLoaderPage> createState() => _ConfigLoaderPageState();
}

class _ConfigLoaderPageState extends State<ConfigLoaderPage> {
  String _status = "Checking Master Engine connection...";

  @override
  void initState() {
    super.initState();
    _verifyAndConnect();
  }

  Future<void> _verifyAndConnect() async {
    // 1. Storage se IP nikalein
    String? savedIp = await SecureStorageUtil.getIp();

    if (savedIp == null) {
      setState(() => _status = "No configuration found.");
      Future.delayed(const Duration(seconds: 1), () => context.go(AppRoutes.settings));
      return;
    }

    // 2. Server se config.json fetch karein (Verification)
    try {
      final response = await http.get(Uri.parse("http://$savedIp:8090/config.json"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String currentIp = data['server_ip'];

        // Agar IP change hua hai, toh update kar do
        if (currentIp != savedIp) await SecureStorageUtil.saveIp(currentIp);

        // ApiClient ko set karo
        GetIt.I<ApiClient>().updateBaseUrl("http://$currentIp:8090");

        if (mounted) context.go(AppRoutes.login);
      } else {
        throw Exception("Server unreachable");
      }
    } catch (e) {
      setState(() => _status = "Connection failed. Please check your network.");
      Future.delayed(const Duration(seconds: 2), () => context.go(AppRoutes.settings));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE5A93C)),
            const SizedBox(height: 24),
            Text(_status, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}