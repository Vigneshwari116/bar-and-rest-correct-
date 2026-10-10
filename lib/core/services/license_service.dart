import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class JsonLicenseService {
  static const bool demoMode = true;
  static const String _privateMasterKey = "SVENSKA_POS_MASTER_RSA_SECRET_KEY_2026_@#\$99X";

  static Future<File> _getLicenseFile() async {
    final Directory directory = await getApplicationSupportDirectory();
    return File('${directory.path}/license_auth.json');
  }

  // 🖥️ PC Hardware Fingerprint
  static Future<String> getMachineFingerprint() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll('-', '')
            .trim()
            .toUpperCase();
      }
    } catch (_) {}
    return 'UNKNOWN_PC';
  }

  // 🔑 Digital Signature Verification
  static bool verifyRsaSignature(String machineId, String signatureBase64) {
    try {
      String cleanId = machineId
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('-', '')
          .trim()
          .toUpperCase();

      var keyBytes = utf8.encode(_privateMasterKey);
      var hmac = Hmac(sha256, keyBytes);
      var digest = hmac.convert(utf8.encode(cleanId));

      String expectedSignature = base64.encode(digest.bytes);

      return inputSignatureBase64Clean(signatureBase64) == expectedSignature;
    } catch (e) {
      debugPrint("🔴 [Verification Failed]: $e");
      return false;
    }
  }

  static String inputSignatureBase64Clean(String input) {
    return input.trim();
  }

  // ✅ 1. Activate License
  static Future<bool> activateLicense(String inputSignatureBase64) async {
    try {
      String machineId = await getMachineFingerprint();

      bool isValid = verifyRsaSignature(machineId, inputSignatureBase64);

      if (isValid) {
        final File file = await _getLicenseFile();

        final Map<String, dynamic> licenseData = {
          'activated_license_key': inputSignatureBase64.trim(),
          'registered_machine_id': machineId,
          'activated_at': DateTime.now().toIso8601String(),
        };

        await file.writeAsString(jsonEncode(licenseData));
        return true;
      }
    } catch (e) {
      debugPrint("🔴 [Activation Exception]: $e");
    }
    return false;
  }

  // 🔍 2. Startup Verification Check

    static Future<bool> isLicenseValid() async {
  if (demoMode) {
    debugPrint("🛠️ [Demo Mode]: License check disabled.");
    return true;
  }

  if (kDebugMode) {
    debugPrint("🛠️ [Dev Mode]: License check bypassed.");
    return true;
  }

    try {
      final File file = await _getLicenseFile();
      if (!await file.exists()) return false;

      final String contents = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(contents);

      String? savedKey = data['activated_license_key'];
      String? savedMachineId = data['registered_machine_id'];

      if (savedKey == null || savedMachineId == null) return false;

      String currentMachineId = await getMachineFingerprint();
      if (savedMachineId != currentMachineId) return false;

      return verifyRsaSignature(currentMachineId, savedKey);
    } catch (e) {
      debugPrint("🔴 [License Check Exception]: $e");
      return false;
    }
  }
}