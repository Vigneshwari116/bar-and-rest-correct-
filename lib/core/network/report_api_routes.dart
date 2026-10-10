
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/database/daos/report_dio.dart';

class ReportApiRoutes {
  final Database db;
  ReportApiRoutes(this.db);

  Router get router {
    final router = Router();
    final reportDao = ReportDao(db);

    router.get('/reports/daily-sales', (Request request) async {
      try {
        final data = await reportDao.getDailySalesItems();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.get('/reports/billwise-abstract', (Request request) async {
      try {
        final data = await reportDao.getBillwiseAbstractData();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🌟 DETAILED BILL-WISE ITEMIZED REPORT ROUTE
    router.get('/reports/billwise-detailed', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final startDate = params['start_date'];
        final endDate = params['end_date'];

        final data = await reportDao.getDetailedBillWiseReport(
          startDate: startDate,
          endDate: endDate,
        );

        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.post('/reports/daily-reset', (Request request) async {
      try {
        final success = await reportDao.wipeLiveLedgerForNewDay();
        if (success) {
          return Response.ok(
            jsonEncode({'status': 'SUCCESS', 'message': 'System Wiped'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return Response.badRequest(
          body: jsonEncode({'status': 'FAIL', 'error': 'Wipe transaction failed'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.get('/reports/liquor-history', (Request request) async {
      try {
        final data = await reportDao.getLiquorExciseAuditReport();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.get('/reports/manual-food-history', (Request request) async {
      try {
        final data = await reportDao.getManualFoodHistoryReport();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🌟 6. GET FOOD AUDIT REPORT (ACCEPT DATES)
    router.get('/reports/food-audit', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final DateTime startDate = DateTime.tryParse(params['start_date'] ?? '') ?? DateTime.now();
        final DateTime endDate = DateTime.tryParse(params['end_date'] ?? '') ?? DateTime.now();

        final data = await reportDao.getFoodAuditData(startDate: startDate, endDate: endDate);
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🌟 7. GET LIQUOR AUDIT REPORT (ACCEPT DATES)
    router.get('/reports/liquor-audit', (Request request) async {
      try {
        final params = request.url.queryParameters;
        final DateTime startDate = DateTime.tryParse(params['start_date'] ?? '') ?? DateTime.now();
        final DateTime endDate = DateTime.tryParse(params['end_date'] ?? '') ?? DateTime.now();

        final data = await reportDao.getLiquorAuditData(startDate: startDate, endDate: endDate);
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'FAIL', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // 🌟 8. GET DELETED ITEMS AUDIT REPORT
    router.get('/reports/deleted-items-audit', (Request request) async {
      try {
        final data = await reportDao.getDeletedItemsAuditReport();
        return Response.ok(
          jsonEncode({'status': 'SUCCESS', 'data': data}),
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