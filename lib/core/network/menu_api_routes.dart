
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../data/database/daos/auth_dao.dart';
import '../../data/database/daos/manual_liquore_dao.dart';
import '../../data/database/daos/menu_dio.dart';
import '../../data/database/db_contract.dart';

class MenuApiRoutes {
  final Database db;
  MenuApiRoutes(this.db);

  Router get router {
    final router = Router();

    // 🗂️ CREATE CATEGORY GROUP
    router.post('/group/create', (Request request) async {
      try {
        final String? authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'content-type': 'application/json'});
        }
        final String token = authHeader.replaceFirst('Bearer ', '');
        final authDao = AuthDao(db);
        if (!await authDao.isSessionAdmin(token)) {
          return Response.forbidden(jsonEncode({'error': 'Admin privileges required'}), headers: {'content-type': 'application/json'});
        }
        final String? validTenantId = await authDao.getPrimaryTenantId();
        if (validTenantId == null) {
          return Response.internalServerError(body: jsonEncode({'error': 'No active tenant'}), headers: {'content-type': 'application/json'});
        }

        final body = jsonDecode(await request.readAsString());
        final id = await MenuDao(db).createCategory(
            tenantId: validTenantId,
            categoryType: body['type'] ?? 'FOOD',
            categoryName: body['name'] ?? ''
        );
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'group_id': id}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // 🗂️ GET ALL GROUPS
    router.get('/groups', (Request request) async {
      try {
        final String? authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'content-type': 'application/json'});
        }
        final authDao = AuthDao(db);
        final String? actualTenantId = await authDao.getPrimaryTenantId();
        if (actualTenantId == null) {
          return Response.internalServerError(body: jsonEncode({'error': 'No tenant bound'}), headers: {'content-type': 'application/json'});
        }

