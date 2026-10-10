import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageUtil {
  static const _storage = FlutterSecureStorage();

  static const String keyIp = 'master_ip';
  static const String keyToken = 'auth_token';
  static const String userTenant = 'tenant_id';

  // IP Operations
  // SecureStorageUtil.dart mein
  static Future<void> saveIp(String ip) async {
    try {
      await _storage.write(key: keyIp, value: ip);
      debugPrint("✅ [SecureStorage]: IP $ip successfully written.");
    } catch (e) {
      debugPrint("❌ [SecureStorage]: Write Error -> $e");
    }
  }
  static Future<String?> getIp() async => await _storage.read(key: keyIp);

  static Future<void> saveToken(String token) async => await _storage.write(key: keyToken, value: token);
  static Future<String?> getToken() async => await _storage.read(key: keyToken);

  static Future<void> saveUserTenant(String tenant) async => await _storage.write(key: userTenant, value: tenant);
  static Future<String?> getUserTenant() async => await _storage.read(key: userTenant);


  // Clear Utility
  static Future<void> clearAll() async => await _storage.deleteAll();
}