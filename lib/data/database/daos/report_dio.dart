import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class ReportDao {
  final Database db;
  ReportDao(this.db);

  // 🌟 1. DAILY SALES REPORT MATRIX (CATEGORIZED STRICTLY ACCORDING TO CSV GROUPS)
  Future<List<Map<String, dynamic>>> getDailySalesItems() async {
    try {
      return await db.rawQuery('''
    SELECT 
      UPPER(TRIM(combined.item_name)) as item_name,
      MAX(UPPER(combined.category_type)) as category_type,
      MAX(UPPER(combined.category_name)) as category_name,
      SUM(combined.qty) as sold_qty,
      SUM(combined.amount) as total_revenue
    FROM (
      -- Live Regular Running Orders
      SELECT 
        ${DbContracts.colItemName} as item_name,
        CASE 
          WHEN UPPER(COALESCE(category_name, '')) IN ('COLD', 'K', 'MILK', 'MONSTER E D') 
               OR UPPER(${DbContracts.colItemName}) LIKE '%WATER%' 
               OR UPPER(${DbContracts.colItemName}) LIKE '%SODA%' 
               OR UPPER(${DbContracts.colItemName}) LIKE '%SOFT DRINKS%'
               OR UPPER(${DbContracts.colItemName}) LIKE '%KINLEY%' THEN 'COLD DRINKS'
          ELSE COALESCE(category_type, 'FOOD') 
        END as category_type,
        COALESCE(category_name, 'GENERAL') as category_name,
        ${DbContracts.colQty} as qty,
        ${DbContracts.colAmount} as amount
      FROM ${DbContracts.tableRunningOrders}
      WHERE ${DbContracts.colIsSettled} = 0
      
      UNION ALL
      
      -- Settled Regular POS Ledger
      SELECT 
        ${DbContracts.colLedgerItemName} as item_name,
        CASE 
          WHEN UPPER(COALESCE(${DbContracts.colLedgerCategoryName}, '')) IN ('COLD', 'K', 'MILK', 'MONSTER E D') 
               OR UPPER(${DbContracts.colLedgerItemName}) LIKE '%WATER%' 
               OR UPPER(${DbContracts.colLedgerItemName}) LIKE '%SODA%' 
               OR UPPER(${DbContracts.colLedgerItemName}) LIKE '%SOFT DRINKS%'
               OR UPPER(${DbContracts.colLedgerItemName}) LIKE '%KINLEY%' THEN 'COLD DRINKS'
          ELSE COALESCE(${DbContracts.colLedgerCategoryType}, 'FOOD') 
        END as category_type, 
        COALESCE(${DbContracts.colLedgerCategoryName}, 'GENERAL') as category_name,
        ${DbContracts.colLedgerQty} as qty,
        ${DbContracts.colLedgerAmount} as amount
      FROM ${DbContracts.tableLiveOrdersLedger}

      UNION ALL

      -- Manual POS Liquor Archive Entries
      SELECT 
        ${DbContracts.colManualItemName} as item_name,
        CASE 
          WHEN UPPER(COALESCE(${DbContracts.colManualCategoryName}, '')) IN ('COLD', 'K', 'MILK', 'MONSTER E D') 
               OR UPPER(${DbContracts.colManualItemName}) LIKE '%WATER%' 
               OR UPPER(${DbContracts.colManualItemName}) LIKE '%SODA%' 
               OR UPPER(${DbContracts.colManualItemName}) LIKE '%SOFT DRINKS%'
               OR UPPER(${DbContracts.colManualItemName}) LIKE '%KINLEY%' THEN 'COLD DRINKS'
          ELSE 'LIQUOR' 
        END as category_type, 
        COALESCE(${DbContracts.colManualCategoryName}, 'M') as category_name,
        ${DbContracts.colManualQty} as qty,
        ${DbContracts.colManualAmount} as amount
      FROM ${DbContracts.tableManualOrdersArchive}
      WHERE UPPER(COALESCE(${DbContracts.colManualCategoryType}, 'FOOD')) = 'LIQUOR'
    ) combined
    GROUP BY LOWER(TRIM(combined.item_name)) -- 👈 FIX: Sirf Item Name par Group Hoga!
    ORDER BY category_type ASC, item_name ASC
  ''');
    } catch (e) {
      debugPrint("🔴 [Daily Sales Exception]: $e");
      return [];
    }
  }
  // Shared section rule used by BOTH Daily Sales and Bill-wise reports.
  // Order of checks matches the Daily Sales screen: cold drinks, others, beer, liquor, food.
  static String _reportSection(String catType, String catName, String itemName) {
    final t = catType.toUpperCase().trim();
    final c = catName.toUpperCase().trim();
    final n = itemName.toUpperCase().trim();
    if (t == 'COLD DRINKS' || c == 'COLD' || c == 'K' || c == 'MILK' || c == 'MONSTER E D' ||
        n.contains('WATER') || n.contains('SODA') || n.contains('SOFT DRINKS') || n.contains('KINLEY')) {
      return 'COLD DRINKS & BEVERAGES';
    }
    if (c == 'CA' || c == 'CIG' || c.contains('CIGRATE') || n == 'C' ||
        n.contains('GLASS') || n.contains('CONTAINER')) {
      return 'OTHERS';
    }
    if (c == 'BEER' || n.contains('BEER') || n.contains('KF STRONG') || n.contains('BUDWEISER') ||
        n.contains('TUBORG') || n.contains('CARLSBERG')) {
      return 'BEER';
    }
    if (t == 'LIQUOR' || c == 'WHISKY' || c == 'SCOTCH' || c == 'RUM' || c == 'VODKA' ||
        c == 'WINE' || c == 'GIN' || c == 'BRANDY' || c == 'BACARDI') {
      return 'LIQUOR';
    }
    return 'FOOD';
  }

  // 🌟 2. BILLWISE ABSTRACT REPORT
  Future<List<Map<String, dynamic>>> getBillwiseAbstractData() async {
    try {
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
    SELECT 
      CAST(combined.bill_identifier AS TEXT) as bill_no,
      UPPER(combined.table_id) as table_id,
      UPPER(combined.item_name) as item_name,
      combined.qty as qty,
      combined.price as price,
      combined.amount as amount,
      UPPER(combined.category_type) as cat_type,
      UPPER(combined.category_name) as group_name,
      combined.source_type
    FROM (
      SELECT 
        'PENDING' as bill_identifier,
        ${DbContracts.colOrderTableId} as table_id,
        ${DbContracts.colItemName} as item_name,
        ${DbContracts.colQty} as qty,
        ${DbContracts.colPrice} as price,
        ${DbContracts.colAmount} as amount,
        COALESCE(category_type, 'FOOD') as category_type,
        COALESCE(category_name, 'GENERAL') as category_name,
        'PENDING' as source_type
      FROM ${DbContracts.tableRunningOrders}
      WHERE ${DbContracts.colIsSettled} = 0
        AND (is_manual = 0 OR is_manual IS NULL)
      
      UNION ALL
      
      SELECT 
        CAST(${DbContracts.colLedgerBillNo} AS TEXT) as bill_identifier,
        ${DbContracts.colLedgerTableId} as table_id,
        ${DbContracts.colLedgerItemName} as item_name,
        ${DbContracts.colLedgerQty} as qty,
        ${DbContracts.colLedgerPrice} as price,
        ${DbContracts.colLedgerAmount} as amount,
        COALESCE(${DbContracts.colLedgerCategoryType}, 'FOOD') as category_type,
        COALESCE(${DbContracts.colLedgerCategoryName}, 'GENERAL') as category_name,
        'REGULAR' as source_type
      FROM ${DbContracts.tableLiveOrdersLedger}

      UNION ALL

      SELECT 
        CAST(${DbContracts.colManualBillNo} AS TEXT) as bill_identifier,
        ${DbContracts.colManualTableId} as table_id,
        ${DbContracts.colManualItemName} as item_name,
        ${DbContracts.colManualQty} as qty,
        ${DbContracts.colManualPrice} as price,
        ${DbContracts.colManualAmount} as amount,
        'LIQUOR' as category_type,
        COALESCE(${DbContracts.colManualCategoryName}, 'GENERAL') as category_name,
        'MANUAL_LIQUOR' as source_type
      FROM ${DbContracts.tableManualOrdersArchive}
      WHERE UPPER(COALESCE(${DbContracts.colManualCategoryType}, 'FOOD')) = 'LIQUOR'
    ) combined
    ORDER BY CAST(bill_no AS INTEGER) ASC
  ''');

      final Map<String, Map<String, dynamic>> billGroupMap = {};

      for (var row in rawRows) {
        String rawBillNo = row['bill_no']?.toString() ?? 'PENDING';
        final String tableId = row['table_id']?.toString().toUpperCase() ?? '1';
        final String itemName = row['item_name']?.toString().toUpperCase() ?? '';
        final String sourceType = row['source_type']?.toString() ?? 'REGULAR';
        final int qty = int.tryParse(row['qty'].toString()) ?? 0;
        final double price = double.tryParse(row['price'].toString()) ?? 0.0;
        final double amt = double.tryParse(row['amount'].toString()) ?? 0.0;
        final String catType = row['cat_type']?.toString().toUpperCase() ?? 'FOOD';
        final String groupName = row['group_name']?.toString().toUpperCase() ?? 'GENERAL';

        String billKey = rawBillNo == 'PENDING' ? "PENDING_$tableId" : "${sourceType}_$rawBillNo";

        if (!billGroupMap.containsKey(billKey)) {
          String cleanDisplayBillNo = rawBillNo == 'PENDING' ? 'PENDING' : rawBillNo;

          billGroupMap[billKey] = {
            'bill_no': cleanDisplayBillNo,
            'table_id': tableId,
            'food_total': 0.0,
            'liquor_total': 0.0,
            'soft_total': 0.0,
            'others_total': 0.0,
            'grand_total': 0.0,
            'items_served': <Map<String, dynamic>>[],
          };
        }

        final node = billGroupMap[billKey]!;
        List<Map<String, dynamic>> itemsList = node['items_served'] as List<Map<String, dynamic>>;

        int existingIdx = itemsList.indexWhere((e) => e['name'] == itemName);
        if (existingIdx != -1) {
          itemsList[existingIdx]['qty'] += qty;
          itemsList[existingIdx]['total'] += amt;
        } else {
          itemsList.add({
            'name': itemName,
            'qty': qty,
            'price': price,
            'total': amt,
            'group_name': groupName,
            'cat_type': catType,
          });
        }

        // Same grouping rule as the Daily Sales report, so both always agree.
        switch (_reportSection(catType, groupName, itemName)) {
          case 'COLD DRINKS & BEVERAGES':
            node['soft_total'] = (node['soft_total'] as double) + amt;
            break;
          case 'OTHERS':
            node['others_total'] = (node['others_total'] as double) + amt;
            break;
          case 'BEER':
          case 'LIQUOR':
            node['liquor_total'] = (node['liquor_total'] as double) + amt;
            break;
          default:
            node['food_total'] = (node['food_total'] as double) + amt;
        }

        node['grand_total'] = (node['grand_total'] as double) + amt;
      }

      final List<Map<String, dynamic>> resultList = billGroupMap.values.toList();

      resultList.sort((a, b) {
        final String billA = a['bill_no'].toString();
        final String billB = b['bill_no'].toString();

        if (billA == 'PENDING' && billB != 'PENDING') return 1;
        if (billA != 'PENDING' && billB == 'PENDING') return -1;

        if (billA == 'PENDING' && billB == 'PENDING') {
          return a['table_id'].toString().compareTo(b['table_id'].toString());
        }

        final intNumA = int.tryParse(billA) ?? 0;
        final intNumB = int.tryParse(billB) ?? 0;
        return intNumA.compareTo(intNumB);
      });

      return resultList;
    } catch (e) {
      debugPrint("🔴 [Billwise Abstract Exception]: $e");
      return [];
    }
  }

//This is special
  Future<List<Map<String, dynamic>>> getDetailedBillWiseReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      String dateFilterRegular = "";
      String dateFilterManual = "";
      List<dynamic> args = [];

      if (startDate != null && endDate != null && startDate.isNotEmpty && endDate.isNotEmpty) {
        dateFilterRegular = "WHERE DATE(l.${DbContracts.colLedgerCreatedAt}) BETWEEN DATE(?) AND DATE(?)";
        dateFilterManual = "WHERE DATE(m.${DbContracts.colManualCreatedAt}) BETWEEN DATE(?) AND DATE(?)";
        args = [startDate, endDate, startDate, endDate];
      }

      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
      SELECT 
        combined.bill_no,
        combined.table_id,
        combined.customer_mobile,
        combined.item_name,
        combined.qty,
        combined.price,
        combined.amount,
        combined.cat_type,
        combined.group_name,
        combined.created_at,
        combined.source_type
      FROM (
        -- 1. Regular POS Bills
        SELECT 
          CAST(l.${DbContracts.colLedgerBillNo} AS TEXT) as bill_no,
          l.${DbContracts.colLedgerTableId} as table_id,
          COALESCE(b.${DbContracts.colCustomerMobile}, '') as customer_mobile,
          l.${DbContracts.colLedgerItemName} as item_name,
          l.${DbContracts.colLedgerQty} as qty,
          l.${DbContracts.colLedgerPrice} as price,
          l.${DbContracts.colLedgerAmount} as amount,
          COALESCE(l.${DbContracts.colLedgerCategoryType}, 'FOOD') as cat_type,
          COALESCE(l.${DbContracts.colLedgerCategoryName}, 'GENERAL') as group_name,
          l.${DbContracts.colLedgerCreatedAt} as created_at,
          'REGULAR' as source_type
        FROM ${DbContracts.tableLiveOrdersLedger} l
        LEFT JOIN ${DbContracts.tableBillingMaster} b ON CAST(b.${DbContracts.colBillId} AS TEXT) = CAST(l.${DbContracts.colLedgerBillNo} AS TEXT)
        $dateFilterRegular

        UNION ALL

        -- 2. Manual Liquor Bills
        SELECT 
          CAST(m.${DbContracts.colManualBillNo} AS TEXT) as bill_no,
          m.${DbContracts.colManualTableId} as table_id,
          COALESCE(m.${DbContracts.colManualCustomerMobile}, '') as customer_mobile,
          m.${DbContracts.colManualItemName} as item_name,
          m.${DbContracts.colManualQty} as qty,
          m.${DbContracts.colManualPrice} as price,
          m.${DbContracts.colManualAmount} as amount,
          'LIQUOR' as cat_type,
          COALESCE(m.${DbContracts.colManualCategoryName}, 'LIQUOR') as group_name,
          m.${DbContracts.colManualCreatedAt} as created_at,
          'MANUAL_LIQUOR' as source_type
        FROM ${DbContracts.tableManualOrdersArchive} m
        $dateFilterManual
      ) combined
      ORDER BY CAST(combined.bill_no AS INTEGER) DESC, combined.created_at DESC
    ''', args.isNotEmpty ? args : null);

      // 🌟 Group by Bill Number into structured object hierarchy
      final Map<String, Map<String, dynamic>> billGroupMap = {};

      for (var row in rawRows) {
        final String billNo = row['bill_no']?.toString() ?? 'N/A';
        final String sourceType = row['source_type']?.toString() ?? 'REGULAR';
        final String groupKey = "${sourceType}_$billNo";

        final String tableId = row['table_id']?.toString().toUpperCase() ?? '1';
        final String mobile = row['customer_mobile']?.toString() ?? '';
        final String createdAt = row['created_at']?.toString() ?? '';
        final String itemName = row['item_name']?.toString().toUpperCase() ?? '';
        final int qty = int.tryParse(row['qty']?.toString() ?? '1') ?? 1;
        final double price = double.tryParse(row['price']?.toString() ?? '0.0') ?? 0.0;
        final double amount = double.tryParse(row['amount']?.toString() ?? '0.0') ?? (price * qty);
        final String catType = row['cat_type']?.toString().toUpperCase() ?? 'FOOD';
        final String groupName = row['group_name']?.toString().toUpperCase() ?? 'GENERAL';

        if (!billGroupMap.containsKey(groupKey)) {
          billGroupMap[groupKey] = {
            'bill_no': billNo,
            'table_id': tableId,
            'customer_mobile': mobile,
            'created_at': createdAt,
            'source_type': sourceType,
            'food_total': 0.0,
            'liquor_total': 0.0,
            'grand_total': 0.0,
            'items': <Map<String, dynamic>>[],
          };
        }

        final billNode = billGroupMap[groupKey]!;
        List<Map<String, dynamic>> itemsList = billNode['items'] as List<Map<String, dynamic>>;

        itemsList.add({
          'item_name': itemName,
          'qty': qty,
          'price': price,
          'amount': amount,
          'category_type': catType,
          'category_name': groupName,
        });

        if (catType == 'LIQUOR') {
          billNode['liquor_total'] = (billNode['liquor_total'] as double) + amount;
        } else {
          billNode['food_total'] = (billNode['food_total'] as double) + amount;
        }

        billNode['grand_total'] = (billNode['grand_total'] as double) + amount;
      }

      final result = billGroupMap.values.toList();
      result.sort((a, b) {
        final intNumA = int.tryParse(a['bill_no'].toString()) ?? 0;
        final intNumB = int.tryParse(b['bill_no'].toString()) ?? 0;
        return intNumB.compareTo(intNumA); // Latest bill on top
      });

      return result;
    } catch (e) {
      debugPrint("🔴 [Detailed Bill Report Exception]: $e");
      return [];
    }
  }

  // 🌟 3. LIQUOR EXCISE AUDIT REPORT (EXCLUDES NON-ALCOHOLIC COLD DRINKS/WATER/SODA/GLASSES)
  Future<List<Map<String, dynamic>>> getLiquorExciseAuditReport1() async {
    try {
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
      SELECT 
        e.${DbContracts.colExciseOriginalBillNo} as excise_bill_no,
        e.${DbContracts.colExciseTableId} as table_id,
        e.${DbContracts.colExciseItemName} as item_name,
        e.${DbContracts.colExciseQty} as qty,
        e.${DbContracts.colExciseMPrice} as m_price, 
        e.${DbContracts.colExciseCreatedAt} as created_at
      FROM ${DbContracts.tableLiquorExciseAudit} e
      WHERE UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%WATER%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SODA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%KINLEY%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%COLA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SPRITE%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%PEPSI%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%GLASS%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CONTAINER%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SDODA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%DRINKS%'
      ORDER BY CAST(e.${DbContracts.colExciseOriginalBillNo} AS INTEGER) ASC
    ''');

      final Map<String, Map<String, dynamic>> auditGroupMap = {};

      for (var row in rawRows) {
        final String exciseBillNo = row['excise_bill_no']?.toString() ?? '5000';
        final String tableId = row['table_id']?.toString().toUpperCase() ?? '1A';
        final String cAt = row['created_at']?.toString() ?? '';
        final String bDate = cAt.isNotEmpty ? cAt.split('T')[0] : '';

        final String billKey = "${exciseBillNo}_$bDate";

        if (!auditGroupMap.containsKey(billKey)) {
          auditGroupMap[billKey] = {
            'excise_bill_no': exciseBillNo,
            'bill_no': exciseBillNo,
            'table_id': tableId,
            'business_date': bDate,
            'category_type': 'LIQUOR',
            'category_name': 'M',
            'audit_liquor_total': 0.0,
            'items_served': <Map<String, dynamic>>[],
          };
        }

        final node = auditGroupMap[billKey]!;
        List<Map<String, dynamic>> itemsList = node['items_served'];
        final String itemName = row['item_name']?.toString().toUpperCase() ?? '';
        final int qty = int.tryParse(row['qty'].toString()) ?? 0;
        final double mPrice = double.tryParse(row['m_price'].toString()) ?? 0.0;
        final double totalMAmount = qty * mPrice;

        int existingIdx = itemsList.indexWhere((element) => element['name'] == itemName);
        if (existingIdx != -1) {
          itemsList[existingIdx]['qty'] += qty;
          itemsList[existingIdx]['total'] += totalMAmount;
        } else {
          itemsList.add({
            'name': itemName,
            'qty': qty,
            'price': mPrice,
            'total': totalMAmount,
            'group_name': 'M',
            'cat_type': 'LIQUOR',
            'category_type': 'LIQUOR',
            'category_name': 'M',
          });
        }

        node['audit_liquor_total'] = (node['audit_liquor_total'] as double) + totalMAmount;
      }

      return auditGroupMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  // 🌟 3. LIQUOR EXCISE AUDIT REPORT (STRICTLY PURE LIQUOR/BEER ONLY - NO C/CA/WATER/SODA)
  Future<List<Map<String, dynamic>>> getLiquorExciseAuditReport() async {
    try {
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
      SELECT 
        e.${DbContracts.colExciseOriginalBillNo} as excise_bill_no,
        e.${DbContracts.colExciseTableId} as table_id,
        e.${DbContracts.colExciseItemName} as item_name,
        e.${DbContracts.colExciseQty} as qty,
        e.${DbContracts.colExciseMPrice} as m_price, 
        e.${DbContracts.colExciseCreatedAt} as created_at
      FROM ${DbContracts.tableLiquorExciseAudit} e
      WHERE UPPER(TRIM(e.${DbContracts.colExciseItemName})) != 'C'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%WATER%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SODA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%KINLEY%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%COLA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SPRITE%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%PEPSI%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%GLASS%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CONTAINER%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SDODA%'
        AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%DRINKS%'
      ORDER BY CAST(e.${DbContracts.colExciseOriginalBillNo} AS INTEGER) ASC
    ''');

      final Map<String, Map<String, dynamic>> auditGroupMap = {};

      for (var row in rawRows) {
        final String exciseBillNo = row['excise_bill_no']?.toString() ?? '5000';
        final String tableId = row['table_id']?.toString().toUpperCase() ?? '1A';
        final String cAt = row['created_at']?.toString() ?? '';
        final String bDate = cAt.isNotEmpty ? cAt.split('T')[0] : '';

        final String billKey = "${exciseBillNo}_$bDate";

        if (!auditGroupMap.containsKey(billKey)) {
          auditGroupMap[billKey] = {
            'excise_bill_no': exciseBillNo,
            'bill_no': exciseBillNo,
            'table_id': tableId,
            'business_date': bDate,
            'category_type': 'LIQUOR',
            'category_name': 'M',
            'audit_liquor_total': 0.0,
            'items_served': <Map<String, dynamic>>[],
          };
        }

        final node = auditGroupMap[billKey]!;
        List<Map<String, dynamic>> itemsList = node['items_served'];
        final String itemName = row['item_name']?.toString().toUpperCase() ?? '';
        final int qty = int.tryParse(row['qty'].toString()) ?? 0;
        final double mPrice = double.tryParse(row['m_price'].toString()) ?? 0.0;
        final double totalMAmount = qty * mPrice;

        int existingIdx = itemsList.indexWhere((element) => element['name'] == itemName);
        if (existingIdx != -1) {
          itemsList[existingIdx]['qty'] += qty;
          itemsList[existingIdx]['total'] += totalMAmount;
        } else {
          itemsList.add({
            'name': itemName,
            'qty': qty,
            'price': mPrice,
            'total': totalMAmount,
            'group_name': 'M',
            'cat_type': 'LIQUOR',
            'category_type': 'LIQUOR',
            'category_name': 'M',
          });
        }

        node['audit_liquor_total'] = (node['audit_liquor_total'] as double) + totalMAmount;
      }

      return auditGroupMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  // 🌟 6. LIQUOR AUDIT REPORT DATA (EXCLUDES ITEM 'C' AND OTHER NON-ALCOHOLIC ITEMS)
  Future<List<Map<String, dynamic>>> getLiquorAuditData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final String startStr = startDate.toIso8601String().split('T')[0];
      final String endStr = endDate.toIso8601String().split('T')[0];

      return await db.rawQuery('''
        SELECT 
          e.${DbContracts.colExciseOriginalBillNo} as bill_no,
          UPPER(e.${DbContracts.colExciseItemName}) as particulars,
          e.${DbContracts.colExciseMPrice} as rate,
          SUM(e.${DbContracts.colExciseQty}) as unit,
          SUM(e.${DbContracts.colExciseTotalMAmount}) as amount,
          e.${DbContracts.colExciseCreatedAt} as created_at
        FROM ${DbContracts.tableLiquorExciseAudit} e
        WHERE DATE(e.${DbContracts.colExciseCreatedAt}) BETWEEN DATE(?) AND DATE(?)
          AND UPPER(TRIM(e.${DbContracts.colExciseItemName})) NOT IN ('C', 'CM', 'CA')
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CIG%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CIGRATE%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CIGARETTE%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%WATER%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SODA%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%KINLEY%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%COLA%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SPRITE%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%PEPSI%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%GLASS%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%CONTAINER%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%SDODA%'
          AND UPPER(e.${DbContracts.colExciseItemName}) NOT LIKE '%DRINKS%'
        GROUP BY e.${DbContracts.colExciseOriginalBillNo}, UPPER(e.${DbContracts.colExciseItemName})
        ORDER BY CAST(e.${DbContracts.colExciseOriginalBillNo} AS INTEGER) ASC
      ''', [startStr, endStr]);
    } catch (e) {
      debugPrint("🔴 [Liquor Audit Query Error]: $e");
      return [];
    }
  }

  // 🌟 4. MANUAL FOOD HISTORY REPORT
  Future<List<Map<String, dynamic>>> getManualFoodHistoryReport() async {
    try {
      final List<Map<String, dynamic>> rawRows = await db.rawQuery('''
        SELECT 
          m.${DbContracts.colFoodBillNo} as display_bill_no,
          m.${DbContracts.colFoodTableId} as table_id,
          m.${DbContracts.colFoodItemName} as item_name,
          m.${DbContracts.colFoodQty} as qty,
          m.${DbContracts.colFoodPrice} as price,
          m.${DbContracts.colFoodAmount} as amount,
          'FOOD' as cat_type,
          m.${DbContracts.colFoodCategoryName} as group_name,
          m.${DbContracts.colFoodBusinessDate} as business_date
        FROM ${DbContracts.tableManualFoodArchive} m
        ORDER BY CAST(m.${DbContracts.colFoodBillNo} AS INTEGER) ASC
      ''');

      final Map<String, Map<String, dynamic>> manualGroupMap = {};

      for (var row in rawRows) {
        final String displayBillNo = row['display_bill_no']?.toString() ?? '1';
        final String tableId = row['table_id']?.toString().toUpperCase() ?? '1';
        final String bDate = row['business_date']?.toString() ?? '';
        final String billKey = "${bDate}_${tableId}_$displayBillNo";

        final String itemName = row['item_name']?.toString().toUpperCase() ?? '';
        final int qty = int.tryParse(row['qty'].toString()) ?? 0;
        final double price = double.tryParse(row['price'].toString()) ?? 0.0;
        final double amt = double.tryParse(row['amount'].toString()) ?? 0.0;

        if (!manualGroupMap.containsKey(billKey)) {
          manualGroupMap[billKey] = {
            'bill_no': displayBillNo,
            'table_id': tableId,
            'business_date': bDate,
            'food_total': 0.0,
            'grand_total': 0.0,
            'items_served': <Map<String, dynamic>>[],
          };
        }

        final node = manualGroupMap[billKey]!;
        List<Map<String, dynamic>> itemsList = node['items_served'];

        int existingIdx = itemsList.indexWhere((element) => element['name'] == itemName);
        if (existingIdx != -1) {
          itemsList[existingIdx]['qty'] += qty;
          itemsList[existingIdx]['total'] += amt;
        } else {
          itemsList.add({
            'name': itemName,
            'qty': qty,
            'price': price,
            'total': amt,
          });
        }

        node['food_total'] = (node['food_total'] as double) + amt;
        node['grand_total'] = (node['grand_total'] as double) + amt;
      }

      return manualGroupMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  // 🌟 5. FOOD AUDIT REPORT DATA
  Future<List<Map<String, dynamic>>> getFoodAuditData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final String startStr = startDate.toIso8601String().split('T')[0];
      final String endStr = endDate.toIso8601String().split('T')[0];

      return await db.rawQuery('''
        SELECT 
          m.${DbContracts.colFoodBillNo} as bill_no,
          UPPER(m.${DbContracts.colFoodItemName}) as particulars,
          m.${DbContracts.colFoodPrice} as rate,
          m.${DbContracts.colFoodQty} as unit,
          m.${DbContracts.colFoodAmount} as amount,
          m.${DbContracts.colFoodBusinessDate} as business_date
        FROM ${DbContracts.tableManualFoodArchive} m
        WHERE DATE(m.${DbContracts.colFoodBusinessDate}) BETWEEN DATE(?) AND DATE(?)
        ORDER BY CAST(m.${DbContracts.colFoodBillNo} AS INTEGER) ASC
      ''', [startStr, endStr]);
    } catch (e) {
      debugPrint("🔴 [Food Audit Exception]: $e");
      return [];
    }
  }


  // 🌟 FETCH DELETED ITEMS AUDIT REPORT
  Future<List<Map<String, dynamic>>> getDeletedItemsAuditReport() async {
    try {
      return await db.rawQuery('''
        SELECT 
          ${DbContracts.colDeletedArchiveId} as id,
          ${DbContracts.colDeletedTableId} as table_id,
          ${DbContracts.colDeletedEmployeeId} as employee_id,
          UPPER(${DbContracts.colDeletedItemName}) as item_name,
          ${DbContracts.colDeletedQty} as qty,
          ${DbContracts.colDeletedPrice} as price,
          ${DbContracts.colDeletedAmount} as amount,
          ${DbContracts.colDeletedAt} as deleted_at
        FROM ${DbContracts.tableDeletedOrdersArchive}
        ORDER BY ${DbContracts.colDeletedArchiveId} DESC
      ''');
    } catch (e) {
      debugPrint("🔴 [ReportDao Deleted Audit Error]: $e");
      return [];
    }
  }

  Future<bool> wipeLiveLedgerForNewDay() async {
    try {
      // 🛡️ 1. Check if any running pending orders exist
      final pendingOrders = await db.query(
        DbContracts.tableRunningOrders,
        where: '${DbContracts.colIsSettled} = 0',
      );

      if (pendingOrders.isNotEmpty) {
        debugPrint("⚠️ [EOD Wipe Cancelled]: Pending orders are currently running!");
        return false;
      }

      // 🧹 2. Atomic Transaction for New Day Wipe
      return await db.transaction((txn) async {
        // Clear Live Orders and Running Tables
        await txn.delete(DbContracts.tableLiveOrdersLedger);
        await txn.delete(DbContracts.tableRunningOrders);

        // Reset Table Statuses to 0 (Available)
        await txn.update(
          DbContracts.tableTablesMaster,
          {DbContracts.colTableStatus: 0},
        );

        // Clear History & Billing Archives
        await txn.delete(DbContracts.tableHistoryOrdersArchive);
        await txn.delete(DbContracts.tableBillingMaster);
        await txn.delete(DbContracts.tableManualOrdersArchive);

        // 🌟 3. CLEAR DELETED ORDERS AUDIT ARCHIVE
        await txn.delete(DbContracts.tableDeletedOrdersArchive);

        // 🌟 4. RESET AUTOINCREMENT COUNTERS TO 0 IN SQLITE
        try {
          await txn.execute("DELETE FROM sqlite_sequence WHERE name IN ('${DbContracts.tableDeletedOrdersArchive}', '${DbContracts.tableRunningOrders}', '${DbContracts.tableLiveOrdersLedger}')");
        } catch (seqError) {
          debugPrint("⚠️ Sequence reset warning: $seqError");
        }

        debugPrint("✅ [EOD Reset Success]: All live ledgers, history, and deleted audit logs wiped to 0 for New Day.");
        return true;
      });
    } catch (e) {
      debugPrint("🔴 [EOD Reset Exception]: $e");
      return false;
    }
  }

}