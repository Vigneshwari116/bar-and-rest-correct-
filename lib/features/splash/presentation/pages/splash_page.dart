import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/license_service.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../../core/utils/secure_storage_util.dart';
import '../../../../core/widgets/licence_activation_page.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isLicenseInvalid = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _checkLicenseAndNavigate();
  }

  Future<void> _checkLicenseAndNavigate() async {
    // Artificial delay to let splash animations play out beautifully
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // ⚡ 1. OFFLINE LICENSE VALIDATION CHECK
    // (Dev mode me automatic true dega, Release/EXE mode me JSON file check karega)
    bool isAuthorized = await JsonLicenseService.isLicenseValid();

    if (!isAuthorized) {
      debugPrint("🚨 [Svenska Security Matrix]: License invalid or machine fingerprint mismatch detected. Forcing Activation screen.");
      setState(() {
        _isLicenseInvalid = true;
      });

      if (mounted) {
        // Redirect to License Activation Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LicenseActivationPage(
              onActivated: () {
                context.go(AppRoutes.splash);
              },
            ),
          ),
        );
      }
      return; // Pipeline break taaki aage ka network / routing logic execute na ho
    }

    // --- 2. CONTINUING ORIGINAL SYSTEM PIPELINE LOGIC IF LICENSE IS VALID ---
    final bool isMasterServer = !kIsWeb && (dotenv.env['IS_MASTER_SERVER']?.toLowerCase() == 'true');
    final apiClient = GetIt.I<ApiClient>();

    try {
      if (isMasterServer) {
        // --- MASTER PC SERVER ENGINE LOGIC ---
        // The server runs inside this same app, so always talk to it via loopback.
        // (server_config.json is only for OTHER devices; its LAN IP can be stale.)
        apiClient.updateBaseUrl("http://127.0.0.1:8090");
        _proceedBasedOnSession(await SecureStorageUtil.getToken());

      } else {
        // --- 📱 MOBILE / WINDOWS CLIENT TERMINALS LOGIC ---
        String? savedIp = await SecureStorageUtil.getIp();

        // Strict validation check loop parameters
        if (savedIp == null ||
            savedIp.isEmpty ||
            savedIp == '127.0.0.1' ||
            savedIp.toLowerCase() == 'localhost') {

          debugPrint("🚨 [Splash Core]: Secure Master IP invalid or missing. Forcing settings view redirect.");
          if (mounted) context.go(AppRoutes.settings);

        } else {
          debugPrint("🔗 [Splash Core]: Handshaking established with master node endpoint: http://$savedIp:8090");
          apiClient.updateBaseUrl("http://$savedIp:8090");
          _proceedBasedOnSession(await SecureStorageUtil.getToken());
        }
      }
    } catch (e) {
      debugPrint("❌ [Splash Crash Exception Handled Safety Override]: $e");
      if (mounted) context.go(AppRoutes.settings);
    }
  }

  void _proceedBasedOnSession(String? token) {
    if (token != null && token.isNotEmpty) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Icon(Icons.wine_bar_rounded, size: 60, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              const Text(
                'SVENSKA POS ENGINE',
                style: TextStyle(fontFamily: 'Lato-Black', fontSize: 22, color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _isLicenseInvalid
                    ? 'WAITING FOR LICENSE ACTIVATION...'
                    : 'ESTABLISHING INTERFACE SYNCHRONIZATION...',
                style: TextStyle(fontSize: 9, color: _isLicenseInvalid ? Colors.redAccent : const Color(0xFF6C7A93), letterSpacing: 2, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 18,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.amber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}