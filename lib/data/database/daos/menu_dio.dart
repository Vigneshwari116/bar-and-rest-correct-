
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../db_contract.dart';

class MenuDao {
  final Database db;
  MenuDao(this.db);

  Future<int> createCategory({required String tenantId, required String categoryType, required String categoryName}) async {
    return await db.insert(DbContracts.tableCategories, {
      DbContracts.columnCategoryTenantId: tenantId,
      DbContracts.columnCategoryType: categoryType.toUpperCase(),
      DbContracts.columnCategoryName: categoryName.toUpperCase(),
      DbContracts.columnCategoryIsActive: 1,
    });
  }

  Future<List<Map<String, dynamic>>> getCategories(String tenantId, {String? type}) async {
    String whereClause = '${DbContracts.columnCategoryTenantId} = ? AND ${DbContracts.columnCategoryIsActive} = 1';
    List<dynamic> whereArgs = [tenantId];
    if (type != null && type.isNotEmpty) {
      whereClause += ' AND ${DbContracts.columnCategoryType} = ?';
      whereArgs.add(type.toUpperCase());
    }
    return await db.query(DbContracts.tableCategories, where: whereClause, whereArgs: whereArgs, orderBy: DbContracts.columnCategoryName);
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
    return await db.insert(DbContracts.tableProducts, {
      DbContracts.columnProductTenantId: tenantId,
      DbContracts.columnProductCategoryId: categoryId,
      DbContracts.columnProductName: productName.toUpperCase(),
      DbContracts.columnProductUnit: unitMeasure.toUpperCase(),
      DbContracts.columnProductBarcode: barcode.trim(), // Strict trim spacing error se bachne ke liye
      DbContracts.columnProductCostPrice: costPrice,
      DbContracts.columnProductSalePrice: salePrice,
      DbContracts.columnProductMPrice: mPrice,
      DbContracts.columnProductIsActive: 1,
    });
  }

