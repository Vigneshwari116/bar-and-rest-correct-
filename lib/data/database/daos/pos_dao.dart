import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class PosDao {
  final Database db;
  PosDao(this.db);

  Future<List<Map<String, dynamic>>> getActiveEmployees() async {
    try {
      return await db.query(
        DbContracts.tableUsers,
        columns: [
          DbContracts.columnUserId,
          DbContracts.columnUsername,
          DbContracts.columnUserRole,
        ],
      );
    } catch (e) {
      return [];
    }
  }

  Future<bool> createTable({required String tableId, required String tableName}) async {
    try {
      final existing = await db.query(
        DbContracts.tableTablesMaster,
        where: '${DbContracts.colTableId} = ?',
        whereArgs: [tableId],
      );
      if (existing.isNotEmpty) return false;
      await db.insert(DbContracts.tableTablesMaster, {
        DbContracts.colTableId: tableId,
        DbContracts.colTableName: tableName,
        DbContracts.colTableStatus: 0,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTables() async {
    try {
      return await db.query(DbContracts.tableTablesMaster);
    } catch (e) {
      return [];
    }
  }

  // 🌟 SHARED BILL SEQUENCE FOR REGULAR POS & MANUAL LIQUOR (Pehle Jaisa Same)
  Future<int> _getRegularAndLiquorMaxBill(Transaction txn) async {
    final regularRes = await txn.rawQuery(
      "SELECT COALESCE(MAX(CAST(${DbContracts.colLedgerBillNo} AS INTEGER)), 0) as max_reg FROM ${DbContracts.tableLiveOrdersLedger}",
    );
    int maxReg = regularRes.first['max_reg'] as int? ?? 0;

    final manualLiquorRes = await txn.rawQuery(
      "SELECT COALESCE(MAX(CAST(${DbContracts.colManualBillNo} AS INTEGER)), 0) as max_liq FROM ${DbContracts.tableManualOrdersArchive}",
    );
    int maxLiq = manualLiquorRes.first['max_liq'] as int? ?? 0;

    return (maxReg > maxLiq ? maxReg : maxLiq) + 1;
  }

  // 🌟 REGULAR POS CHECKOUT (Linked with Manual Liquor)
  Future<Map<String, dynamic>?> checkoutTable({
    required String tableId,
    String? customerMobile,
  }) async {
    try {
      return await db.transaction((txn) async {
        final items = await txn.query(
          DbContracts.tableRunningOrders,
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND (is_manual = 0 OR is_manual IS NULL)',
          whereArgs: [tableId],
        );

        if (items.isEmpty) return null;

        // ⚡ Shared Bill Number (Regular POS + Manual Liquor)
        int nextBillNo = await _getRegularAndLiquorMaxBill(txn);
        String mappedBillNoString = nextBillNo.toString();

        final maxExciseResult = await txn.rawQuery(
          "SELECT COALESCE(MAX(CAST(${DbContracts.colExciseOriginalBillNo} AS INTEGER)), 4999) as last_excise FROM ${DbContracts.tableLiquorExciseAudit} WHERE ${DbContracts.colExciseOriginalBillNo} GLOB '[0-9]*'",
        );
        int lastExciseNo = maxExciseResult.first['last_excise'] as int;
        int currentBillExciseNo = lastExciseNo + 1;

        double foodTotal = 0.0;
        double liquorTotal = 0.0;
        final timestampStr = DateTime.now().toIso8601String();
        String currentBusinessDate = timestampStr.split('T')[0];
        bool hasLiquorItems = false;

        for (var item in items) {
          final amount = item[DbContracts.colAmount] as double;
          final price = item[DbContracts.colPrice] as double;
          final qty = item[DbContracts.colQty] as int;
          final name = item[DbContracts.colItemName] as String;
          final String empId = (item[DbContracts.colOrderEmployeeId] ?? '1').toString();

          final List<Map<String, dynamic>> userMatch = await txn.query(
            DbContracts.tableUsers,
            columns: [DbContracts.columnUsername],
            where: 'CAST(${DbContracts.columnUserId} AS TEXT) = ?',
            whereArgs: [empId],
          );
          final String empName = userMatch.isNotEmpty ? userMatch.first[DbContracts.columnUsername].toString() : "WAITER #$empId";

          final double mPrice = double.tryParse(item[DbContracts.colItemMPrice]?.toString() ?? '0.0') ?? 0.0;
          final String savedType = item['category_type']?.toString().toUpperCase() ?? 'FOOD';
          final String savedGroupName = item['category_name']?.toString().toUpperCase() ?? 'GENERAL';

          if (savedType == 'LIQUOR') {
            liquorTotal += amount;
            hasLiquorItems = true;

            await txn.insert(DbContracts.tableLiquorExciseAudit, {
              DbContracts.colExciseOriginalBillNo: currentBillExciseNo.toString(),
              DbContracts.colExciseTableId: tableId,
              DbContracts.colExciseItemId: item[DbContracts.colOrderId],
              DbContracts.colExciseItemName: name,
              DbContracts.colExciseQty: qty,
              DbContracts.colExciseMPrice: mPrice > 0 ? mPrice : price,
              DbContracts.colExciseSalePrice: price,
              DbContracts.colExciseTotalMAmount: qty * (mPrice > 0 ? mPrice : price),
              DbContracts.colExciseCreatedAt: timestampStr
            });
          } else {
            foodTotal += amount;
          }

          await txn.insert(DbContracts.tableLiveOrdersLedger, {
            DbContracts.colLedgerBillNo: mappedBillNoString,
            DbContracts.colLedgerTableId: tableId,
            DbContracts.colLedgerItemName: name,
            DbContracts.colLedgerQty: qty,
            DbContracts.colLedgerPrice: price,
            DbContracts.colLedgerAmount: amount,
            DbContracts.colLedgerCategoryType: savedType,
            DbContracts.colLedgerCategoryName: savedGroupName,
            'employee_id': empId,
            'employee_name': empName,
            DbContracts.colLedgerCreatedAt: timestampStr
          });

          await txn.insert(DbContracts.tableHistoryOrdersArchive, {
            DbContracts.colArchiveOrderId: item[DbContracts.colOrderId],
            DbContracts.colArchiveTableId: tableId,
            DbContracts.colArchiveItemName: name,
            DbContracts.colArchiveQty: qty,
            DbContracts.colArchivePrice: price,
            DbContracts.colArchiveAmount: amount,
            DbContracts.colArchiveCategoryType: savedType,
            'category_name': savedGroupName,
            'employee_id': empId,
            'employee_name': empName,
            DbContracts.colArchiveBillNo: mappedBillNoString,
            DbContracts.colArchiveBusinessDate: currentBusinessDate,
            DbContracts.colArchiveCreatedAt: timestampStr,
          });
        }

        final generatedBillId = mappedBillNoString;

        await txn.insert(DbContracts.tableBillingMaster, {
          DbContracts.colBillId: generatedBillId,
          DbContracts.colBillTableId: tableId,
          DbContracts.colCustomerMobile: customerMobile,
          DbContracts.colFoodTotal: foodTotal,
          DbContracts.colLiquorTotal: liquorTotal,
          DbContracts.colGrandTotal: foodTotal + liquorTotal,
          DbContracts.colCheckoutAt: timestampStr,
        });

        await txn.update(
          DbContracts.tableRunningOrders,
          {
            DbContracts.colIsSettled: 1,
            DbContracts.colLinkedBillId: generatedBillId
          },
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND (is_manual = 0 OR is_manual IS NULL)',
          whereArgs: [tableId],
        );

        final remainingOrders = await txn.query(
          DbContracts.tableRunningOrders,
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0',
          whereArgs: [tableId],
        );

        if (remainingOrders.isEmpty) {
          await txn.update(
            DbContracts.tableTablesMaster,
            {DbContracts.colTableStatus: 0},
            where: '${DbContracts.colTableId} = ?',
            whereArgs: [tableId],
          );
        }

        return {
          'bill_id': generatedBillId,
          'daily_bill_no': mappedBillNoString,
          'excise_bill_no': hasLiquorItems ? currentBillExciseNo.toString() : "N/A",
          'food_total': foodTotal,
          'liquor_total': liquorTotal,
          'grand_total': foodTotal + liquorTotal,
        };
      });
    } catch (e) {
      return null;
    }
  }

  // 🌟 MANUAL CHECKOUT: Liquor is Linked with POS, Food is Pure Independent (1, 2, 3...)
  Future<Map<String, dynamic>?> checkoutManualTable({
    required String tableId,
    String? customerMobile,
    required String businessDateStr,
  }) async {
    try {
      return await db.transaction((txn) async {
        final items = await txn.query(
          DbContracts.tableRunningOrders,
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND is_manual = 1',
          whereArgs: [tableId],
        );

        if (items.isEmpty) return null;

        // ⚡ Manual Liquor: Shared with Regular POS (Pehle ki tarah)
        int nextLiquorBillNo = await _getRegularAndLiquorMaxBill(txn);
        String liquorBillNoStr = nextLiquorBillNo.toString();

        final maxExciseResult = await txn.rawQuery('''
          SELECT COALESCE(MAX(CAST(${DbContracts.colExciseOriginalBillNo} AS INTEGER)), 4999) as last_excise 
          FROM ${DbContracts.tableLiquorExciseAudit} 
          WHERE ${DbContracts.colExciseOriginalBillNo} GLOB '[0-9]*'
        ''');
        int nextExciseNo = (maxExciseResult.first['last_excise'] as int) + 1;

        // ⚡ Manual Food ONLY: Completely Separate Sequence (1, 2, 3...)
        final maxFoodResult = await txn.rawQuery('''
          SELECT COALESCE(MAX(CAST(${DbContracts.colFoodBillNo} AS INTEGER)), 0) as last_food 
          FROM ${DbContracts.tableManualFoodArchive}
          WHERE ${DbContracts.colFoodBillNo} GLOB '[0-9]*'
        ''');
        int nextFoodBillNo = (maxFoodResult.first['last_food'] as int) + 1;
        String foodBillNoStr = nextFoodBillNo.toString();

        double foodTotal = 0.0;
        double liquorTotal = 0.0;
        final timestampStr = DateTime.now().toIso8601String();
        bool hasLiquorItems = false;
        bool hasFoodItems = false;

        for (var item in items) {
          final amount = item[DbContracts.colAmount] as double;
          final price = item[DbContracts.colPrice] as double;
          final qty = item[DbContracts.colQty] as int;
          final name = item[DbContracts.colItemName] as String;
          final double mPrice = double.tryParse(item[DbContracts.colItemMPrice]?.toString() ?? '0.0') ?? 0.0;
          final String savedType = item['category_type']?.toString().toUpperCase() ?? 'FOOD';
          final String savedGroupName = item['category_name']?.toString().toUpperCase() ?? 'GENERAL';

          if (savedType == 'LIQUOR') {
            liquorTotal += amount;
            hasLiquorItems = true;

            await txn.insert(DbContracts.tableLiquorExciseAudit, {
              DbContracts.colExciseOriginalBillNo: nextExciseNo.toString(),
              DbContracts.colExciseTableId: tableId,
              DbContracts.colExciseItemId: item[DbContracts.colOrderId],
              DbContracts.colExciseItemName: name,
              DbContracts.colExciseQty: qty,
              DbContracts.colExciseMPrice: mPrice > 0 ? mPrice : price,
              DbContracts.colExciseSalePrice: price,
              DbContracts.colExciseTotalMAmount: qty * (mPrice > 0 ? mPrice : price),
              DbContracts.colExciseCreatedAt: timestampStr
            });

            await txn.insert(DbContracts.tableManualOrdersArchive, {
              DbContracts.colManualBillNo: liquorBillNoStr,
              DbContracts.colManualTableId: tableId,
              DbContracts.colManualItemName: name,
              DbContracts.colManualQty: qty,
              DbContracts.colManualPrice: price,
              DbContracts.colManualAmount: amount,
              DbContracts.colManualCategoryType: 'LIQUOR',
              DbContracts.colManualCategoryName: savedGroupName,
              DbContracts.colManualCustomerMobile: customerMobile,
              DbContracts.colManualBusinessDate: businessDateStr,
              DbContracts.colManualCreatedAt: timestampStr,
            });
          } else {
            foodTotal += amount;
            hasFoodItems = true;

            // 🌟 Manual Food ONLY goes to Food Archive with separate sequence
            await txn.insert(DbContracts.tableManualFoodArchive, {
              DbContracts.colFoodBillNo: foodBillNoStr,
              DbContracts.colFoodTableId: tableId,
              DbContracts.colFoodItemName: name,
              DbContracts.colFoodQty: qty,
              DbContracts.colFoodPrice: price,
              DbContracts.colFoodAmount: amount,
              DbContracts.colFoodCategoryName: savedGroupName,
              DbContracts.colFoodCustomerMobile: customerMobile,
              DbContracts.colFoodBusinessDate: businessDateStr,
              DbContracts.colFoodCreatedAt: timestampStr,
            });
          }
        }

        final generatedBillId = hasLiquorItems ? liquorBillNoStr : foodBillNoStr;

        await txn.update(
          DbContracts.tableRunningOrders,
          {
            DbContracts.colIsSettled: 1,
            DbContracts.colLinkedBillId: generatedBillId,
          },
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND is_manual = 1',
          whereArgs: [tableId],
        );

        final remainingOrders = await txn.query(
          DbContracts.tableRunningOrders,
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0',
          whereArgs: [tableId],
        );

        if (remainingOrders.isEmpty) {
          await txn.update(
            DbContracts.tableTablesMaster,
            {DbContracts.colTableStatus: 0},
            where: '${DbContracts.colTableId} = ?',
            whereArgs: [tableId],
          );
        }

        return {
          'bill_id': generatedBillId,
          'manual_bill_no': hasLiquorItems ? liquorBillNoStr : foodBillNoStr,
          'food_bill_no': hasFoodItems ? foodBillNoStr : 'N/A',
          'liquor_bill_no': hasLiquorItems ? liquorBillNoStr : 'N/A',
          'excise_bill_no': hasLiquorItems ? nextExciseNo.toString() : 'N/A',
          'food_total': foodTotal,
          'liquor_total': liquorTotal,
          'grand_total': foodTotal + liquorTotal,
        };
      });
    } catch (e) {
      return null;
    }
  }

  // 🌟 1. CHECK TABLE CONFLICT
  Future<String?> checkTableConflict1({required String tableId, required bool isManual}) async {
    try {
      final oppositeMode = isManual ? 0 : 1;
      final existing = await db.query(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND is_manual = ?',
        whereArgs: [tableId, oppositeMode],
      );

      if (existing.isNotEmpty) {
        return isManual
            ? "Table $tableId is currently ACTIVE in REGULAR POS mode!"
            : "Table $tableId is currently ACTIVE in MANUAL POS mode!";
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 🌟 1. CONFLICT CHECK: Bypassed taaki Table 1 par Regular aur Manual Food dono sath chal sakein
  Future<String?> checkTableConflict({required String tableId, required bool isManual}) async {
    return null; // Koi block nahi hoga
  }

  // 🌟 2. TYPE-SAFE REPRINT METHOD (Zero Collision + Exact DB Timestamp)
  Future<Map<String, dynamic>?> getSettledBillDetailsForReprint(
      String billNo, {
        String billType = 'REGULAR', // 'REGULAR' ya 'MANUAL_FOOD'
      }) async {
    try {
      // ----------------------------------------------------
      // CASE 1: MANUAL FOOD SCREEN REPRINT
      // ----------------------------------------------------
      if (billType == 'MANUAL_FOOD') {
        final List<Map<String, dynamic>> manualFoodItems = await db.query(
          DbContracts.tableManualFoodArchive,
          where: '${DbContracts.colFoodBillNo} = ?',
          whereArgs: [billNo],
        );

        if (manualFoodItems.isNotEmpty) {
          final String tableId = manualFoodItems.first[DbContracts.colFoodTableId]?.toString() ?? '1';
          final String customerMobile = manualFoodItems.first[DbContracts.colFoodCustomerMobile]?.toString() ?? '';
          final String createdAt = manualFoodItems.first[DbContracts.colFoodCreatedAt]?.toString() ?? '';

          List<Map<String, dynamic>> foodItems = [];
          double grandTotal = 0.0;

          for (var item in manualFoodItems) {
            final double lineAmt = double.tryParse(item[DbContracts.colFoodAmount]?.toString() ?? '0.0') ?? 0.0;
            grandTotal += lineAmt;

            foodItems.add({
              'item_name': item[DbContracts.colFoodItemName],
              'qty': item[DbContracts.colFoodQty],
              'price': item[DbContracts.colFoodPrice],
              'amount': lineAmt,
            });
          }

          return {
            'bill_no': billNo,
            'table_id': tableId,
            'customer_mobile': customerMobile,
            'food_items': foodItems,
            'liquor_items': <Map<String, dynamic>>[],
            'grand_total': grandTotal,
            'created_at': createdAt, // 👈 DB Saved Timestamp
          };
        }
        return null;
      }

      // ----------------------------------------------------
      // CASE 2: REGULAR POS / MANUAL LIQUOR REPRINT
      // ----------------------------------------------------
      final List<Map<String, dynamic>> regularItems = await db.query(
        DbContracts.tableLiveOrdersLedger,
        where: '${DbContracts.colLedgerBillNo} = ?',
        whereArgs: [billNo],
      );

      if (regularItems.isNotEmpty) {
        final List<Map<String, dynamic>> master = await db.query(
          DbContracts.tableBillingMaster,
          where: '${DbContracts.colBillId} = ?',
          whereArgs: [billNo],
        );

        final String tableId = regularItems.first[DbContracts.colLedgerTableId]?.toString() ?? '1';
        final String customerMobile = master.isNotEmpty ? (master.first[DbContracts.colCustomerMobile]?.toString() ?? '') : '';
        final String createdAt = regularItems.first[DbContracts.colLedgerCreatedAt]?.toString() ??
            (master.isNotEmpty ? master.first[DbContracts.colCheckoutAt]?.toString() ?? '' : '');

        List<Map<String, dynamic>> foodItems = [];
        List<Map<String, dynamic>> liquorItems = [];
        double grandTotal = 0.0;

        for (var item in regularItems) {
          final String catType = item[DbContracts.colLedgerCategoryType]?.toString().toUpperCase() ?? 'FOOD';
          final double lineAmt = double.tryParse(item[DbContracts.colLedgerAmount]?.toString() ?? '0.0') ?? 0.0;
          grandTotal += lineAmt;

          final itemMap = {
            'item_name': item[DbContracts.colLedgerItemName],
            'qty': item[DbContracts.colLedgerQty],
            'price': item[DbContracts.colLedgerPrice],
            'amount': lineAmt,
          };

          if (catType == 'LIQUOR') {
            liquorItems.add(itemMap);
          } else {
            foodItems.add(itemMap);
          }
        }

        return {
          'bill_no': billNo,
          'table_id': tableId,
          'customer_mobile': customerMobile,
          'food_items': foodItems,
          'liquor_items': liquorItems,
          'grand_total': grandTotal,
          'created_at': createdAt,
        };
      }

      // Manual Liquor Archive Search
      final List<Map<String, dynamic>> manualLiquorItems = await db.query(
        DbContracts.tableManualOrdersArchive,
        where: '${DbContracts.colManualBillNo} = ?',
        whereArgs: [billNo],
      );

      if (manualLiquorItems.isNotEmpty) {
        final String tableId = manualLiquorItems.first[DbContracts.colManualTableId]?.toString() ?? '50';
        final String customerMobile = manualLiquorItems.first[DbContracts.colManualCustomerMobile]?.toString() ?? '';
        final String createdAt = manualLiquorItems.first[DbContracts.colManualCreatedAt]?.toString() ?? '';

        List<Map<String, dynamic>> liquorItems = [];
        double grandTotal = 0.0;

        for (var item in manualLiquorItems) {
          final double lineAmt = double.tryParse(item[DbContracts.colManualAmount]?.toString() ?? '0.0') ?? 0.0;
          grandTotal += lineAmt;

          liquorItems.add({
            'item_name': item[DbContracts.colManualItemName],
            'qty': item[DbContracts.colManualQty],
            'price': item[DbContracts.colManualPrice],
            'amount': lineAmt,
          });
        }

        return {
          'bill_no': billNo,
          'table_id': tableId,
          'customer_mobile': customerMobile,
          'food_items': <Map<String, dynamic>>[],
          'liquor_items': liquorItems,
          'grand_total': grandTotal,
          'created_at': createdAt,
        };
      }

      return null;
    } catch (e) {
      debugPrint("🔴 [PosDao Reprint Fetch Error]: $e");
      return null;
    }
  }


  // 🌟 1. LOG DELETED ITEM BEFORE REMOVAL (SAVING TABLE_ID & DETAILS)
  Future<void> logDeletedOrderItem(int orderId) async {
    try {
      final List<Map<String, dynamic>> items = await db.query(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colOrderId} = ?',
        whereArgs: [orderId],
      );

      if (items.isNotEmpty) {
        final item = items.first;
        await db.insert(DbContracts.tableDeletedOrdersArchive, {
          DbContracts.colDeletedOriginalOrderId: item[DbContracts.colOrderId],
          DbContracts.colDeletedTableId: item[DbContracts.colOrderTableId]?.toString().toUpperCase() ?? '1',
          DbContracts.colDeletedEmployeeId: item[DbContracts.colOrderEmployeeId]?.toString() ?? '1',
          DbContracts.colDeletedItemName: item[DbContracts.colItemName],
          DbContracts.colDeletedCategoryType: item['category_type'] ?? 'FOOD',
          DbContracts.colDeletedPrice: item[DbContracts.colPrice],
          DbContracts.colDeletedQty: item[DbContracts.colQty],
          DbContracts.colDeletedAmount: item[DbContracts.colAmount],
          DbContracts.colDeletedAt: DateTime.now().toIso8601String(),
        });
        debugPrint("🛡️ [PosDao]: Order ID $orderId from Table ${item[DbContracts.colOrderTableId]} logged in audit archive.");
      }
    } catch (e) {
      debugPrint("🔴 [PosDao Log Deleted Item Exception]: $e");
    }
  }

  // 🌟 2. REMOVE ORDER ITEM WITH AUDIT ARCHIVE
  Future<bool> removeRunningOrderItemWithAudit(int orderId) async {
    try {
      // Step A: First Log to Deleted Archive Table
      await logDeletedOrderItem(orderId);

      // Step B: Delete from Running Orders
      final deletedRows = await db.delete(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colOrderId} = ?',
        whereArgs: [orderId],
      );

      return deletedRows > 0;
    } catch (e) {
      debugPrint("🔴 [PosDao Remove Item Error]: $e");
      return false;
    }
  }

// 🌟 TYPE-SAFE REPRINT METHOD (Zero Collision Guarantee)
  Future<Map<String, dynamic>?> getSettledBillDetailsForReprint1(
      String billNo, {
        String billType = 'REGULAR', // 'REGULAR' ya 'MANUAL_FOOD'
      }) async {
    try {
      // ----------------------------------------------------
      // CASE 1: MANUAL FOOD SCREEN REPRINT
      // ----------------------------------------------------
      if (billType == 'MANUAL_FOOD') {
        final List<Map<String, dynamic>> manualFoodItems = await db.query(
          DbContracts.tableManualFoodArchive,
          where: '${DbContracts.colFoodBillNo} = ?',
          whereArgs: [billNo],
        );

        if (manualFoodItems.isNotEmpty) {
          final String tableId = manualFoodItems.first[DbContracts.colFoodTableId]?.toString() ?? '1';
          final String customerMobile = manualFoodItems.first[DbContracts.colFoodCustomerMobile]?.toString() ?? '';
          // 🌟 1. Extract exact timestamp from Manual Food Archive
          final String createdAt = manualFoodItems.first[DbContracts.colFoodCreatedAt]?.toString() ?? '';

          List<Map<String, dynamic>> foodItems = [];
          double grandTotal = 0.0;

          for (var item in manualFoodItems) {
            final double lineAmt = double.tryParse(item[DbContracts.colFoodAmount]?.toString() ?? '0.0') ?? 0.0;
            grandTotal += lineAmt;

            foodItems.add({
              'item_name': item[DbContracts.colFoodItemName],
              'qty': item[DbContracts.colFoodQty],
              'price': item[DbContracts.colFoodPrice],
              'amount': lineAmt,
            });
          }

          return {
            'bill_no': billNo,
            'table_id': tableId,
            'customer_mobile': customerMobile,
            'food_items': foodItems,
            'liquor_items': <Map<String, dynamic>>[],
            'grand_total': grandTotal,
            'created_at': createdAt, // 👈 🌟 DB Saved Date & Time
          };
        }
        return null;
      }

      // ----------------------------------------------------
      // CASE 2: REGULAR POS / MANUAL LIQUOR REPRINT
      // ----------------------------------------------------
      // A. Pehle Regular POS me check karega
      final List<Map<String, dynamic>> regularItems = await db.query(
        DbContracts.tableLiveOrdersLedger,
        where: '${DbContracts.colLedgerBillNo} = ?',
        whereArgs: [billNo],
      );

      if (regularItems.isNotEmpty) {
        final List<Map<String, dynamic>> master = await db.query(
          DbContracts.tableBillingMaster,
          where: '${DbContracts.colBillId} = ?',
          whereArgs: [billNo],
        );

        final String tableId = regularItems.first[DbContracts.colLedgerTableId]?.toString() ?? '1';
        final String customerMobile = master.isNotEmpty ? (master.first[DbContracts.colCustomerMobile]?.toString() ?? '') : '';
        // 🌟 2. Extract exact timestamp from Regular POS Ledger / Master
        final String createdAt = regularItems.first[DbContracts.colLedgerCreatedAt]?.toString() ??
            (master.isNotEmpty ? master.first[DbContracts.colCheckoutAt]?.toString() ?? '' : '');

        List<Map<String, dynamic>> foodItems = [];
        List<Map<String, dynamic>> liquorItems = [];
        double grandTotal = 0.0;

        for (var item in regularItems) {
          final String catType = item[DbContracts.colLedgerCategoryType]?.toString().toUpperCase() ?? 'FOOD';
          final double lineAmt = double.tryParse(item[DbContracts.colLedgerAmount]?.toString() ?? '0.0') ?? 0.0;
          grandTotal += lineAmt;

          final itemMap = {
            'item_name': item[DbContracts.colLedgerItemName],
            'qty': item[DbContracts.colLedgerQty],
            'price': item[DbContracts.colLedgerPrice],
            'amount': lineAmt,
          };

          if (catType == 'LIQUOR') {
            liquorItems.add(itemMap);
          } else {
            foodItems.add(itemMap);
          }
        }

        return {
          'bill_no': billNo,
          'table_id': tableId,
          'customer_mobile': customerMobile,
          'food_items': foodItems,
          'liquor_items': liquorItems,
          'grand_total': grandTotal,
          'created_at': createdAt, // 👈 🌟 DB Saved Date & Time
        };
      }

      // B. Phir Manual Liquor Archive me check karega
      final List<Map<String, dynamic>> manualLiquorItems = await db.query(
        DbContracts.tableManualOrdersArchive,
        where: '${DbContracts.colManualBillNo} = ?',
        whereArgs: [billNo],
      );

      if (manualLiquorItems.isNotEmpty) {
        final String tableId = manualLiquorItems.first[DbContracts.colManualTableId]?.toString() ?? '50';
        final String customerMobile = manualLiquorItems.first[DbContracts.colManualCustomerMobile]?.toString() ?? '';
        // 🌟 3. Extract exact timestamp from Manual Liquor Archive
        final String createdAt = manualLiquorItems.first[DbContracts.colManualCreatedAt]?.toString() ?? '';

        List<Map<String, dynamic>> liquorItems = [];
        double grandTotal = 0.0;

        for (var item in manualLiquorItems) {
          final double lineAmt = double.tryParse(item[DbContracts.colManualAmount]?.toString() ?? '0.0') ?? 0.0;
          grandTotal += lineAmt;

          liquorItems.add({
            'item_name': item[DbContracts.colManualItemName],
            'qty': item[DbContracts.colManualQty],
            'price': item[DbContracts.colManualPrice],
            'amount': lineAmt,
          });
        }

        return {
          'bill_no': billNo,
          'table_id': tableId,
          'customer_mobile': customerMobile,
          'food_items': <Map<String, dynamic>>[],
          'liquor_items': liquorItems,
          'grand_total': grandTotal,
          'created_at': createdAt, // 👈 🌟 DB Saved Date & Time
        };
      }

      return null;
    } catch (e) {
      debugPrint("🔴 [PosDao Reprint Fetch Error]: $e");
      return null;
    }
  }

  // 🌟 KOT PRINT STATUS UPDATE (MARK ITEMS AS PRINTED IN DB)
  Future<int> markKOTItemsAsPrinted({
    required String tableId,
    required List<int> orderIds,
  }) async {
    try {
      if (orderIds.isEmpty) return 0;

      // 🛡️ Safe SQL placeholders (e.g. "?,?,?")
      final placeholders = List.filled(orderIds.length, '?').join(',');

      return await db.update(
        DbContracts.tableRunningOrders,
        {'is_printed': 1},
        where: 'order_id IN ($placeholders) AND ${DbContracts.colOrderTableId} = ?',
        whereArgs: [...orderIds, tableId],
      );
    } catch (e) {
      debugPrint("🔴 [PosDao KOT Printed Update Error]: $e");
      return 0;
    }
  }
  // 🌟 2. ADD ITEM WITH CONFLICT CHECK
  Future<int> addItemToRunningOrder({
    required String tableId,
    required String employeeId,
    required String itemName,
    required String category,
    required double price,
    required int qty,
    double mPrice = 0.0,
    String? barcode,
    required bool isManual,
    String? categoryType,
  }) async {
    try {
      final conflictError = await checkTableConflict(tableId: tableId, isManual: isManual);
      if (conflictError != null) {
        throw Exception(conflictError);
      }

      return await db.transaction((txn) async {
        final amount = price * qty;
        final addedAt = DateTime.now().toIso8601String();

        double resolvedMPrice = mPrice;

        // 1. Table Detection Rules
        final String cleanTable = tableId.trim().toUpperCase().replaceAll(RegExp(r'[^\d]'), '');
        final int tableNum = int.tryParse(cleanTable) ?? 0;
        final bool isExciseLiquorTable = tableNum >= 50 && tableNum <= 55;
        final bool isManualFoodTable = isManual && (tableNum >= 1 && tableNum <= 49);

        // 2. Query target product table ONLY for m_price
        if (barcode != null && barcode.trim().isNotEmpty) {
          final String targetProductTable = (isManual && isExciseLiquorTable)
              ? DbContracts.tableManualLiquorProducts
              : DbContracts.tableProducts;

          final List<Map<String, dynamic>> productCheck = await txn.query(
            targetProductTable,
            columns: [DbContracts.columnProductMPrice],
            where: 'LOWER(${DbContracts.columnProductBarcode}) = LOWER(?) AND ${DbContracts.columnProductIsActive} = 1',
            whereArgs: [barcode.trim()],
            limit: 1,
          );

          if (productCheck.isNotEmpty) {
            double fetchedMPrice = double.tryParse(productCheck.first[DbContracts.columnProductMPrice]?.toString() ?? '0.0') ?? 0.0;
            if (fetchedMPrice > 0) resolvedMPrice = fetchedMPrice;
          }
        }

        if (resolvedMPrice <= 0.0) resolvedMPrice = price;

        // 3. Category Type Resolution Logic
        String resolvedType = 'FOOD';
        String resolvedGroupName = 'GENERAL';

        // Base category lookup from db
        final List<Map<String, dynamic>> catResolve = await txn.rawQuery('''
        SELECT UPPER(c.${DbContracts.columnCategoryType}) as cat_type, UPPER(c.${DbContracts.columnCategoryName}) as cat_name
        FROM ${DbContracts.tableCategories} c
        WHERE CAST(c.${DbContracts.columnCategoryId} AS TEXT) = CAST(? AS TEXT) 
           OR UPPER(c.${DbContracts.columnCategoryName}) = UPPER(?)
        LIMIT 1
      ''', [category, category]);

        if (catResolve.isNotEmpty) {
          resolvedType = catResolve.first['cat_type'] ?? 'FOOD';
          resolvedGroupName = catResolve.first['cat_name'] ?? 'GENERAL';
        }

        final String incomingType = (categoryType ?? resolvedType).trim().toUpperCase();
        final String incomingCatName = category.trim().toUpperCase();

        // 🛑 STRICT GUARD 1: Block Liquor / Cold Drinks ('K') on Manual Food Tables (1-49)
        if (isManualFoodTable) {
          if (incomingType == 'LIQUOR' || incomingType == 'K' || incomingCatName == 'K' || incomingCatName == 'COLD' || incomingCatName == 'BEER') {
            throw Exception("BLOCKED: Mineral Water/Soda/Liquor is not allowed on Food Audit Table $tableId!");
          }
          resolvedType = 'FOOD'; // Force pure FOOD for manual food tables
        }
        // 🍷 GUARD 2: Manual Excise Tables (50-55) -> ALWAYS LIQUOR
        else if (isManual && isExciseLiquorTable) {
          resolvedType = 'LIQUOR';
          resolvedGroupName = 'LIQUOR';
        }
        // 🍺 GUARD 3: Client Requirement for Regular POS (Soda, Mineral Water, Cold Drinks -> LIQUOR)
        else if (!isManual) {
          if (incomingType == 'K' || incomingCatName == 'K' || incomingCatName == 'COLD' || incomingType.contains('KITCHEN')) {
            resolvedType = 'LIQUOR';
          } else if (categoryType != null && categoryType.trim().isNotEmpty) {
            resolvedType = categoryType.trim().toUpperCase();
          }
        }

        final id = await txn.insert(DbContracts.tableRunningOrders, {
          DbContracts.colOrderTableId: tableId,
          DbContracts.colOrderEmployeeId: employeeId,
          DbContracts.colItemName: itemName,
          DbContracts.colItemCategory: category.toUpperCase(),
          'category_type': resolvedType,
          'category_name': resolvedGroupName,
          DbContracts.colPrice: price,
          DbContracts.colQty: qty,
          DbContracts.colAmount: amount,
          DbContracts.colItemMPrice: resolvedMPrice,
          DbContracts.colItemBarcode: barcode,
          'is_manual': isManual ? 1 : 0,
          DbContracts.colAddedAt: addedAt,
          DbContracts.colIsSettled: 0,
        });

        await txn.update(
          DbContracts.tableTablesMaster,
          {DbContracts.colTableStatus: 1},
          where: '${DbContracts.colTableId} = ?',
          whereArgs: [tableId],
        );
        return id;
      });
    } catch (e) {
      rethrow;
    }
  }

  // 🌟 3. STRICT FILTERED RUNNING ORDERS QUERY
  Future<List<Map<String, dynamic>>> getRunningOrders(String tableId, {int? isManual}) async {
    String whereClause = '${DbContracts.colIsSettled} = 0';
    List<dynamic> whereArgs = [];

    if (tableId != 'ALL') {
      whereClause += ' AND ${DbContracts.colOrderTableId} = ?';
      whereArgs.add(tableId);
    }

    if (isManual != null) {
      whereClause += ' AND is_manual = ?';
      whereArgs.add(isManual);
    }

    return await db.query(
      DbContracts.tableRunningOrders,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${DbContracts.colAddedAt} DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getLiveOrdersStream() async {
    try {
      return await db.query(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colIsSettled} = 0',
        orderBy: '${DbContracts.colAddedAt} DESC',
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLiveOrdersForTable(String tableId) async {
    try {
      return await db.query(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0',
        whereArgs: [tableId],
        orderBy: '${DbContracts.colAddedAt} ASC',
      );
    } catch (e) {
      return [];
    }
  }

  Future<int> updateRunningOrderPrice(int orderId, double newPrice) async {
    try {
      final List<Map<String, dynamic>> order = await db.query(
        DbContracts.tableRunningOrders,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      if (order.isEmpty) return 0;
      int qty = int.tryParse(order.first['qty']?.toString() ?? '1') ?? 1;
      return await db.update(
        DbContracts.tableRunningOrders,
        {'price': newPrice, 'amount': newPrice * qty},
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUnprintedFoodKOT(String tableId) async {
    return await db.query(
      DbContracts.tableRunningOrders,
      where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND category_type = "FOOD"',
      whereArgs: [tableId],
    );
  }

  Future<int> settleFoodKOTItems(String tableId) async {
    try {
      return await db.transaction((txn) async {
        final rowsAffected = await txn.update(
          DbContracts.tableRunningOrders,
          {DbContracts.colIsSettled: 1},
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0 AND category_type = "FOOD"',
          whereArgs: [tableId],
        );

        final remaining = await txn.query(
          DbContracts.tableRunningOrders,
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0',
          whereArgs: [tableId],
        );
        if (remaining.isEmpty) {
          await txn.update(
            DbContracts.tableTablesMaster,
            {DbContracts.colTableStatus: 0},
            where: '${DbContracts.colTableId} = ?',
            whereArgs: [tableId],
          );
        }
        return rowsAffected;
      });
    } catch (e) {
      return 0;
    }
  }

  // 🌟 REGULAR POS DASHBOARD METRICS ENGINE
  // 🌟 DASHBOARD METRICS: Regular POS + Manual Liquor (Excludes Manual Food)
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      // 1. Total Combined Gross Sales (Regular Bills + Manual Liquor Items)
      final salesRes = await db.rawQuery('''
        SELECT 
          (
            COALESCE((SELECT SUM(${DbContracts.colGrandTotal}) FROM ${DbContracts.tableBillingMaster}), 0.0)
            +
            COALESCE((SELECT SUM(${DbContracts.colManualAmount}) FROM ${DbContracts.tableManualOrdersArchive} WHERE UPPER(COALESCE(${DbContracts.colManualCategoryType}, 'LIQUOR')) = 'LIQUOR'), 0.0)
          ) as total_gross,
          (
            SELECT COUNT(DISTINCT bill_no) FROM (
              SELECT ${DbContracts.colBillId} as bill_no FROM ${DbContracts.tableBillingMaster}
              UNION
              SELECT ${DbContracts.colManualBillNo} as bill_no FROM ${DbContracts.tableManualOrdersArchive}
            )
          ) as total_settled
      ''');

      double combinedGross = double.tryParse(salesRes.first['total_gross']?.toString() ?? '0.0') ?? 0.0;
      int combinedSettled = int.tryParse(salesRes.first['total_settled']?.toString() ?? '0') ?? 0;

      final activeTablesRes = await db.rawQuery(
        'SELECT COUNT(*) as active_count FROM ${DbContracts.tableTablesMaster} WHERE ${DbContracts.colTableStatus} = 1',
      );
      final totalTablesRes = await db.rawQuery(
        'SELECT COUNT(*) as total_count FROM ${DbContracts.tableTablesMaster}',
      );

      final pendingKotRes = await db.rawQuery('''
        SELECT COALESCE(SUM(${DbContracts.colQty}), 0) as pending_qty
        FROM ${DbContracts.tableRunningOrders} 
        WHERE ${DbContracts.colIsSettled} = 0 AND (is_manual = 0 OR is_manual IS NULL)
      ''');

      return {
        'gross_sales': combinedGross,
        'settled_vouchers_count': combinedSettled,
        'active_tables': activeTablesRes.first['active_count'] ?? 0,
        'total_tables': totalTablesRes.first['total_count'] ?? 0,
        'pending_kot_count': pendingKotRes.first['pending_qty'] ?? 0,
        'total_discounts': 0.0,
      };
    } catch (e) {
      debugPrint("🔴 [Dashboard Metrics Error]: $e");
      return {};
    }
  }

  // 🌟 DEPARTMENT SHARES: Regular POS + Manual Liquor (Excludes Manual Food)
  Future<Map<String, double>> getDepartmentShares() async {
    try {
      final archiveShares = await db.rawQuery('''
        SELECT 
          UPPER(combined.cat_type) as cat_type,
          UPPER(combined.cat_name) as cat_name,
          COALESCE(SUM(combined.amount), 0.0) as total_amt
        FROM (
          -- 1. Regular POS Orders Archive
          SELECT 
            COALESCE(${DbContracts.colArchiveCategoryType}, 'FOOD') as cat_type,
            COALESCE(category_name, 'GENERAL') as cat_name,
            ${DbContracts.colArchiveAmount} as amount
          FROM ${DbContracts.tableHistoryOrdersArchive}
          
          UNION ALL
          
          -- 2. Manual Liquor Archive
          SELECT 
            COALESCE(${DbContracts.colManualCategoryType}, 'LIQUOR') as cat_type,
            COALESCE(${DbContracts.colManualCategoryName}, 'LIQUOR') as cat_name,
            ${DbContracts.colManualAmount} as amount
          FROM ${DbContracts.tableManualOrdersArchive}
          WHERE UPPER(COALESCE(${DbContracts.colManualCategoryType}, 'LIQUOR')) = 'LIQUOR'
        ) combined
        GROUP BY cat_type, cat_name
      ''');

      double foodTotal = 0.0;
      double beerTotal = 0.0;
      double liquorTotal = 0.0;

      for (var row in archiveShares) {
        String catType = (row['cat_type'] ?? 'FOOD').toString().toUpperCase();
        String catName = (row['cat_name'] ?? '').toString().toUpperCase();
        double amt = double.tryParse(row['total_amt']?.toString() ?? '0.0') ?? 0.0;

        if (catType == 'BEER' || catName.contains('BEER') || catName == 'BEER') {
          beerTotal += amt;
        } else if (catType == 'LIQUOR' || catType == 'EXCISE' || catName.contains('LIQUOR') || catName == 'M') {
          liquorTotal += amt;
        } else {
          foodTotal += amt;
        }
      }

      return {
        'food_total': foodTotal,
        'beer_total': beerTotal,
        'liquor_total': liquorTotal,
      };
    } catch (e) {
      debugPrint("🔴 [Department Shares Error]: $e");
      return {'food_total': 0.0, 'beer_total': 0.0, 'liquor_total': 0.0};
    }
  }

  Future<int> getSettledBillsCount() async {
    try {
      final res = await db.rawQuery('''
      SELECT COUNT(DISTINCT bill_no) as count FROM (
        SELECT ${DbContracts.colBillId} as bill_no FROM ${DbContracts.tableBillingMaster}
        UNION
        SELECT ${DbContracts.colManualBillNo} as bill_no FROM ${DbContracts.tableManualOrdersArchive}
      )
    ''');
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // 🌟 PURE INDEPENDENT SETTLED COUNT FOR MANUAL FOOD ONLY
  Future<int> getManualFoodSettledBillsCount() async {
    try {
      final res = await db.rawQuery('''
        SELECT COUNT(DISTINCT ${DbContracts.colFoodBillNo}) as count 
        FROM ${DbContracts.tableManualFoodArchive}
      ''');
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      debugPrint("🔴 [Manual Food Settled Count Error]: $e");
      return 0;
    }
  }


  // 🌟 HARD SYSTEM RESET
  Future<bool> clearTransactionDataPreserveMasters() async {
    try {
      return await db.transaction((txn) async {
        await txn.delete(DbContracts.tableRunningOrders);
        await txn.delete(DbContracts.tableLiveOrdersLedger);
        await txn.delete(DbContracts.tableHistoryOrdersArchive);
        await txn.delete(DbContracts.tableManualOrdersArchive);
        await txn.delete(DbContracts.tableManualFoodArchive);
        await txn.delete(DbContracts.tableBillingMaster);
        await txn.delete(DbContracts.tableLiquorExciseAudit);
        await txn.delete(DbContracts.tableManualLiquorProducts);


        await txn.update(
          DbContracts.tableTablesMaster,
          {DbContracts.colTableStatus: 0},
        );

        try {
          await txn.execute('''
            DELETE FROM sqlite_sequence 
            WHERE name IN (
              '${DbContracts.tableRunningOrders}',
              '${DbContracts.tableLiveOrdersLedger}',
              '${DbContracts.tableHistoryOrdersArchive}',
              '${DbContracts.tableManualOrdersArchive}',
              '${DbContracts.tableManualFoodArchive}',
              '${DbContracts.tableLiquorExciseAudit}'
              '${DbContracts.tableManualLiquorProducts}'

            )
          ''');
        } catch (_) {}

        return true;
      });
    } catch (e) {
      debugPrint("🔴 [Database Wipe Exception]: $e");
      return false;
    }
  }



  Future<List<Map<String, dynamic>>> getRegularWaiterPerformanceReport({
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await db.rawQuery('''
        SELECT 
          l.${DbContracts.colArchiveBillNo} as bill_no,
          l.${DbContracts.colArchiveTableId} as table_id,
          l.${DbContracts.colArchiveItemName} as particulars,
          l.${DbContracts.colArchiveQty} as unit,
          l.${DbContracts.colArchivePrice} as rate,
          l.${DbContracts.colArchiveAmount} as amount,
          l.${DbContracts.colArchiveCategoryType} as category_type,
          COALESCE(l.employee_id, '1') as employee_id,
          COALESCE(l.employee_name, u.${DbContracts.columnUsername}, 'WAITER #' || COALESCE(l.employee_id, '1')) as employee_name
        FROM ${DbContracts.tableHistoryOrdersArchive} l
        LEFT JOIN ${DbContracts.tableUsers} u ON CAST(COALESCE(l.employee_id, '1') AS TEXT) = CAST(u.${DbContracts.columnUserId} AS TEXT)
        WHERE DATE(l.${DbContracts.colArchiveCreatedAt}) BETWEEN DATE(?) AND DATE(?)
          AND UPPER(l.${DbContracts.colArchiveCategoryType}) = 'FOOD'
        ORDER BY l.${DbContracts.colArchiveCreatedAt} DESC
      ''', [startDate, endDate]);
    } catch (e) {
      debugPrint("🔴 [Waiter Performance Query Error]: $e");
      return [];
    }
  }

}