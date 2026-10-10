import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _accessTokenKey = "accessToken";
  static const _userTypeKey = "userType";
  static const _refreshTokenKey = "refreshToken";


  Future<void> saveSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }


  Future<void> saveAuthData(String token, String userType ,String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    await _secureStorage.write(key: _userTypeKey, value: userType);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

  }

  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<String?> getUserType() async {
    final type = await _secureStorage.read(key: _userTypeKey);
    return (type == null || type.isEmpty) ? null : type;
  }

  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _userTypeKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
