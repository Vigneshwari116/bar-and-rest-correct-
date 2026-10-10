import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/daos/settings_dao.dart';
import 'package:path/path.dart' as p;

import '../../data/database/db_contract.dart';


class SettingsApiRoutes {
  final Database db;
  SettingsApiRoutes(this.db);

  Router get router {
    final router = Router();
    final settingsDao = SettingsDao(db);

    router.get('/printers', (Request request) async {
      try {
        final printers = await settingsDao.getAllPrinters();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': printers}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
        );
      }
    });

    // 2. POST Save / Update Printer
    router.post('/printers/save', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        await settingsDao.savePrinter({
          if (body['id'] != null) 'id': body['id'],
          'printer_name': body['printer_name'],
          'printer_type': body['printer_type'], // 'KOT' / 'BILL'
          'connection_type': body['connection_type'], // 'USB' / 'NETWORK'
          'target_address': body['target_address'],
          'is_active': body['is_active'] ?? 1,
        });

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'message': 'Printer saved successfully'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
        );
      }
    });

    // 3. POST Delete Printer
    router.post('/printers/delete', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final int printerId = body['id'];
        await settingsDao.deletePrinter(printerId);

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'message': 'Printer deleted successfully'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
        );
      }
    });

    // 4. GET System Configs / Shortcuts
    router.get('/configs', (Request request) async {
      try {
        final configs = await settingsDao.getAllConfigs();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': configs}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
        );
      }
    });

    // 5. POST Save System Config / Shortcut
    router.post('/configs/save', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String key = body['config_key'];
        final String value = body['config_value'];

        await settingsDao.saveConfig(key, value);

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'message': 'Config saved successfully'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
        );
      }
    });

    // 6. GET Database Backup to D Drive
// 6. GET Database Backup to D Drive
    router.get('/database/backup', (Request request) async {
      try {
        // ⚡ AppDatabaseHelper wala exact secure folder path
        final Directory appSupportDir = await getApplicationSupportDirectory();
        final Directory secureFolder = Directory(p.join(appSupportDir.path, 'DataStorage'));

        // Exact database file path
        final String sourceDbPath = p.join(secureFolder.path, "svenska_pos.db");
        final File sourceFile = File(sourceDbPath);

        // Fallback: Agar secure folder me na mile toh standard documents directory check karein
        File fileToCopy = sourceFile;
        if (!fileToCopy.existsSync()) {
          final Directory docsDir = await getApplicationDocumentsDirectory();
          final File oldDbFile = File(p.join(docsDir.path, "svenska_pos.db"));
          if (oldDbFile.existsSync()) {
            fileToCopy = oldDbFile;
          } else {
            return Response.ok(
              jsonEncode({
                'status': 'FAIL',
                'message': 'Database file not found at path: $sourceDbPath'
              }),
              headers: {'content-type': 'application/json'},
            );
          }
        }

        // D Drive Destination Folder Setup
        final Directory backupDir = Directory('D:\\DB_BACKUP');
        if (!backupDir.existsSync()) {
          backupDir.createSync(recursive: true);
        }

        final now = DateTime.now();
        final String timestamp = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

        final String backupFileName = 'db_backup_$timestamp.db';
        final String destinationPath = p.join(backupDir.path, backupFileName);

        // Copy database file safely
        fileToCopy.copySync(destinationPath);

        return Response.ok(
          jsonEncode({
            'status': 'SUCCESS',
            'message': 'Database backup created successfully!',
            'backup_file': backupFileName,
            'path': destinationPath
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

// 📊 POST Bulk Import Tables Route
    router.post('/tables/bulk-import', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final List<dynamic>? tablesList = body['tables'];

        if (tablesList == null || tablesList.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Tables list is empty'}),
            headers: {'content-type': 'application/json'},
          );
        }

        int successCount = 0;
        int skippedCount = 0;

        await db.transaction((txn) async {
          for (var item in tablesList) {
            final String val = item.toString().trim().toUpperCase();
            if (val.isEmpty) continue;

            final String tableId = val;
            final String tableName = val;

            // Check if table already exists
            final existing = await txn.query(
              DbContracts.tableTablesMaster,
              where: '${DbContracts.colTableId} = ?',
              whereArgs: [tableId],
            );

            if (existing.isNotEmpty) {
              skippedCount++;
              continue;
            }

            // Insert Table (Table ID aur Table Name same rahenge)
            await txn.insert(DbContracts.tableTablesMaster, {
              DbContracts.colTableId: tableId,
              DbContracts.colTableName: tableName,
              DbContracts.colTableStatus: 0,
            });

            successCount++;
          }
        });

        return Response.ok(
          jsonEncode({
            'status': 'SUCCESS',
            'message': 'Tables imported successfully',
            'imported': successCount,
            'skipped': skippedCount,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });
    return router;
  }
}