  // 🌟 FIXING ENGINE: Strict explicit column selection alias mapping taaki runtime par key collision na ho
  Future<List<Map<String, dynamic>>> getFilteredProducts({
    required String tenantId,
    int? limit,
    int? offset,
    String? searchName,
    String? searchBarcode,
    String? categoryType,
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
        c.${DbContracts.columnCategoryName} as category_name,
        c.${DbContracts.columnCategoryType} as category_type
      FROM ${DbContracts.tableProducts} p
      LEFT JOIN ${DbContracts.tableCategories} c ON p.${DbContracts.columnProductCategoryId} = c.${DbContracts.columnCategoryId}
      WHERE p.${DbContracts.columnProductTenantId} = ? AND p.${DbContracts.columnProductIsActive} = 1
    ''';

    final bool hasNameSearch = searchName != null && searchName.trim().isNotEmpty;
    final bool hasBarcodeSearch = searchBarcode != null && searchBarcode.trim().isNotEmpty;

    // 🎯 1. GLOBAL ON-DEMAND BARCODE SEARCH (DEPT & GROUP OVERRIDE)
    if (hasBarcodeSearch) {
      query += " AND (p.${DbContracts.columnProductBarcode} LIKE ? OR CAST(p.${DbContracts.columnProductBarcode} AS TEXT) = ?)";
      whereArgs.add('%${searchBarcode.trim()}%');
      whereArgs.add(searchBarcode.trim());
    }
    // 🎯 2. GLOBAL ON-DEMAND NAME SEARCH (DEPT & GROUP OVERRIDE)
    else if (hasNameSearch) {
      query += " AND p.${DbContracts.columnProductName} LIKE ?";
      whereArgs.add('%${searchName.trim().toUpperCase()}%');
    }
    // 🎯 3. NORMAL GROUP / DEPT FILTERING (Jab koi search na kar raha ho)
    else {
      if (categoryId != null && categoryId != 'ALL' && categoryId.trim().isNotEmpty) {
        query += " AND p.${DbContracts.columnProductCategoryId} = ?";
        whereArgs.add(int.parse(categoryId.trim()));
      } else if (categoryType != null && categoryType != 'ALL' && categoryType.trim().isNotEmpty) {
        query += " AND UPPER(c.${DbContracts.columnCategoryType}) = ?";
        whereArgs.add(categoryType.trim().toUpperCase());
      }
    }

    query += " ORDER BY p.${DbContracts.columnProductName} ASC";
    if (limit != null && offset != null) {
      query += " LIMIT ? OFFSET ?";
      whereArgs.add(limit);
      whereArgs.add(offset);
    }

    return await db.rawQuery(query, whereArgs);
  }

  // 🌟 FIXED & SECURED: Dynamic field update routine now allows M-PRICE alterations seamlessly
  Future<int> updateProductField({required int productId, required String column, required dynamic value}) async {
    final allowedColumns = [
      DbContracts.columnProductName,
      DbContracts.columnProductBarcode,
      DbContracts.columnProductCostPrice,
      DbContracts.columnProductSalePrice,
      DbContracts.columnProductMPrice // ✅ Enabled M-Price alteration support safely
    ];

    if (!allowedColumns.contains(column)) throw Exception("Unauthorized column alteration attempt");

    return await db.update(
        DbContracts.tableProducts,
        {column: value is String ? value.toUpperCase() : value},
        where: '${DbContracts.columnProductId} = ?', // ✅ Replaced fuzzy 'id' string with clear contract reference
        whereArgs: [productId]
    );
  }

  // 🌟 ADVANCED AUTOMATED INGESTION PROCESSING ENGINE (AUTO-CLEAR TABLE BEFORE IMPORT)
  Future<void> bulkImportMenu(String tenantId, List<List<dynamic>> csvRows) async {
    await db.transaction((txn) async {
      // 1. 🧹 STRICT CLEAR PURANA DATA (Foreign Keys constraints handling ke saath)
      try {
        // Child Table (Products) pehle delete karein
        await txn.rawDelete(
          'DELETE FROM ${DbContracts.tableProducts} WHERE ${DbContracts.columnProductTenantId} = ?',
          [tenantId],
        );

        // Parent Table (Categories) uske baad delete karein
        await txn.rawDelete(
          'DELETE FROM ${DbContracts.tableCategories} WHERE ${DbContracts.columnCategoryTenantId} = ?',
          [tenantId],
        );

        // Auto-increment sequence counter reset karein taaki IDs fresh 1 se shuru hon
        await txn.rawDelete(
          "DELETE FROM sqlite_sequence WHERE name IN (?, ?)",
          [DbContracts.tableProducts, DbContracts.tableCategories],
        );
      } catch (e) {
        print("⚠️ Regular Menu Table Clear Warning: $e");
      }

      Map<String, int> groupCache = {};
      Set<String> trackedBarcodesSet = {};

      // 2. 🚀 FRESH BATCH INSERTION (Header Index 0 Ko Chhod Kar)
      for (int i = 1; i < csvRows.length; i++) {
        var row = csvRows[i];
        if (row.isEmpty || row.length < 7) continue;

        // Extract unified attributes natively from master import CSV file
        String categoryType    = row[0].toString().trim().toUpperCase(); // Index 0: FOOD or LIQUOR
        String groupName       = row[1].toString().trim().toUpperCase(); // Index 1: Group Name
        String productName     = row[2].toString().trim().toUpperCase(); // Index 2: Item Description
        String initialBarcode  = row[3].toString().trim();                // Index 3: Barcode
        double finalCostPrice  = double.tryParse(row[4].toString().trim()) ?? 0.0; // Index 4: Cost
        double finalSalePrice  = double.tryParse(row[5].toString().trim()) ?? 0.0; // Index 5: Sale
        double finalMPrice     = double.tryParse(row[6].toString().trim()) ?? 0.0; // Index 6: M-Price
        String unitMeasure     = row.length > 7 ? row[7].toString().trim() : '';  // Index 7: Unit

        if (groupName.isEmpty || productName.isEmpty) continue;

        // 🌟 SAFE DUPLICATE BARCODE SCANNER AND GENERATOR INTERCEPTOR
        String resolvedBarcode = initialBarcode.trim().toUpperCase();
        if (resolvedBarcode.isEmpty ||
            resolvedBarcode == '0' || resolvedBarcode == '0.0' ||
            trackedBarcodesSet.contains(resolvedBarcode)) {

          String cleanedPrefix = productName.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (cleanedPrefix.length > 4) {
            cleanedPrefix = cleanedPrefix.substring(0, 4);
          } else if (cleanedPrefix.isEmpty) {
            cleanedPrefix = "ITEM";
          }

          int uniqueSalt = DateTime.now().millisecondsSinceEpoch % 10000;
          resolvedBarcode = "BC-$cleanedPrefix-$uniqueSalt-$i";
        }

        trackedBarcodesSet.add(resolvedBarcode);

        // Create category row dynamically if not existing inside mapping cache
        int currentGroupId;
        if (groupCache.containsKey(groupName)) {
          currentGroupId = groupCache[groupName]!;
        } else {
          currentGroupId = await txn.insert(DbContracts.tableCategories, {
            DbContracts.columnCategoryTenantId: tenantId,
            DbContracts.columnCategoryType: categoryType,
            DbContracts.columnCategoryName: groupName,
            DbContracts.columnCategoryIsActive: 1,
          });
          groupCache[groupName] = currentGroupId;
        }

        // 💾 EXECUTE STANDALONE DISPATCH SAVE
        await txn.insert(DbContracts.tableProducts, {
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
