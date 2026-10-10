import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class AuthDao {
  final Database db;
  AuthDao(this.db);

  // 1. Single Master Admin Lock Constraint Verification
  Future<bool> doesAdminExist(String tenantId) async {
    final List<Map<String, dynamic>> result = await db.query(
      DbContracts.tableUsers,
      where: '${DbContracts.columnUserTenantId} = ? AND ${DbContracts.columnUserRole} = ?',
      whereArgs: [tenantId, 'admin'],
    );
    return result.isNotEmpty;
  }

  // Poore system mein check karega ki koi bhi admin hai ya nahi
  Future<bool> isAnyAdminRegistered() async {
    final List<Map<String, dynamic>> result = await db.query(
      DbContracts.tableUsers,
      where: '${DbContracts.columnUserRole} = ?',
      whereArgs: ['admin'],
    );
    return result.isNotEmpty;
  }


  Future<void> registerTenantWithAdmin({
    required String tenantId,
    required String tenantName,
    required String username,
    required String passwordHash,
  }) async {

    // 🌟 Yahan check lagao: Agar ek bhi admin poore database mein hai, toh naya register mat hone do
    final bool adminExists = await isAnyAdminRegistered();

    if (adminExists) {
      throw Exception("Deployment Violation: A Master Admin already exists on this node. Multi-admin/Multi-tenant provisioning is disabled.");
    }

    await db.transaction((txn) async {
      await txn.insert(DbContracts.tableTenants, {
        DbContracts.columnTenantId: tenantId,
        DbContracts.columnTenantName: tenantName,
      });

      await txn.insert(DbContracts.tableUsers, {
        DbContracts.columnUserTenantId: tenantId,
        DbContracts.columnUsername: username.trim(),
        DbContracts.columnPasswordHash: passwordHash,
        DbContracts.columnUserRole: 'admin',
      });
    });
  }

  // 3. Employee Creation Module Under Strict Guard Rules
  Future<int> insertEmployee({
    required String tenantId,
    required String username,
    required String passwordHash,
    required String role,
  }) async {
    // 🌟 Check: Username already exists?
    final existing = await db.query(
      DbContracts.tableUsers,
      where: '${DbContracts.columnUsername} = ?',
      whereArgs: [username.trim()],
    );

    if (existing.isNotEmpty) {
      throw Exception("Security Alert: Username '$username' is already registered in this cluster.");
    }

    return await db.insert(DbContracts.tableUsers, {
      DbContracts.columnUserTenantId: tenantId,
      DbContracts.columnUsername: username.trim(),
      DbContracts.columnPasswordHash: passwordHash,
      DbContracts.columnUserRole: role,
    });
  }

  // ==========================================================================
  // 🛡️ ROLE VERIFICATION
  // ==========================================================================
  Future<bool> isSessionAdmin(String token) async {
    final String query = '''
      SELECT u.${DbContracts.columnUserRole} 
      FROM ${DbContracts.tableUsers} u
      INNER JOIN ${DbContracts.tableSessions} s 
        ON u.${DbContracts.columnUserId} = s.${DbContracts.columnSessionUserId}
      WHERE s.${DbContracts.columnSessionToken} = ? 
        AND s.${DbContracts.columnIsForcefullyLoggedOut} = 0
    ''';

    final result = await db.rawQuery(query, [token]);

    if (result.isNotEmpty) {
      // Agar role 'admin' hai toh true return karega, warna false
      return result.first[DbContracts.columnUserRole] == 'admin';
    }

    return false; // Token invalid ya expire ho chuka hai
  }


  // AuthDao mein ye add karo
  Future<String?> getPrimaryTenantId() async {
    final List<Map<String, dynamic>> tenants = await db.query(
      DbContracts.tableTenants,
      limit: 1,
    );
    return tenants.isNotEmpty ? tenants.first[DbContracts.columnTenantId] : null;
  }

  // 4. Forceful Session Revoke Matrix
  Future<int> executeForceLogout(String token) async {
    return await db.update(
      DbContracts.tableSessions,
      {DbContracts.columnIsForcefullyLoggedOut: 1},
      where: '${DbContracts.columnSessionToken} = ?',
      whereArgs: [token],
    );
  }

  // ==========================================================================
  // 🛡️ NEW ADDITION: Absolute Timeout Table Invalidation
  // ==========================================================================
  Future<void> clearAllSessionsOnTimeout() async {
    await db.update(
      DbContracts.tableSessions,
      {DbContracts.columnIsForcefullyLoggedOut: 1},
    );
  }

// AuthDao.dart
  Future<void> createSession({required String token, required int userId, required String deviceId}) async {
    await db.insert(
      DbContracts.tableSessions,
      {
        DbContracts.columnSessionToken: token,
        DbContracts.columnSessionUserId: userId,
        DbContracts.columnDeviceId: deviceId,
        DbContracts.columnLastActiveAt: DateTime.now().toIso8601String(),
        DbContracts.columnIsForcefullyLoggedOut: 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // 🌟 CRITICAL FIX
    );
  }
  Future<void> updateSessionActivity(String token) async {
    await db.update(
      DbContracts.tableSessions,
      {DbContracts.columnLastActiveAt: DateTime.now().toIso8601String()},
      where: '${DbContracts.columnSessionToken} = ?',
      whereArgs: [token],
    );
  }

  Future<Map<String, dynamic>?> getActiveSession(String token) async {
    final List<Map<String, dynamic>> results = await db.query(
      DbContracts.tableSessions,
      where: '${DbContracts.columnSessionToken} = ?',
      whereArgs: [token],
    );
    return results.isNotEmpty ? results.first : null;
  }
}