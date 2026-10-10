import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/services/token_injection.dart';
import 'data/database/app_database_helper.dart';
import 'data/database/daos/auth_dao.dart';
import 'features/main/presentation/bloc/auth_bloc.dart';
import 'core/network/embedded_server_engine.dart';

final sl = GetIt.instance;

Future<void> init({required bool isMasterServer}) async {
  // 1. External Services & Auth Tokens
  await initTokenDI();
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfo(sl<Connectivity>()));

  // 2. ApiClient: Lazy Singleton ensure karta hai ki poori app mein ek hi instance rahe
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>(), sl<NetworkInfo>()));

  // 3. Database Layer (Conditional for Master Node)
  if (!kIsWeb && isMasterServer) {
    final dbHelper = AppDatabaseHelper();
    final Database database = await dbHelper.database;

    sl.registerSingleton<Database>(database);
    sl.registerLazySingleton<AuthDao>(() => AuthDao(sl<Database>()));
    sl.registerLazySingleton<EmbeddedServerEngine>(() => EmbeddedServerEngine(sl<Database>()));
  }

  // 4. Bloc Layer
  sl.registerFactory<AuthBloc>(() => AuthBloc(
    authDao: (isMasterServer && sl.isRegistered<AuthDao>()) ? sl<AuthDao>() : null,
    apiClient: sl<ApiClient>(),
  ));
}