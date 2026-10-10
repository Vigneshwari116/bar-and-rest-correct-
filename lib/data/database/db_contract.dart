class DbContracts {
  static const String tableTenants = 'tenants';
  static const String columnTenantId = 'id';
  static const String columnTenantName = 'name';
  static const String columnTenantAddress = 'address';

  static const String tableUsers = 'users';
  static const String columnUserId = 'id';
  static const String columnUserTenantId = 'tenant_id';
  static const String columnUsername = 'username';
  static const String columnPasswordHash = 'password_hash';
  static const String columnUserRole = 'role';

  static const String colArchiveEmployeeId = 'employee_id';
  static const String colArchiveEmployeeName = 'employee_name';

  static const String colLedgerEmployeeId = 'employee_id';
  static const String colLedgerEmployeeName = 'employee_name';

  static const String tableSessions = 'active_sessions';
  static const String columnSessionToken = 'token';
  static const String columnSessionUserId = 'user_id';
  static const String columnDeviceId = 'device_id';
  static const String columnLastActiveAt = 'last_active_at';
  static const String columnIsForcefullyLoggedOut = 'is_forcefully_logged_out';

  static const String tableCategories = 'menu_categories';
  static const String columnCategoryId = 'id';
  static const String columnCategoryTenantId = 'tenant_id';
  static const String columnCategoryType = 'category_type';
  static const String columnCategoryName = 'category_name';
  static const String columnCategoryIsActive = 'is_active';

  static const String tableProducts = 'products';
  static const String columnProductId = 'id';
  static const String columnProductTenantId = 'tenant_id';
  static const String columnProductCategoryId = 'category_id';
  static const String columnProductName = 'product_name';
  static const String columnProductUnit = 'unit_measure';
  static const String columnProductBarcode = 'barcode';
  static const String columnProductCostPrice = 'cost_price';
  static const String columnProductSalePrice = 'sale_price';
  static const String columnProductMPrice = 'm_price';
  static const String columnProductIsActive = 'is_active';

  static const String tableTablesMaster = 'table_master';
  static const String colTableId = 'table_id';
  static const String colTableName = 'table_name';
  static const String colTableStatus = 'status';

  static const String tableRunningOrders = 'running_orders';
  static const String colOrderId = 'order_id';
  static const String colOrderTableId = 'table_id';
  static const String colItemBarcode = 'barcode';
  static const String colItemName = 'item_name';
  static const String colItemCategory = 'category';
  static const String colPrice = 'price';
  static const String colQty = 'qty';
  static const String colAmount = 'amount';
  static const String colAddedAt = 'added_at';
  static const String colIsSettled = 'is_settled';
  static const String colLinkedBillId = 'linked_bill_id';
  static const String colOrderEmployeeId = 'employee_id';
  static const String colItemMPrice = 'm_price';

  static const String tableLiveOrdersLedger = 'live_orders_ledger';
  static const String colLedgerId = 'id';
  static const String colLedgerBillNo = 'bill_no';
  static const String colLedgerTableId = 'table_id';
  static const String colLedgerItemName = 'item_name';
  static const String colLedgerQty = 'qty';
  static const String colLedgerPrice = 'price';
  static const String colLedgerAmount = 'amount';
  static const String colLedgerCategoryType = 'category_type';
  static const String colLedgerCategoryName = 'category_name';
  static const String colLedgerCreatedAt = 'created_at';

  static const String tableHistoryOrdersArchive = 'history_orders_archive';
  static const String colArchiveId = 'archive_id';
  static const String colArchiveOrderId = 'order_id';
  static const String colArchiveTableId = 'table_id';
  static const String colArchiveItemName = 'item_name';
  static const String colArchiveQty = 'qty';
  static const String colArchivePrice = 'price';
  static const String colArchiveAmount = 'amount';
  static const String colArchiveCategoryType = 'category_type';
  static const String colArchiveBillNo = 'bill_no';
  static const String colArchiveBusinessDate = 'business_date';
  static const String colArchiveCreatedAt = 'created_at';

  static const String tableLiquorExciseAudit = 'liquor_excise_audit';
  static const String colExciseBillId = 'excise_bill_id';
  static const String colExciseOriginalBillNo = 'original_bill_no';
  static const String colExciseTableId = 'table_id';
  static const String colExciseItemId = 'item_id';
  static const String colExciseItemName = 'item_name';
  static const String colExciseQty = 'qty';
  static const String colExciseMPrice = 'm_price';
  static const String colExciseSalePrice = 'sale_price';
  static const String colExciseTotalMAmount = 'total_m_amount';
  static const String colExciseCreatedAt = 'created_at';

  static const String tableBillingMaster = 'billing_master';
  static const String colBillId = 'bill_id';
  static const String colBillTableId = 'table_id';
  static const String colCustomerMobile = 'customer_mobile';
  static const String colFoodTotal = 'food_total';
  static const String colLiquorTotal = 'liquor_total';
  static const String colGrandTotal = 'grand_total';
  static const String colCheckoutAt = 'checkout_at';

  static const String tableBills = 'bills';
  static const String columnBillId = 'id';
  static const String columnBillNo = 'bill_no';
  static const String columnBillTableId = 'table_id';
  static const String columnBillLiquorTotal = 'liquor_total';
  static const String columnBillFoodTotal = 'food_total';
  static const String columnBillSoftTotal = 'soft_total';
  static const String columnBillOthersTotal = 'others_total';
  static const String columnBillGrandTotal = 'grand_total';
  static const String columnBillCreatedAt = 'created_at';
  static const String columnBillTenantId = 'tenant_id';

  static const String tableBillItems = 'bill_items';
  static const String columnBillItemProductId = 'product_id';
  static const String columnBillItemName = 'item_name';
  static const String columnBillItemQty = 'qty';
  static const String columnBillItemPrice = 'price';
  static const String columnBillItemCategoryType = 'category_type';

  // --- PRINTERS MASTER TABLE ---
  static const String tablePrintersMaster = 'printers_master';
  static const String colPrinterId = 'id';
  static const String colPrinterName = 'printer_name';
  static const String colPrinterType = 'printer_type';
  static const String colPrinterConnection = 'connection_type';
  static const String colPrinterTarget = 'target_address';
  static const String colPrinterIsActive = 'is_active';

  // --- SYSTEM CONFIG TABLE ---
  static const String tableSystemConfigs = 'system_configs';
  static const String colConfigKey = 'config_key';
  static const String colConfigValue = 'config_value';

  // --- MANUAL LIQUOR ARCHIVE TABLE ---
  static const String tableManualOrdersArchive = 'manual_orders_archive';
  static const String colManualArchiveId = 'archive_id';
  static const String colManualBillNo = 'manual_bill_no';
  static const String colManualTableId = 'table_id';
  static const String colManualItemName = 'item_name';
  static const String colManualQty = 'qty';
  static const String colManualPrice = 'price';
  static const String colManualAmount = 'amount';
  static const String colManualCategoryType = 'category_type';
  static const String colManualCategoryName = 'category_name';
  static const String colManualCustomerMobile = 'customer_mobile';
  static const String colManualBusinessDate = 'business_date';
  static const String colManualCreatedAt = 'created_at';

  // 🌟 NEW: DEDICATED MANUAL FOOD ARCHIVE TABLE
  static const String tableManualFoodArchive = 'manual_food_archive';
  static const String colFoodArchiveId = 'archive_id';
  static const String colFoodBillNo = 'food_bill_no';
  static const String colFoodTableId = 'table_id';
  static const String colFoodItemName = 'item_name';
  static const String colFoodQty = 'qty';
  static const String colFoodPrice = 'price';
  static const String colFoodAmount = 'amount';
  static const String colFoodCategoryName = 'category_name';
  static const String colFoodCustomerMobile = 'customer_mobile';
  static const String colFoodBusinessDate = 'business_date';
  static const String colFoodCreatedAt = 'created_at';

  static const String tableDeletedOrdersArchive = 'deleted_orders_archive';
  static const String colDeletedArchiveId = 'deleted_id';
  static const String colDeletedOriginalOrderId = 'original_order_id';
  static const String colDeletedTableId = 'table_id';
  static const String colDeletedEmployeeId = 'employee_id';
  static const String colDeletedItemName = 'item_name';
  static const String colDeletedCategoryType = 'category_type';
  static const String colDeletedPrice = 'price';
  static const String colDeletedQty = 'qty';
  static const String colDeletedAmount = 'amount';
  static const String colDeletedAt = 'deleted_at';

  static const String tableManualLiquorCategories = 'manual_liquor_categories';
  static const String tableManualLiquorProducts = 'manual_liquor_products';
}