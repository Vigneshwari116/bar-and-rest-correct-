import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../../core/utils/secure_storage_util.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIp() async {
    String? currentIp = await SecureStorageUtil.getIp();
    if (currentIp != null) {
      setState(() {
        _ipController.text = currentIp;
      });
    }
  }

  Future<void> _saveAndConnect() async {
    String newIp = _ipController.text.trim();
    if (newIp.isEmpty) {
      _showError("IP address cannot be empty");
      return;
    }

    setState(() => _isConnecting = true);

    try {
      debugPrint("📡 [Settings]: Testing connection to $newIp:8090...");

      final response = await http
          .get(Uri.parse("http://$newIp:8090/api/v1/test"))
          .timeout(const Duration(seconds: 5));

      debugPrint("📡 [Settings]: Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        debugPrint("✅ [Settings]: Engine reachable! Saving IP...");

        await SecureStorageUtil.saveIp(newIp);
        GetIt.I<ApiClient>().updateBaseUrl("http://$newIp:8090");

        if (mounted) {
          setState(() => _isConnecting = false);
          _showSnackBar("Connected successfully to Master Engine!", isError: false);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) context.go(AppRoutes.login);
        }
      } else {
        throw Exception("Server responded with ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) setState(() => _isConnecting = false);
      debugPrint("❌ [Settings Error]: $e");
      _showError("Master Engine Unreachable at http://$newIp:8090");
    }
  }

  // 🌟 ALERT DIALOG: HARD SYSTEM RESET
  Future<void> _showClearDatabaseDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "HARD SYSTEM RESET",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: screenWidth > 450 ? 400 : screenWidth * 0.9,
            child: const Text(
              "Are you sure you want to clear the transactional database?\n\n"
                  "• Wipes: All Bills, KOTs, Archives & Live Ledgers.\n"
                  "• Preserves: Items, Categories, Users & Tables.",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                _executeDatabaseWipe();
              },
              child: const Text("YES, WIPE BILLS", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeDatabaseWipe() async {
    setState(() => _isConnecting = true);
    try {
      final ApiClient client = GetIt.I<ApiClient>();
      final response = await client.post('/api/v1/reports/clear-system-database');

      if (mounted) setState(() => _isConnecting = false);

      if (response != null && response.data['status'] == 'SUCCESS') {
        _showSnackBar("Database cleared successfully! Items & Users are safe.", isError: false);
      } else {
        _showError("Failed to reset database.");
      }
    } catch (e) {
      if (mounted) setState(() => _isConnecting = false);
      _showError("Wipe Error: $e");
    }
  }

  void _showError(String message) {
    _showSnackBar(message, isError: true);
  }

  void _showSnackBar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final double formWidth = isMobile ? constraints.maxWidth : 460.0;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              isMobile ? "MASTER CONFIG" : "MASTER SYSTEM CONFIGURATION",
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            actions: [
/*
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 10.0, bottom: 10.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2).withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                  ),
                  onPressed: _showClearDatabaseDialog,
                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 15),
                  label: Text(
                    isMobile ? "CLEAR DB" : "CLEAR DATABASE",
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
*/
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Container(
                width: formWidth,
                padding: EdgeInsets.all(isMobile ? 20.0 : 28.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF12161F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2533), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER CARD INFO
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.dns_rounded, color: Colors.amber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Master Engine Endpoint",
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Configure Server Local IP & Port 8090",
                                style: TextStyle(color: Color(0xFF7A849C), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // INPUT LABEL
                    const Text(
                      "MASTER ENGINE IP ADDRESS",
                      style: TextStyle(color: Color(0xFF7A849C), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),

                    // TEXTFIELD
                    TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      cursorColor: Colors.amber,
                      decoration: InputDecoration(
                        hintText: "e.g. 192.168.1.100",
                        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                        prefixIcon: const Icon(Icons.wifi_rounded, size: 16, color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF0B0E14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1F2533)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PORT INFO
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2533).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF7A849C), size: 13),
                          SizedBox(width: 6),
                          Text(
                            "Default Gateway Port: 8090 (/api/v1/test)",
                            style: TextStyle(color: Color(0xFF7A849C), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isConnecting ? null : _saveAndConnect,
                        child: _isConnecting
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync_rounded, size: 16, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              "SAVE & CONNECT ENGINE",
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}