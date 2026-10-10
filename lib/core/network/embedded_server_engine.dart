import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_route;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:sqflite/sqflite.dart';
import 'package:svenska/core/network/pos_api_routes.dart';
import 'package:svenska/core/network/report_api_routes.dart';
import 'package:svenska/core/network/settings_api_routes.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/db_contract.dart';
import '../utils/password_hash_util.dart';
import 'menu_api_routes.dart';

class EmbeddedServerEngine {
  final Database db;
  HttpServer? _server;

  EmbeddedServerEngine(this.db);

  Future<void> bootHostEngine(int targetPort) async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    final router = shelf_route.Router();
    final menuApi = MenuApiRoutes(db);
    final posApi = PosApiRoutes(db);
    final reportApi = ReportApiRoutes(db);
    final settingsApi = SettingsApiRoutes(db);



    router.get('/api/v1/test', (Request request) {
      return Response.ok(jsonEncode({'status': 'ONLINE'}), headers: {'content-type': 'application/json','Access-Control-Allow-Origin': '*',});
    });

    router.get('/config.json', (Request request) async {
      final file = File('server_config.json');
      if (await file.exists()) {
        return Response.ok(await file.readAsString(), headers: {'content-type': 'application/json'});
      }
      return Response.notFound('Config not found');
    });