        final groups = await MenuDao(db).getCategories(actualTenantId, type: request.url.queryParameters['type']);
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'data': groups}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // 🍽️ FILTERED PRODUCTS STREAM (Fixed to support absolute correct m_price lookups)
    router.get('/products', (Request request) async {
      try {
        final authDao = AuthDao(db);
        final String? actualTenantId = await authDao.getPrimaryTenantId();
        if (actualTenantId == null) {
          return Response.internalServerError(body: jsonEncode({'error': 'No active tenant setup found'}), headers: {'content-type': 'application/json'});
        }

        final params = request.url.queryParameters;
        final int? limit = params['limit'] != null ? int.tryParse(params['limit']!) : null;
        final int? offset = params['offset'] != null ? int.tryParse(params['offset']!) : null;

        final products = await MenuDao(db).getFilteredProducts(
          tenantId: actualTenantId, limit: limit, offset: offset,
          searchName: params['name'], searchBarcode: params['barcode'],
          categoryType: params['category_type'], categoryId: params['category_id'],
        );
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'data': products}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // 🛍️ CREATE SINGLE PRODUCT SLOT
    router.post('/product/create', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final id = await MenuDao(db).createProduct(
          tenantId: body['tenant_id'] ?? 'svenska_1',
          categoryId: int.parse(body['category_id'].toString()),
          productName: body['product_name'] ?? '',
          unitMeasure: body['unit_measure'] ?? '',
          barcode: body['barcode'] ?? '',
          costPrice: double.tryParse(body['cost_price'].toString()) ?? 0.0,
          salePrice: double.tryParse(body['sale_price'].toString()) ?? 0.0,
          mPrice: double.tryParse(body['m_price'].toString()) ?? 0.0,
        );
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'product_id': id}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // 📊 BATCH MASTER BULK-IMPORT ENGINE (Standardized for the new 7-column spreadsheet format)
    router.post('/bulk-import', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String tenantId = body['tenant_id'] ?? '';
        final List<dynamic> rawRows = body['csv_data'] ?? [];

        List<List<dynamic>> parsedRows = rawRows.map((row) => row as List<dynamic>).toList();

        // Triggers the corrected and dynamic MenuDao parser method cleanly
        await MenuDao(db).bulkImportMenu(tenantId, parsedRows);

        return Response.ok(
            jsonEncode({'status': 'SUCCESS', 'message': 'Bulk unified spreadsheet matrix import completed'}),
            headers: {'content-type': 'application/json'}
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // ✏️ INLINE FIELDS MODIFICATION LAYER
    router.post('/product/update-field', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final int productId = int.parse(body['product_id'].toString());
        final String column = body['column'].toString();
        dynamic finalValue = body['value'];

        if (column == DbContracts.columnProductCostPrice ||
            column == DbContracts.columnProductSalePrice ||
            column == DbContracts.columnProductMPrice) { // Enabled support for manual pricing alterations
          finalValue = double.tryParse(body['value'].toString()) ?? 0.0;
        }

        await MenuDao(db).updateProductField(productId: productId, column: column, value: finalValue);
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Field altered inline'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });


    router.get('/manual-liquor/groups', (Request request) async {
      final queryParams = request.url.queryParameters;
      final String tenantId = queryParams['tenant_id'] ?? 'svenska_1';
      final categories = await ManualLiquorDao(db).getCategories(tenantId);
      return Response.ok(jsonEncode({'status': 'SUCCESS', 'data': categories}), headers: {'content-type': 'application/json'});
    });

    router.post('/api/v1/manual-liquor/group/create', (Request request) async {
      final body = jsonDecode(await request.readAsString());
      await ManualLiquorDao(db).createCategory(
        tenantId: body['tenant_id'] ?? 'svenska_1',
        categoryName: body['name'],
      );
      return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Manual Liquor Group created'}), headers: {'content-type': 'application/json'});
    });

    router.post('/manual-liquor/product/create', (Request request) async {
      final body = jsonDecode(await request.readAsString());
      await ManualLiquorDao(db).createProduct(
        tenantId: body['tenant_id'] ?? 'svenska_1',
        categoryId: int.parse(body['category_id'].toString()),
        productName: body['product_name'],
        unitMeasure: body['unit_measure'] ?? 'ML',
        barcode: body['barcode'] ?? '',
        costPrice: double.tryParse(body['cost_price'].toString()) ?? 0.0,
        salePrice: double.tryParse(body['sale_price'].toString()) ?? 0.0,
        mPrice: double.tryParse(body['m_price']?.toString() ?? '0.0') ?? 0.0,
      );
      return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Manual Liquor Item saved'}), headers: {'content-type': 'application/json'});
    });

    router.get('/manual-liquor/products', (Request request) async {
      final params = request.url.queryParameters;
      final String tenantId = params['tenant_id'] ?? 'svenska_1';
      final items = await ManualLiquorDao(db).getFilteredProducts(
        tenantId: tenantId,
        limit: params['limit'] != null ? int.tryParse(params['limit']!) : null,
        offset: params['offset'] != null ? int.tryParse(params['offset']!) : null,
        searchName: params['name'],
        searchBarcode: params['barcode'],
        categoryId: params['category_id'],
      );
      return Response.ok(jsonEncode({'status': 'SUCCESS', 'data': items}), headers: {'content-type': 'application/json'});
    });

    router.post('/manual-liquor/product/update-field', (Request request) async {
      final body = jsonDecode(await request.readAsString());
      await ManualLiquorDao(db).updateProductField(
        productId: int.parse(body['product_id'].toString()),
        column: body['column'],
        value: body['value'],
      );
      return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Manual Liquor Product updated'}), headers: {'content-type': 'application/json'});
    });

    router.post('/manual-liquor/bulk-import', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString());
        final String tenantId = body['tenant_id'] ?? 'svenska_1';
        final List<dynamic> rawRows = body['csv_data'] ?? [];
        List<List<dynamic>> parsedRows = rawRows.map((row) => row as List<dynamic>).toList();

        await ManualLiquorDao(db).bulkImportManualLiquor(tenantId, parsedRows);
        return Response.ok(jsonEncode({'status': 'SUCCESS', 'message': 'Manual Liquor CSV Bulk Import completed'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    return router;
  }
}