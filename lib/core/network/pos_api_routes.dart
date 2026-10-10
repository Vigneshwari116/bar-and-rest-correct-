

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart';
import '../../../data/database/daos/pos_dao.dart';
import '../../data/database/db_contract.dart';

class PosApiRoutes {
  final Database db;
  PosApiRoutes(this.db);

  Router get router {
    final router = Router();
    final posDao = PosDao(db);

    // 1. Get Active Waiters / Employees
    router.get('/pos/employees', (Request request) async {
      try {
        final employees = await posDao.getActiveEmployees();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': employees}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 2. Create Table
    router.post('/pos/tables/create', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String tableId = body['table_id']?.trim() ?? '';
        final String tableName = body['table_name']?.trim() ?? '';
        final success = await posDao.createTable(tableId: tableId, tableName: tableName);
        if (success) {
          return Response.ok(
            jsonEncode({'status': 'SUCCESS', 'message': 'Table created'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return Response.badRequest(
          body: jsonEncode({'status': 'FAIL', 'error': 'Duplicate Entry'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 3. Get All Tables
    router.get('/pos/tables', (Request request) async {
      try {
        final tables = await posDao.getAllTables();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': tables}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 4. Get Running Orders For Table
    router.get('/pos/orders/<tableId>', (Request request, String tableId) async {
      try {
        if (tableId.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'error': 'Table ID missing'}),
            headers: {'content-type': 'application/json'},
          );
        }
        List<Map<String, dynamic>> liveOrders;
        if (tableId.toUpperCase() == 'ALL') {
          liveOrders = await posDao.getLiveOrdersStream();
        } else {
          liveOrders = await posDao.getLiveOrdersForTable(tableId);
        }
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': liveOrders}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 5. Add Item To Running Order
    router.post('/pos/orders/add', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final insertedId = await posDao.addItemToRunningOrder(
          tableId: body['table_id']?.toString() ?? '1',
          employeeId: body['employee_id']?.toString() ?? '1',
          itemName: body['item_name']?.toString() ?? '',
          category: body['category']?.toString() ?? 'FOOD',
          price: double.parse(body['price'].toString()),
          qty: int.parse(body['qty'].toString()),
          mPrice: double.tryParse(body['m_price']?.toString() ?? '0.0') ?? 0.0,
          barcode: body['barcode']?.toString(),
          isManual: body['is_manual'] == true || body['is_manual'] == 1,
        );
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'inserted_id': insertedId}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        final String cleanMsg = e.toString().replaceAll("Exception: ", "");
        return Response.ok(
          jsonEncode({'status': 'FAIL', 'message': cleanMsg}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 6. Table Transfer
    router.post('/pos/table/transfer', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String oldTable = body['old_table_id'];
        final String newTable = body['new_table_id'];
        await posDao.db.update(
          DbContracts.tableRunningOrders,
          {DbContracts.colOrderTableId: newTable},
          where: '${DbContracts.colOrderTableId} = ? AND ${DbContracts.colIsSettled} = 0',
          whereArgs: [oldTable],
        );
        await posDao.db.update(
          DbContracts.tableTablesMaster,
          {DbContracts.colTableStatus: 0},
          where: 'table_id = ?',
          whereArgs: [oldTable],
        );
        await posDao.db.update(
          DbContracts.tableTablesMaster,
          {DbContracts.colTableStatus: 1},
          where: 'table_id = ?',
          whereArgs: [newTable],
        );
        return Response.ok(
          jsonEncode({'status': 'SUCCESS'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 7. Override Price
    router.post('/pos/order/update-price', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final int orderId = int.parse(body['order_id'].toString());
        final double newPrice = double.parse(body['price'].toString());
        await posDao.updateRunningOrderPrice(orderId, newPrice);
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'message': 'Price overridden'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 8. KOT Settle
    router.post('/pos/kot/settle', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String tableId = body['table_id']?.toString() ?? '';
        await posDao.settleFoodKOTItems(tableId);
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'message': 'Food items cleared'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🌟 8.5 MARK KOT ITEMS AS PRINTED (New Endpoint)
    router.post('/pos/kot/mark-printed', (Request request) async {
      try {
        final payloadStr = await request.readAsString();
        if (payloadStr.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Empty payload'}),
            headers: {'content-type': 'application/json'},
          );
        }

        final body = jsonDecode(payloadStr) as Map<String, dynamic>;
        final String tableId = body['table_id']?.toString().toUpperCase() ?? '';
        final List<dynamic> rawIds = body['order_ids'] ?? [];
        final List<int> orderIds = rawIds.map((e) => int.parse(e.toString())).toList();

        if (tableId.isEmpty || orderIds.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Invalid table_id or order_ids'}),
            headers: {'content-type': 'application/json'},
          );
        }

        final updatedCount = await posDao.markKOTItemsAsPrinted(
          tableId: tableId,
          orderIds: orderIds,
        );

        return Response.ok(
          jsonEncode({
            'status': 'SUCCESS',
            'updated_count': updatedCount,
            'message': 'KOT items marked as printed successfully.'
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

    // 9. Standard POS Checkout
    router.post('/pos/checkout', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final billSummary = await posDao.checkoutTable(
          tableId: body['table_id'] ?? '',
          customerMobile: body['customer_mobile'],
        );
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': billSummary}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 10. Dedicated MANUAL Entry Checkout API
    router.post('/pos/manual/checkout', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String tableId = body['table_id'] ?? '';
        final String? mobile = body['customer_mobile'];
        final String businessDate = body['business_date'] ?? DateTime.now().toIso8601String().split('T')[0];

        final billSummary = await posDao.checkoutManualTable(
          tableId: tableId,
          customerMobile: mobile,
          businessDateStr: businessDate,
        );

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': billSummary}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 11. Dashboard Metrics
    router.get('/pos/dashboard/stats', (Request request) async {
      try {
        final metrics = await posDao.getDashboardMetrics();
        final shares = await posDao.getDepartmentShares();

        return Response.ok(
          jsonEncode({
            'status': 'SUCCESS',
            'data': {
              ...metrics,
              'food_total': shares['food_total'] ?? 0.0,
              'beer_total': shares['beer_total'] ?? 0.0,
              'liquor_total': shares['liquor_total'] ?? 0.0,
            }
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

    router.get('/pos/bill/reprint/<billNo>', (Request req, String billNo) async {
      try {
        // 🌟 URL se bill type read karega (?type=MANUAL_FOOD ya ?type=REGULAR)
        final billType = req.url.queryParameters['type'] ?? 'REGULAR';

        final billData = await posDao.getSettledBillDetailsForReprint(billNo, billType: billType);

        if (billData != null) {
          return Response.ok(
            jsonEncode({'status': 'SUCCESS', 'data': billData}),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response.notFound(
            jsonEncode({'status': 'NOT_FOUND', 'message': 'Bill #$billNo not found in $billType history'}),
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 13. Barcode Product Search
    router.get('/pos/products/search', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final String? searchBarcode = params['barcode']?.trim();

        if (searchBarcode == null || searchBarcode.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Barcode parameter is required'}),
            headers: {'content-type': 'application/json'},
          );
        }

        final List<Map<String, dynamic>> result = await db.rawQuery('''
          SELECT 
            p.${DbContracts.columnProductId} as id,
            p.${DbContracts.columnProductTenantId} as tenant_id,
            p.${DbContracts.columnProductCategoryId} as category_id,
            p.${DbContracts.columnProductName} as product_name,
            p.${DbContracts.columnProductUnit} as unit_measure,
            CAST(p.${DbContracts.columnProductBarcode} AS TEXT) as barcode,
            p.${DbContracts.columnProductCostPrice} as cost_price,
            p.${DbContracts.columnProductSalePrice} as sale_price,
            p.${DbContracts.columnProductMPrice} as m_price,
            p.${DbContracts.columnProductIsActive} as is_active,
            c.${DbContracts.columnCategoryName} as category_name, 
            c.${DbContracts.columnCategoryType} as category_type
          FROM ${DbContracts.tableProducts} p
          LEFT JOIN ${DbContracts.tableCategories} c ON p.${DbContracts.columnProductCategoryId} = c.${DbContracts.columnCategoryId}
          WHERE LOWER(CAST(p.${DbContracts.columnProductBarcode} AS TEXT)) = LOWER(?) AND p.${DbContracts.columnProductIsActive} = 1
        ''', [searchBarcode]);

        if (result.isNotEmpty) {
          return Response.ok(
            jsonEncode({'status': 'SUCCESS', 'data': result.first}),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response.notFound(
            jsonEncode({'status': 'NOT_FOUND', 'message': 'No product matches this strict barcode entry'}),
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 14. Settled Bills Count
    router.get('/pos/bills/settled-count', (Request req) async {
      try {
        final count = await posDao.getSettledBillsCount();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'settled_count': count}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🍲 MANUAL FOOD SETTLED COUNT ROUTE
    router.get('/pos/manual-food/settled-count', (Request req) async {
      try {
        final count = await posDao.getManualFoodSettledBillsCount();
        return Response.ok(
          jsonEncode({
            'status': 'SUCCESS',
            'settled_count': count,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({
            'status': 'FAIL',
            'message': e.toString(),
          }),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 15. Waiter Performance Report
    router.get('/reports/waiter-performance', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final String startDate = params['start_date'] ?? DateTime.now().toIso8601String().split('T')[0];
        final String endDate = params['end_date'] ?? DateTime.now().toIso8601String().split('T')[0];

        final performanceData = await posDao.getRegularWaiterPerformanceReport(
          startDate: startDate,
          endDate: endDate,
        );

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': performanceData}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 16. Clear System Database
    router.post('/reports/clear-system-database', (Request request) async {
      try {
        final bool isSuccess = await posDao.clearTransactionDataPreserveMasters();

        if (isSuccess) {
          return Response.ok(
            jsonEncode({
              'status': 'SUCCESS',
              'message': 'System transactional data wiped successfully. Items, Users, and Tables preserved.'
            }),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response.internalServerError(
            body: jsonEncode({'status': 'FAIL', 'message': 'Failed to reset system transactions.'}),
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 12. Remove Order Item (With Table ID Audit Trail Logging)
    router.post('/pos/order/remove', (Request request) async {
      try {
        final payloadStr = await request.readAsString();
        if (payloadStr.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Empty payload'}),
            headers: {'content-type': 'application/json'},
          );
        }

        final body = jsonDecode(payloadStr);
        final int orderId = int.parse(body['order_id'].toString());

        // 🛡️ Call PosDao method to log and remove
        final bool success = await posDao.removeRunningOrderItemWithAudit(orderId);

        if (success) {
          return Response.ok(
            jsonEncode({
              'status': 'SUCCESS',
              'message': 'Order item logged to audit archive and deleted successfully.'
            }),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response.badRequest(
            body: jsonEncode({'status': 'FAIL', 'message': 'Item not found or delete failed'}),
            headers: {'content-type': 'application/json'},
          );
        }
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