    router.post('/api/v1/login', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String username = body['username'] ?? '';
        final String plainPassword = body['password'] ?? '';

        final String hashedPassword = hashPassword(plainPassword); // Hashing enabled

        final user = await db.query(DbContracts.tableUsers,
            where: '${DbContracts.columnUsername} = ? AND ${DbContracts.columnPasswordHash} = ?',
            whereArgs: [username, hashedPassword]);

        if (user.isNotEmpty) {
          final Object? userId = user.first[DbContracts.columnUserId];
          final String token = const Uuid().v4();

          await db.insert(
            DbContracts.tableSessions,
            {
              DbContracts.columnSessionToken: token,
              DbContracts.columnSessionUserId: userId,
              DbContracts.columnDeviceId: 'POS_TERMINAL',
              DbContracts.columnLastActiveAt: DateTime.now().toIso8601String(),
              DbContracts.columnIsForcefullyLoggedOut: 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          return Response.ok(jsonEncode({
            'status': 'SUCCESS',
            'token': token,
            'user_id': userId,
            'tenant_id':user.first[DbContracts.columnUserTenantId],
            'username': user.first[DbContracts.columnUsername],
            'role':user.first[DbContracts.columnUserRole],
          }), headers: {'content-type': 'application/json'});
        }

        return Response.forbidden(jsonEncode({'status': 'FAIL', 'message': 'Invalid credentials'}));

      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.get('/api/v1/dashboard-data', (Request request) async {
      final String? username = request.url.queryParameters['username'];
      if (username == null) return Response.forbidden(jsonEncode({'error': 'User not identified'}));

      final userRows = await db.query(DbContracts.tableUsers,
          where: '${DbContracts.columnUsername} = ?', whereArgs: [username]);

      if (userRows.isEmpty) return Response.notFound(jsonEncode({'error': 'User not found'}));

      return Response.ok(jsonEncode({
        'username': userRows.first[DbContracts.columnUsername],
        'role': userRows.first[DbContracts.columnUserRole],
      }), headers: {'content-type': 'application/json'});
    });

    router.post('/api/v1/verify-session', (Request request) async {
      final body = jsonDecode(await request.readAsString());
      final String clientToken = body['token'] ?? '';

      final sessions = await db.query(DbContracts.tableSessions,
          where: '${DbContracts.columnSessionToken} = ?', whereArgs: [clientToken]);

      if (sessions.isEmpty || sessions.first[DbContracts.columnIsForcefullyLoggedOut] == 1) {
        return Response.forbidden(jsonEncode({'status': 'REJECTED'}));
      }
      return Response.ok(jsonEncode({'status': 'VERIFIED'}), headers: {'content-type': 'application/json'});
    });

    // =========================================================================
    // 🌟 NEW USER MANAGEMENT ROUTES INJECTED HERE
    // =========================================================================

    // 1. GET TELEMETRY (Fetch all users & live session status)
    router.get('/api/v1/users/telemetry', (Request request) async {
      try {
        final List<Map<String, dynamic>> userRows = await db.query(DbContracts.tableUsers);
        List<Map<String, dynamic>> synchronizedProfiles = [];

        for (var user in userRows) {
          // ID ko int mein convert karo
          final int currentUid = (user[DbContracts.columnUserId] as num).toInt();

          bool isLive = false;
          String deviceHandle = "Offline Node";
          String lastSeen = "Offline Matrix";

          // 🌟 FIX: Query ko parameterize sahi se kiya hai
          final activeSessions = await db.query(
            DbContracts.tableSessions,
            where: '${DbContracts.columnSessionUserId} = ? AND ${DbContracts.columnIsForcefullyLoggedOut} = 0',
            whereArgs: [currentUid], // ✅ Yahan userId pass karna compulsory hai
            orderBy: '${DbContracts.columnLastActiveAt} DESC',
            limit: 1,
          );

          if (activeSessions.isNotEmpty) {
            isLive = true;
            deviceHandle = activeSessions.first[DbContracts.columnDeviceId]?.toString() ?? "Terminal Node";
            lastSeen = "Active Now";
          }

          synchronizedProfiles.add({
            'user_id': currentUid,
            'username': user[DbContracts.columnUsername] ?? "UNKNOWN",
            'role': user[DbContracts.columnUserRole] ?? "waiter",
            'is_online': isLive ? 1 : 0,
            'active_device': deviceHandle,
            'last_seen_metric': lastSeen,
          });
        }

        return Response.ok(jsonEncode({'status': 'SUCCESS', 'data': synchronizedProfiles}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        print("❌ [Telemetry Error]: $e");
        return Response.internalServerError(body: jsonEncode({'status': 'FAIL', 'message': e.toString()}));
      }
    });
    // 2. CREATE STAFF PROFILE
    router.post('/api/v1/users/create', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String username = body['username']?.trim() ?? '';
        final String plainPassword = body['password']?.trim() ?? '';
        final String role = body['role'] ?? 'waiter';
        final String tenantId = body['tenant_id'] ?? 'svenska_1';

        // Check for duplicates
        final existingUser = await db.query(
          DbContracts.tableUsers,
          where: '${DbContracts.columnUsername} = ?',
          whereArgs: [username],
        );

        if (existingUser.isNotEmpty) {
          return Response.badRequest(body: jsonEncode({'status': 'FAIL', 'message': "Username already exists in cluster."}));
        }

        // Hash Password before saving
        final String hashedPassword = hashPassword(plainPassword);

        await db.insert(DbContracts.tableUsers, {
          DbContracts.columnUserTenantId: tenantId,
          DbContracts.columnUsername: username,
          DbContracts.columnPasswordHash: hashedPassword,
          DbContracts.columnUserRole: role,
        });

        return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'User onboarded'}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        print("User Create Error: $e");
        return Response.internalServerError(body: jsonEncode({'status': 'FAIL', 'message': e.toString()}));
      }
    });

    // 3. KILL SESSION (Remote Logout)
    router.post('/api/v1/users/kill-session', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final int targetUserId = body['user_id'];

        await db.update(
          DbContracts.tableSessions,
          {DbContracts.columnIsForcefullyLoggedOut: 1},
          where: '${DbContracts.columnSessionUserId} = ?',
          whereArgs: [targetUserId],
        );

        return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Hardware node purged'}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        print("Kill Session Error: $e");
        return Response.internalServerError(body: jsonEncode({'status': 'FAIL', 'message': e.toString()}));
      }
    });
    // =========================================================================

    router.mount('/api/v1', menuApi.router.call);
    router.mount('/api/v1', posApi.router.call);
    router.mount('/api/v1', reportApi.router.call);
    router.mount('/api/v1/pos/settings', settingsApi.router.call);


    final pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router);

    _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, targetPort, shared: true);
    print("🚀 [Server] Engine fully operational on port $targetPort");
  }
}