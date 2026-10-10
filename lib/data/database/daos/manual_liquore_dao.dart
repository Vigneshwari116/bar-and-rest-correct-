import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class ManualLiquorDao {
  final Database db;
  ManualLiquorDao(this.db);

  Future<int> createCategory({required String tenantId, required String categoryName}) async {
    return await db.insert(DbContracts.tableManualLiquorCategories, {
      DbContracts.columnCategoryTenantId: tenantId,
      DbContracts.columnCategoryName: categoryName.toUpperCase().trim(),
      DbContracts.columnCategoryIsActive: 1,
    });
  }

  Future<List<Map<String, dynamic>>> getCategories(String tenantId) async {
    return await db.query(
      DbContracts.tableManualLiquorCategories,
      where: '${DbContracts.columnCategoryTenantId} = ? AND ${DbContracts.columnCategoryIsActive} = 1',
      whereArgs: [tenantId],
      orderBy: DbContracts.columnCategoryName,
    );
  }

  Future<int> createProduct({
    required String tenantId,
    required int categoryId,
    required String productName,
    required String unitMeasure,
    required String barcode,
    required double costPrice,
    required double salePrice,
    double mPrice = 0.0,
  }) async {
    return await db.insert(DbContracts.tableManualLiquorProducts, {
      DbContracts.columnProductTenantId: tenantId,
      DbContracts.columnProductCategoryId: categoryId,
      DbContracts.columnProductName: productName.toUpperCase().trim(),
      DbContracts.columnProductUnit: unitMeasure.toUpperCase().trim(),
      DbContracts.columnProductBarcode: barcode.trim(),
      DbContracts.columnProductCostPrice: costPrice,
      DbContracts.columnProductSalePrice: salePrice,
      DbContracts.columnProductMPrice: mPrice,
      DbContracts.columnProductIsActive: 1,
    });
  }

  Future<List<Map<String, dynamic>>> getFilteredProducts({
    required String tenantId,
    int? limit,
    int? offset,
    String? searchName,
    String? searchBarcode,
    String? categoryId,
  }) async {
    List<dynamic> whereArgs = [tenantId];

    String query = '''
      SELECT 
        p.${DbContracts.columnProductId} as id,
        p.${DbContracts.columnProductTenantId} as tenant_id,
        p.${DbContracts.columnProductCategoryId} as category_id,
        p.${DbContracts.columnProductName} as product_name,
        p.${DbContracts.columnProductUnit} as unit_measure,
        p.${DbContracts.columnProductBarcode} as barcode,
        p.${DbContracts.columnProductCostPrice} as cost_price,
        p.${DbContracts.columnProductSalePrice} as sale_price,
        p.${DbContracts.columnProductMPrice} as m_price,
        p.${DbContracts.columnProductIsActive} as is_active,
        p.category_type as category_type,
        c.${DbContracts.columnCategoryName} as category_name
      FROM ${DbContracts.tableManualLiquorProducts} p
      LEFT JOIN ${DbContracts.tableManualLiquorCategories} c ON p.${DbContracts.columnProductCategoryId} = c.${DbContracts.columnCategoryId}
      WHERE p.${DbContracts.columnProductTenantId} = ? AND p.${DbContracts.columnProductIsActive} = 1
    ''';

    if (searchName != null && searchName.trim().isNotEmpty) {
      query += " AND UPPER(p.${DbContracts.columnProductName}) LIKE ?";
      whereArgs.add('%${searchName.trim().toUpperCase()}%');
    }

    if (searchBarcode != null && searchBarcode.trim().isNotEmpty) {
      query += " AND LOWER(CAST(p.${DbContracts.columnProductBarcode} AS TEXT)) = LOWER(?)";
      whereArgs.add(searchBarcode.trim());
    }

    if (categoryId != null && categoryId != 'ALL' && categoryId.trim().isNotEmpty) {
      query += " AND p.${DbContracts.columnProductCategoryId} = ?";
      whereArgs.add(int.parse(categoryId.trim()));
    }

    query += " ORDER BY p.${DbContracts.columnProductName} ASC";
    if (limit != null && offset != null) {
      query += " LIMIT ? OFFSET ?";
      whereArgs.add(limit);
      whereArgs.add(offset);
    }

    return await db.rawQuery(query, whereArgs);
  }

  Future<int> updateProductField({required int productId, required String column, required dynamic value}) async {
    final allowedColumns = [
      DbContracts.columnProductName,
      DbContracts.columnProductBarcode,
      DbContracts.columnProductCostPrice,
      DbContracts.columnProductSalePrice,
      DbContracts.columnProductMPrice
    ];

    if (!allowedColumns.contains(column)) throw Exception("Unauthorized column update");

    return await db.update(
      DbContracts.tableManualLiquorProducts,
      {column: value is String ? value.toUpperCase().trim() : value},
      where: '${DbContracts.columnProductId} = ?',
      whereArgs: [productId],
    );
  }

  // 🍷 CSV BULK IMPORT ENGINE (AUTO CLEAR OLD DATA + STRICT UNIQUE BARCODE ENFORCEMENT)
  Future<void> bulkImportManualLiquor(String tenantId, List<List<dynamic>> csvRows) async {
    await db.transaction((txn) async {
      // 1. 🧹 STRICT CLEAR OLD DATA
      try {
        await txn.rawDelete(
          'DELETE FROM ${DbContracts.tableManualLiquorProducts} WHERE ${DbContracts.columnProductTenantId} = ?',
          [tenantId],
        );
        await txn.rawDelete(
          'DELETE FROM ${DbContracts.tableManualLiquorCategories} WHERE ${DbContracts.columnCategoryTenantId} = ?',
          [tenantId],
        );
        await txn.rawDelete(
          "DELETE FROM sqlite_sequence WHERE name IN (?, ?)",
          [DbContracts.tableManualLiquorProducts, DbContracts.tableManualLiquorCategories],
        );
      } catch (e) {
        print("⚠️ Data clear warning: $e");
      }

      Map<String, int> groupCache = {};
      Set<String> trackedBarcodesSet = {};

      // 2. 🚀 FRESH IMPORT LOOP
      for (int i = 1; i < csvRows.length; i++) {
        var row = csvRows[i];
        if (row.isEmpty || row.length < 7) continue;

        String groupName       = row[1].toString().trim().toUpperCase();
        String productName     = row[2].toString().trim().toUpperCase();
        String initialBarcode  = row[3].toString().trim();
        double finalCostPrice  = double.tryParse(row[4].toString().trim()) ?? 0.0;
        double finalSalePrice  = double.tryParse(row[5].toString().trim()) ?? 0.0;
        double finalMPrice     = double.tryParse(row[6].toString().trim()) ?? 0.0;
        String unitMeasure     = row.length > 7 ? row[7].toString().trim() : 'ML';

        if (groupName.isEmpty || productName.isEmpty) continue;

        // 🌟 STRICT UNIQUE BARCODE RESOLVER & COLLISION PREVENTER
        String resolvedBarcode = initialBarcode.toUpperCase();
        if (resolvedBarcode.isEmpty || resolvedBarcode == '0' || resolvedBarcode == '0.0' || trackedBarcodesSet.contains(resolvedBarcode)) {
          String cleanedPrefix = productName.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          cleanedPrefix = cleanedPrefix.length > 4 ? cleanedPrefix.substring(0, 4) : (cleanedPrefix.isEmpty ? "MLIQ" : cleanedPrefix);

          int uniqueSalt = DateTime.now().millisecondsSinceEpoch % 10000;
          resolvedBarcode = "MLI-$cleanedPrefix-$uniqueSalt-$i";

          // Double safety check if salt collides
          int counter = 1;
          while (trackedBarcodesSet.contains(resolvedBarcode)) {
            resolvedBarcode = "MLI-$cleanedPrefix-$uniqueSalt-$i-$counter";
            counter++;
          }
        }

        trackedBarcodesSet.add(resolvedBarcode);

        // Group Insertion Cache
        int currentGroupId;
        if (groupCache.containsKey(groupName)) {
          currentGroupId = groupCache[groupName]!;
        } else {
          currentGroupId = await txn.insert(DbContracts.tableManualLiquorCategories, {
            DbContracts.columnCategoryTenantId: tenantId,
            DbContracts.columnCategoryName: groupName,
            DbContracts.columnCategoryIsActive: 1,
          });
          groupCache[groupName] = currentGroupId;
        }

        // Product Insertion with Unique Barcode
        await txn.insert(DbContracts.tableManualLiquorProducts, {
          DbContracts.columnProductTenantId: tenantId,
          DbContracts.columnProductCategoryId: currentGroupId,
          DbContracts.columnProductName: productName,
          DbContracts.columnProductUnit: unitMeasure,
          DbContracts.columnProductBarcode: resolvedBarcode,
          DbContracts.columnProductCostPrice: finalCostPrice,
          DbContracts.columnProductSalePrice: finalSalePrice,
          DbContracts.columnProductMPrice: finalMPrice,
          DbContracts.columnProductIsActive: 1,
        });
      }
    });
  }
}