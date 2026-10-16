import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/db_contract.dart';

/// Routes anyone may call without logging in.
/// (config.json is needed by the client before login to find the server.)
const Set<String> _publicPaths = {
  'api/v1/test',
  'api/v1/login',
  'api/v1/verify-session',
  'config.json',
};

/// Routes that only an admin session may call.
/// Everything else just needs a valid, non-revoked login.
const Set<String> _adminOnlyPaths = {
  'api/v1/users/create',
  'api/v1/users/kill-session',
  'api/v1/users/telemetry',
  'api/v1/reports/clear-system-database',
  'api/v1/pos/settings/database/backup',
  'api/v1/pos/settings/tables/bulk-import',
  'api/v1/pos/settings/printers/save',
  'api/v1/pos/settings/printers/delete',
  'api/v1/pos/settings/configs/save',
};

Response _json(int status, String message) => Response(
      status,
      body: jsonEncode({'status': 'FAIL', 'error': message}),
      headers: {'content-type': 'application/json'},
    );

Middleware authMiddleware(Database db) {
  return (Handler inner) {
    return (Request request) async {
      // Let CORS preflight requests through.
      if (request.method == 'OPTIONS') return inner(request);

      var path = request.url.path;
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);

      if (_publicPaths.contains(path)) return inner(request);

      final String? header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        return _json(401, 'Login required');
      }
      final String token = header.substring(7).trim();
      if (token.isEmpty) return _json(401, 'Login required');

      try {
        final rows = await db.rawQuery('''
          SELECT u.${DbContracts.columnUserRole} AS role,
                 u.${DbContracts.columnUserId} AS uid
          FROM ${DbContracts.tableUsers} u
          INNER JOIN ${DbContracts.tableSessions} s
            ON u.${DbContracts.columnUserId} = s.${DbContracts.columnSessionUserId}
          WHERE s.${DbContracts.columnSessionToken} = ?
            AND s.${DbContracts.columnIsForcefullyLoggedOut} = 0
        ''', [token]);

        if (rows.isEmpty) return _json(401, 'Session expired. Please log in again.');

        final String role = (rows.first['role'] ?? '').toString();

        if (_adminOnlyPaths.contains(path) && role != 'admin') {
          return _json(403, 'Admin privileges required');
        }

        return inner(request.change(context: {
          'auth_role': role,
          'auth_user_id': rows.first['uid'],
        }));
      } catch (_) {
        return _json(500, 'Authentication check failed');
      }
    };
  };
}
