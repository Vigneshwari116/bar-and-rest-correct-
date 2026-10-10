import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class SettingsDao {
  final Database db;
  SettingsDao(this.db);

  Future<List<Map<String, dynamic>>> getAllPrinters() async {
    return await db.query(DbContracts.tablePrintersMaster);
  }

  Future<int> savePrinter(Map<String, dynamic> printerData) async {
    return await db.insert(
      DbContracts.tablePrintersMaster,
      printerData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deletePrinter(int printerId) async {
    return await db.delete(
      DbContracts.tablePrintersMaster,
      where: '${DbContracts.colPrinterId} = ?',
      whereArgs: [printerId],
    );
  }


  Future<Map<String, String>> getAllConfigs() async {
    final result = await db.query(DbContracts.tableSystemConfigs);
    final Map<String, String> configs = {};
    for (var row in result) {
      configs[row[DbContracts.colConfigKey].toString()] = row[DbContracts.colConfigValue].toString();
    }
    return configs;
  }

  Future<void> saveConfig(String key, String value) async {
    await db.insert(
      DbContracts.tableSystemConfigs,
      {
        DbContracts.colConfigKey: key,
        DbContracts.colConfigValue: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}