import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';


class LicenseActivationPage extends StatefulWidget {
  final VoidCallback onActivated;
  const LicenseActivationPage({super.key, required this.onActivated});

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final TextEditingController _keyController = TextEditingController();
  String _machineId = 'Reading Hardware ID...';
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMachineId();
  }

  Future<void> _loadMachineId() async {
    String id = await JsonLicenseService.getMachineFingerprint();
    if (mounted) {
      setState(() {
        _machineId = id;
      });
    }
  }

  void _verifyAndActivate() async {
    if (_keyController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '⚠️ Please enter the RSA License Key!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    bool success = await JsonLicenseService.activateLicense(_keyController.text);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        widget.onActivated();
      } else {
        setState(() {
          _errorMessage = '❌ Invalid RSA License Key for this Machine!';
        });
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "SOFTWARE ACTIVATION REQUIRED",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please share your Machine ID with Svenska support to receive your RSA activation key.",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 20),

              // Machine ID Box
              const Text(
                "YOUR MACHINE ID:",
                style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _machineId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Machine ID copied to clipboard!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _machineId,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.copy, color: Color(0xFF00BCD4), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Key Input Field
              const Text(
                "ENTER RSA LICENSE SIGNATURE KEY:",
                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _keyController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  hintText: 'Paste Base64 RSA Key here...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ],
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _isLoading ? null : _verifyAndActivate,
                  child: _isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    "ACTIVATE LICENSE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}