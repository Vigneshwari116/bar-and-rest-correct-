

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🌟 ADDED kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/utils/server_config_util.dart';

import 'app.dart';
import 'core/network/embedded_server_engine.dart';
import 'injection.dart' as di;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final bool envWantsMaster = dotenv.env['IS_MASTER_SERVER']?.toLowerCase() == 'true';

  final bool isMasterServer = isDesktop && envWantsMaster;

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS) && isMasterServer) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await di.init(isMasterServer: isMasterServer);

  if (isMasterServer) {
    final int port = int.tryParse(dotenv.env['SERVER_PORT'] ?? '8090') ?? 8090;
    final server = di.sl<EmbeddedServerEngine>();
    await server.bootHostEngine(port);
    await generateServerConfig(port);
    debugPrint("🚀 [Main]: Server Engine Booted & Config Generated on $port");
  }

  runApp(const MyApp());
}