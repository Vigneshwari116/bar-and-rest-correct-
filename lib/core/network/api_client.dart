
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:svenska/core/utils/app_routes.dart';
import '../../injection.dart'; // Yahan 'sl' (GetIt) hai
import '../utils/constant/Endpoints.dart';
import '../utils/secure_storage_util.dart';
import 'network_info.dart';

class ApiClient {
  final Dio _dio;
  final NetworkInfo _networkInfo;

  String get currentBaseUrl => _dio.options.baseUrl;

  ApiClient(this._dio, this._networkInfo) {
    _dio.options = BaseOptions(
      baseUrl: Endpoints.baseUrl.isEmpty ? "http://not-configured-yet" : Endpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );

    _dio.interceptors.add(LogInterceptor(
      requestHeader: true, requestBody: true, responseHeader: true,
      responseBody: true, error: true,
      logPrint: (obj) => debugPrint("📦 [DIO LOG]: $obj"),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. IP Check & Auto-Redirect
          if (options.baseUrl.contains("not-configured-yet")) {
            final savedIp = await SecureStorageUtil.getIp();
            if (savedIp == null || savedIp.isEmpty) {
              debugPrint("🚨 [IP Error]: IP Missing! Redirecting to Settings...");
              AppRouter.router.go(AppRoutes.settings);
              return handler.reject(DioException(requestOptions: options, error: "IP Not Configured"));
            } else {
              updateBaseUrl(savedIp);
              options.baseUrl = _dio.options.baseUrl;
            }
          }

          // 2. Public Bypass & Auth Check
          // 🌟 FIX: Agar login request hai ya isPublic true hai, toh token nahi chahiye
          final isPublic = options.extra["isPublic"] == true;
          final isLoginRequest = options.path.contains('/login');

          if (!isPublic && !isLoginRequest) {
            final accessToken = await _getAccessToken();
            if (accessToken != null && accessToken.isNotEmpty) {
              options.headers["Authorization"] = "Bearer $accessToken";
            } else {
              debugPrint("🚨 [Auth Error]: Token missing! Redirecting to Login...");
              AppRouter.router.go(AppRoutes.login);
              return handler.reject(DioException(requestOptions: options, error: "Unauthorized"));
            }
          }

          // 3. Network Check
          final isConnected = await _networkInfo.isConnected;
          if (!isConnected && !kIsWeb) {
            return handler.reject(DioException(requestOptions: options, error: "No Network", type: DioExceptionType.cancel));
          }

          return handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final retryRequest = await _retry(e.requestOptions);
              return handler.resolve(retryRequest);
            } else {
              AppRouter.router.go(AppRoutes.login);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  void updateBaseUrl(String newServerIpWithPort) {
    String url = newServerIpWithPort.startsWith('http') ? newServerIpWithPort : 'http://$newServerIpWithPort';
    if (!url.contains(':8090')) {
      url = url.replaceAll(RegExp(r':\d+'), '') + ':8090';
    }
    _dio.options.baseUrl = url;
    debugPrint("🔄 [API Router]: New Base URL -> ${_dio.options.baseUrl}");
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams, bool isPublic = false}) =>
      _dio.get(path, queryParameters: queryParams, options: Options(extra: {"isPublic": isPublic}));

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParams, bool isPublic = false}) =>
      _dio.post(path, data: data, queryParameters: queryParams, options: Options(extra: {"isPublic": isPublic}));

  Future<String?> _getAccessToken() async {
    if (sl.isRegistered<String>(instanceName: "accessToken")) {
      final token = sl<String>(instanceName: "accessToken");
      if (token.isNotEmpty) return token;
    }
    final diskToken = await SecureStorageUtil.getToken();
    if (diskToken != null && diskToken.isNotEmpty) {
      if (!sl.isRegistered<String>(instanceName: "accessToken")) {
        sl.registerSingleton<String>(diskToken, instanceName: "accessToken");
      }
      return diskToken;
    }
    return null;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = sl<String>(instanceName: "refreshToken");
      final response = await _dio.post("/api/token/refresh/", data: {"refresh_token": refreshToken});
      final newAccessToken = response.data["access_token"];
      if (newAccessToken != null) {
        if (sl.isRegistered<String>(instanceName: "accessToken")) await sl.unregister<String>(instanceName: "accessToken");
        sl.registerSingleton<String>(newAccessToken, instanceName: "accessToken");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ [Refresh Error]: $e");
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(method: requestOptions.method, headers: requestOptions.headers, extra: requestOptions.extra),
    );
  }
}