
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'db_contract.dart';

class AppDatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase("svenska_pos_web.db", version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = '';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final Directory appSupportDir = await getApplicationSupportDirectory();
      final Directory secureFolder = Directory(join(appSupportDir.path, 'DataStorage'));

      if (!await secureFolder.exists()) {
        await secureFolder.create(recursive: true);
      }

      dbPath = join(secureFolder.path, "svenska_pos.db");

      try {
        final Directory docsDir = await getApplicationDocumentsDirectory();
        final File oldDbFile = File(join(docsDir.path, "svenska_pos.db"));

        if (await oldDbFile.exists()) {
          final File newDbFile = File(dbPath);
          if (!await newDbFile.exists()) {
            await oldDbFile.copy(dbPath);
          }
          await oldDbFile.delete();
        }
      } catch (_) {}
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      dbPath = join(documentsDirectory.path, "svenska_pos.db");
    }

    print("========================================");
    print("🎯 DB EXACT PATH: $dbPath");
    print("========================================");

    return await openDatabase(
      dbPath,
      version: 4, // 🌟 Updated Version to 4 for Deleted Orders Archive Table
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute("PRAGMA foreign_keys = ON");
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  // 🌟 MIGRATION HOOK: Safely handles schema changes across DB versions
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE ${DbContracts.tableManualLiquorProducts} ADD COLUMN category_type TEXT NOT NULL DEFAULT 'LIQUOR'");
      } catch (e) {
        debugPrint("⚠️ Migration v2 warning: $e");
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE ${DbContracts.tableRunningOrders} ADD COLUMN is_printed INTEGER DEFAULT 0");
      } catch (e) {
        debugPrint("⚠️ Migration v3 warning: $e");
      }
    }
    if (oldVersion < 4) {
      try {
        // 🌟 Migration for Deleted Orders Archive Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DbContracts.tableDeletedOrdersArchive} (
            ${DbContracts.colDeletedArchiveId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DbContracts.colDeletedOriginalOrderId} INTEGER,
            ${DbContracts.colDeletedTableId} TEXT NOT NULL,
            ${DbContracts.colDeletedEmployeeId} TEXT DEFAULT '1',
            ${DbContracts.colDeletedItemName} TEXT NOT NULL,
            ${DbContracts.colDeletedCategoryType} TEXT NOT NULL DEFAULT 'FOOD',
            ${DbContracts.colDeletedPrice} REAL NOT NULL,
            ${DbContracts.colDeletedQty} INTEGER NOT NULL,
            ${DbContracts.colDeletedAmount} REAL NOT NULL,
            ${DbContracts.colDeletedAt} TEXT NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("⚠️ Migration v4 warning (deleted_orders_archive): $e");
      }
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableTenants} (
        ${DbContracts.columnTenantId} TEXT PRIMARY KEY,
        ${DbContracts.columnTenantName} TEXT NOT NULL,
        ${DbContracts.columnTenantAddress} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableUsers} (
        ${DbContracts.columnUserId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.columnUserTenantId} TEXT NOT NULL,
        ${DbContracts.columnUsername} TEXT NOT NULL UNIQUE,
        ${DbContracts.columnPasswordHash} TEXT NOT NULL,
        ${DbContracts.columnUserRole} TEXT NOT NULL,
        FOREIGN KEY (${DbContracts.columnUserTenantId}) REFERENCES ${DbContracts.tableTenants} (${DbContracts.columnTenantId}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableSessions} (
        ${DbContracts.columnSessionToken} TEXT PRIMARY KEY,
        ${DbContracts.columnSessionUserId} INTEGER NOT NULL,
        ${DbContracts.columnDeviceId} TEXT NOT NULL,
        ${DbContracts.columnLastActiveAt} TEXT NOT NULL,
        ${DbContracts.columnIsForcefullyLoggedOut} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${DbContracts.columnSessionUserId}) REFERENCES ${DbContracts.tableUsers} (${DbContracts.columnUserId}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableCategories} (
        ${DbContracts.columnCategoryId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.columnCategoryTenantId} TEXT NOT NULL,
        ${DbContracts.columnCategoryType} TEXT NOT NULL,
        ${DbContracts.columnCategoryName} TEXT NOT NULL,
        ${DbContracts.columnCategoryIsActive} INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (${DbContracts.columnCategoryTenantId}) REFERENCES ${DbContracts.tableTenants} (${DbContracts.columnTenantId}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableProducts} (
        ${DbContracts.columnProductId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.columnProductTenantId} TEXT NOT NULL,
        ${DbContracts.columnProductCategoryId} INTEGER NOT NULL,
        ${DbContracts.columnProductName} TEXT NOT NULL,
        ${DbContracts.columnProductUnit} TEXT,
        ${DbContracts.columnProductBarcode} TEXT,
        ${DbContracts.columnProductCostPrice} REAL NOT NULL DEFAULT 0.0,
        ${DbContracts.columnProductSalePrice} REAL NOT NULL DEFAULT 0.0,
        ${DbContracts.columnProductMPrice} REAL NOT NULL DEFAULT 0.0, 
        ${DbContracts.columnProductIsActive} INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (${DbContracts.columnProductTenantId}) REFERENCES ${DbContracts.tableTenants} (${DbContracts.columnTenantId}) ON DELETE CASCADE,
        FOREIGN KEY (${DbContracts.columnProductCategoryId}) REFERENCES ${DbContracts.tableCategories} (${DbContracts.columnCategoryId}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableTablesMaster} (
        ${DbContracts.colTableId} TEXT PRIMARY KEY,
        ${DbContracts.colTableName} TEXT NOT NULL,
        ${DbContracts.colTableStatus} INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableRunningOrders} (
        ${DbContracts.colOrderId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colOrderTableId} TEXT NOT NULL,
        ${DbContracts.colOrderEmployeeId} TEXT NOT NULL,
        ${DbContracts.colItemBarcode} TEXT,
        ${DbContracts.colItemName} TEXT NOT NULL,
        ${DbContracts.colItemCategory} TEXT NOT NULL,
        category_type TEXT NOT NULL DEFAULT 'FOOD',
        category_name TEXT NOT NULL DEFAULT 'GENERAL',
        ${DbContracts.colPrice} REAL NOT NULL,
        ${DbContracts.colQty} INTEGER NOT NULL,
        ${DbContracts.colAmount} REAL NOT NULL,
        ${DbContracts.colItemMPrice} REAL DEFAULT 0.0,
        is_manual INTEGER DEFAULT 0,
        is_printed INTEGER DEFAULT 0,
        ${DbContracts.colAddedAt} TEXT NOT NULL,
        ${DbContracts.colIsSettled} INTEGER DEFAULT 0,
        ${DbContracts.colLinkedBillId} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableLiveOrdersLedger} (
        ${DbContracts.colLedgerId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colLedgerBillNo} TEXT NOT NULL,
        ${DbContracts.colLedgerTableId} TEXT NOT NULL,
        ${DbContracts.colLedgerItemName} TEXT NOT NULL,
        ${DbContracts.colLedgerQty} INTEGER NOT NULL,
        ${DbContracts.colLedgerPrice} REAL NOT NULL,
        ${DbContracts.colLedgerAmount} REAL NOT NULL,
        ${DbContracts.colLedgerCategoryType} TEXT NOT NULL,
        ${DbContracts.colLedgerCategoryName} TEXT NOT NULL DEFAULT 'GENERAL',
        employee_id TEXT DEFAULT '1',
        employee_name TEXT DEFAULT 'WAITER',
        ${DbContracts.colLedgerCreatedAt} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableHistoryOrdersArchive} (
        ${DbContracts.colArchiveId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colArchiveOrderId} INTEGER,
        ${DbContracts.colArchiveTableId} TEXT,
        ${DbContracts.colArchiveItemName} TEXT,
        ${DbContracts.colArchiveQty} INTEGER,
        ${DbContracts.colArchivePrice} REAL,
        ${DbContracts.colArchiveAmount} REAL,
        ${DbContracts.colArchiveCategoryType} TEXT,
        category_name TEXT NOT NULL DEFAULT 'GENERAL',
        employee_id TEXT DEFAULT '1',
        employee_name TEXT DEFAULT 'WAITER',
        ${DbContracts.colArchiveBillNo} TEXT,
        ${DbContracts.colArchiveBusinessDate} TEXT,
        ${DbContracts.colArchiveCreatedAt} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableLiquorExciseAudit} (
        ${DbContracts.colExciseBillId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colExciseOriginalBillNo} TEXT NOT NULL,
        ${DbContracts.colExciseTableId} TEXT NOT NULL,
        ${DbContracts.colExciseItemId} INTEGER,
        ${DbContracts.colExciseItemName} TEXT NOT NULL,
        ${DbContracts.colExciseQty} INTEGER NOT NULL,
        ${DbContracts.colExciseMPrice} REAL NOT NULL,
        ${DbContracts.colExciseSalePrice} REAL NOT NULL,
        ${DbContracts.colExciseTotalMAmount} REAL NOT NULL,
        ${DbContracts.colExciseCreatedAt} TEXT NOT NULL
      )
    ''');

    try {
      await db.execute("INSERT OR IGNORE INTO sqlite_sequence (name, seq) VALUES ('${DbContracts.tableLiquorExciseAudit}',0)");
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableBillingMaster} (
        ${DbContracts.colBillId} TEXT PRIMARY KEY,
        ${DbContracts.colBillTableId} TEXT NOT NULL,
        ${DbContracts.colCustomerMobile} TEXT,
        ${DbContracts.colFoodTotal} REAL DEFAULT 0.0,
        ${DbContracts.colLiquorTotal} REAL DEFAULT 0.0,
        ${DbContracts.colGrandTotal} REAL NOT NULL,
        ${DbContracts.colCheckoutAt} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tablePrintersMaster} (
        ${DbContracts.colPrinterId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colPrinterName} TEXT NOT NULL,
        ${DbContracts.colPrinterType} TEXT NOT NULL,
        ${DbContracts.colPrinterConnection} TEXT NOT NULL,
        ${DbContracts.colPrinterTarget} TEXT NOT NULL,
        ${DbContracts.colPrinterIsActive} INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableSystemConfigs} (
        ${DbContracts.colConfigKey} TEXT PRIMARY KEY,
        ${DbContracts.colConfigValue} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableManualOrdersArchive} (
        ${DbContracts.colManualArchiveId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colManualBillNo} TEXT NOT NULL,
        ${DbContracts.colManualTableId} TEXT,
        ${DbContracts.colManualItemName} TEXT,
        ${DbContracts.colManualQty} INTEGER,
        ${DbContracts.colManualPrice} REAL,
        ${DbContracts.colManualAmount} REAL,
        ${DbContracts.colManualCategoryType} TEXT,
        ${DbContracts.colManualCategoryName} TEXT DEFAULT 'GENERAL',
        ${DbContracts.colManualCustomerMobile} TEXT,
        ${DbContracts.colManualBusinessDate} TEXT,
        ${DbContracts.colManualCreatedAt} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableManualFoodArchive} (
        ${DbContracts.colFoodArchiveId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colFoodBillNo} TEXT NOT NULL,
        ${DbContracts.colFoodTableId} TEXT,
        ${DbContracts.colFoodItemName} TEXT,
        ${DbContracts.colFoodQty} INTEGER,
        ${DbContracts.colFoodPrice} REAL,
        ${DbContracts.colFoodAmount} REAL,
        ${DbContracts.colFoodCategoryName} TEXT DEFAULT 'GENERAL',
        ${DbContracts.colFoodCustomerMobile} TEXT,
        ${DbContracts.colFoodBusinessDate} TEXT,
        ${DbContracts.colFoodCreatedAt} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableManualLiquorCategories} (
        ${DbContracts.columnCategoryId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.columnCategoryTenantId} TEXT NOT NULL,
        ${DbContracts.columnCategoryName} TEXT NOT NULL,
        ${DbContracts.columnCategoryIsActive} INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableManualLiquorProducts} (
        ${DbContracts.columnProductId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.columnProductTenantId} TEXT NOT NULL,
        ${DbContracts.columnProductCategoryId} INTEGER NOT NULL,
        ${DbContracts.columnProductName} TEXT NOT NULL,
        ${DbContracts.columnProductUnit} TEXT,
        ${DbContracts.columnProductBarcode} TEXT,
        category_type TEXT NOT NULL DEFAULT 'LIQUOR',
        ${DbContracts.columnProductCostPrice} REAL NOT NULL DEFAULT 0.0,
        ${DbContracts.columnProductSalePrice} REAL NOT NULL DEFAULT 0.0,
        ${DbContracts.columnProductMPrice} REAL NOT NULL DEFAULT 0.0,
        ${DbContracts.columnProductIsActive} INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (${DbContracts.columnProductCategoryId}) REFERENCES ${DbContracts.tableManualLiquorCategories} (${DbContracts.columnCategoryId}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbContracts.tableDeletedOrdersArchive} (
        ${DbContracts.colDeletedArchiveId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbContracts.colDeletedOriginalOrderId} INTEGER,
        ${DbContracts.colDeletedTableId} TEXT NOT NULL,
        ${DbContracts.colDeletedEmployeeId} TEXT DEFAULT '1',
        ${DbContracts.colDeletedItemName} TEXT NOT NULL,
        ${DbContracts.colDeletedCategoryType} TEXT NOT NULL DEFAULT 'FOOD',
        ${DbContracts.colDeletedPrice} REAL NOT NULL,
        ${DbContracts.colDeletedQty} INTEGER NOT NULL,
        ${DbContracts.colDeletedAmount} REAL NOT NULL,
        ${DbContracts.colDeletedAt} TEXT NOT NULL
      )
    ''');
  }
}