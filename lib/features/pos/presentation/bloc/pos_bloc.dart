/*
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/print_service.dart';
import 'pos_event.dart';
import 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  PosBloc() : super(const PosState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectTableEvent>(_onSelectTable);
    on<SelectEmployeeEvent>(_onSelectEmployee);
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddItemToOrderEvent>(_onAddItemToOrder);
    on<CheckoutTableEvent>(_onCheckoutTable);
    on<CheckoutManualTableEvent>(_onCheckoutManualTable);
    on<CreateTableEvent>(_onCreateTable);
    on<UpdateItemPriceEvent>(_onUpdateItemPrice);
    on<SettleFoodKOTEvent>(_onSettleFoodKOT);
    on<RemoveOrderItemEvent>(_onRemoveOrderItem);
    on<TransferTableEvent>(_onTransferTable);
    on<LoadShortcutsEvent>(_onLoadShortcuts);

    // 🌟 KOT PRINTED STATUS UPDATE EVENT HANDLER
    on<MarkKotPrintedEvent>(_onMarkKotPrinted);
    on<ReprintBillEvent>(_onReprintBill);
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<PosState> emit) async {
    emit(state.copyWith(status: PosStatus.loading));
    try {
      Map<String, String> shortcutsMap = {};
      try {
        final configsRes = await apiClient.get('/api/v1/pos/settings/configs');
        if (configsRes?.data != null && configsRes.data['data'] != null) {
          final Map<String, dynamic> configs = configsRes.data['data'];
          shortcutsMap = configs.map((k, v) => MapEntry(k, v.toString().toUpperCase()));
        }
      } catch (_) {}

      List<dynamic> printersData = [];
      try {
        final printersRes = await apiClient.get('/api/v1/pos/settings/printers');
        if (printersRes?.data != null && printersRes.data['data'] != null) {
          printersData = printersRes.data['data'] as List<dynamic>? ?? [];
        }
      } catch (_) {}

      final tablesResponse = await apiClient.get('/api/v1/pos/tables');
      final employeesResponse = await apiClient.get('/api/v1/pos/employees');
      final productsResponse = await apiClient.get('/api/v1/products');

      final tablesData = tablesResponse.data['data'] as List<dynamic>? ?? [];
      final employeesData = employeesResponse.data['data'] as List<dynamic>? ?? [];
      final catalogData = productsResponse.data['data'] as List<dynamic>? ?? [];

      final ordersResponse = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = ordersResponse.data['data'] as List<dynamic>? ?? [];

      int settledCount = 0;
      try {
        final countRes = await apiClient.get('/api/v1/pos/bills/settled-count');
        if (countRes != null && countRes.data != null) {
          settledCount = countRes.data['settled_count'] as int? ?? 0;
        }
      } catch (_) {}

      emit(state.copyWith(
        status: PosStatus.loaded,
        tables: tablesData,
        employees: employeesData,
        catalogItems: catalogData,
        runningOrders: runningOrders,
        printers: printersData,
        settledBillsCount: settledCount,
        shortcutsMap: shortcutsMap,
        selectedTableId: null,
        selectedEmployeeId: null,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to load master data."));
    }
  }

  Future<void> _onLoadShortcuts(LoadShortcutsEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/settings/configs');
      if (response?.data != null && response.data['data'] != null) {
        final Map<String, dynamic> configs = response.data['data'];
        final Map<String, String> shortcuts = configs.map(
              (k, v) => MapEntry(k, v.toString().toUpperCase()),
        );
        emit(state.copyWith(shortcutsMap: shortcuts));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onScanBarcode(ScanBarcodeEvent event, Emitter<PosState> emit) async {
    if (event.explicitItem != null) {
      emit(state.copyWith(
        previewItem: event.explicitItem,
        searchStatus: BarcodeSearchStatus.success,
      ));
      return;
    }

    if (event.barcode.trim().isEmpty) {
      emit(state.copyWith(
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
      return;
    }

    emit(state.copyWith(searchStatus: BarcodeSearchStatus.loading));

    try {
      final String cleanBarcode = event.barcode.trim().toLowerCase();
      final String encodedBarcode = Uri.encodeComponent(cleanBarcode);

      final String searchEndpoint = event.isManual
          ? '/api/v1/manual-liquor/products?barcode=$encodedBarcode'
          : '/api/v1/pos/products/search?barcode=$encodedBarcode';

      final response = await apiClient.get(searchEndpoint);

      if (response != null && response.data != null) {
        final resBody = response.data;
        if (resBody['status'] == 'SUCCESS' && resBody['data'] != null) {
          Map<String, dynamic> exactMatchProduct;
          if (resBody['data'] is List) {
            final List items = resBody['data'];
            if (items.isEmpty) {
              emit(state.copyWith(
                searchStatus: BarcodeSearchStatus.notFound,
                searchErrorMessage: "No product found in Manual Liquor DB matching Barcode: '${event.barcode}'",
                clearPreview: true,
              ));
              return;
            }
            exactMatchProduct = Map<String, dynamic>.from(items.first);
          } else {
            exactMatchProduct = Map<String, dynamic>.from(resBody['data']);
          }

          emit(state.copyWith(
            searchStatus: BarcodeSearchStatus.success,
            previewItem: exactMatchProduct,
          ));
          return;
        }
      }

      emit(state.copyWith(
        searchStatus: BarcodeSearchStatus.notFound,
        searchErrorMessage: "No product found matching Barcode: '${event.barcode}'",
        clearPreview: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        searchStatus: BarcodeSearchStatus.notFound,
        searchErrorMessage: "No product found matching Barcode: '${event.barcode}'",
        clearPreview: true,
      ));
    }
  }

  Future<void> _onSelectTable(SelectTableEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];

      emit(state.copyWith(
        status: PosStatus.loaded,
        runningOrders: runningOrders,
        selectedTableId: event.tableId == 'ALL' ? null : event.tableId,
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to fetch table orders"));
    }
  }

  Future<void> _onTransferTable(TransferTableEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/table/transfer', data: {
        'old_table_id': event.oldTableId,
        'new_table_id': event.newTableId,
      });
      add(SelectTableEvent(event.newTableId));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Table transfer failed!"));
    }
  }

  void _onSelectEmployee(SelectEmployeeEvent event, Emitter<PosState> emit) {
    emit(state.copyWith(selectedEmployeeId: event.employeeId));
  }

  Future<void> _onUpdateItemPrice(UpdateItemPriceEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/order/update-price', data: {
        'order_id': event.orderId,
        'price': event.newPrice,
      });
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];
      emit(state.copyWith(status: PosStatus.loaded, runningOrders: runningOrders));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to update item price"));
    }
  }

  Future<void> _onSettleFoodKOT(SettleFoodKOTEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/kot/settle', data: {
        'table_id': event.tableId,
      });
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];
      emit(state.copyWith(status: PosStatus.loaded, runningOrders: runningOrders));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to clear kitchen token orders"));
    }
  }




// Handler implementation:
  Future<void> _onReprintBill(ReprintBillEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/bill/reprint/${event.billNo}');

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final billData = response.data['data'];
        final String resolvedPrinter = _resolveTargetPrinterName(state.printers, 'BILL');

        // Thermal Printer Execution
        await PrinterService.printThermalBill(
          tableId: billData['table_id'],
          mobile: billData['customer_mobile'] ?? '',
          foodItems: List<Map<String, dynamic>>.from(billData['food_items']),
          liquorItems: List<Map<String, dynamic>>.from(billData['liquor_items']),
          grandTotal: double.parse(billData['grand_total'].toString()),
          billNo: billData['bill_no'],
          targetPrinterName: resolvedPrinter,
        );

        if (event.onResult != null) {
          event.onResult!(true, "✅ Bill #${event.billNo} Reprinted Successfully!");
        }
      } else {
        if (event.onResult != null) {
          event.onResult!(false, "⚠️ Bill #${event.billNo} not found!");
        }
      }
    } catch (e) {
      if (event.onResult != null) {
        event.onResult!(false, "🔴 Reprint Error: ${e.toString()}");
      }
    }
  }

// Printer Helper inside PosBloc (agar pehle se nahi hai):
  String _resolveTargetPrinterName(List<dynamic> printersList, String preferredType) {
    if (printersList.isEmpty) return "";
    for (var p in printersList) {
      final String pType = (p['printer_type'] ?? '').toString().toUpperCase();
      final String isActiveStr = (p['is_active'] ?? '').toString();
      final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');
      final String targetAddr = (p['target_address'] ?? '').toString().trim();

      if (pType == preferredType.toUpperCase() && isActive && targetAddr.isNotEmpty) {
        return targetAddr;
      }
    }
    for (var p in printersList) {
      final String isActiveStr = (p['is_active'] ?? '').toString();
      final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');
      final String targetAddr = (p['target_address'] ?? '').toString().trim();
      if (isActive && targetAddr.isNotEmpty) return targetAddr;
    }
    return printersList.isNotEmpty ? (printersList.first['target_address'] ?? '').toString().trim() : "";
  }


  // 🌟 MARK KOT PRINTED API CALL HANDLER
  Future<void> _onMarkKotPrinted(MarkKotPrintedEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.post('/api/v1/pos/kot/mark-printed', data: {
        'table_id': event.tableId,
        'order_ids': event.orderIds,
      });

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        // Refetch latest running orders to update UI state
        final ordersRes = await apiClient.get('/api/v1/pos/orders/ALL');
        final runningOrders = ordersRes.data['data'] as List<dynamic>? ?? [];

        emit(state.copyWith(
          status: PosStatus.loaded,
          runningOrders: runningOrders,
        ));
      }
    } catch (e) {
      print("🔴 [PosBloc MarkKotPrinted Error]: $e");
    }
  }

  Future<void> _onCheckoutTable(CheckoutTableEvent event, Emitter<PosState> emit) async {
    if (state.selectedTableId == null) return;
    emit(state.copyWith(status: PosStatus.loading));
    try {
      await apiClient.post('/api/v1/pos/checkout', data: {
        'table_id': state.selectedTableId,
        'customer_mobile': event.mobileNumber,
      });
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];

      int updatedSettledCount = state.settledBillsCount + 1;
      try {
        final countRes = await apiClient.get('/api/v1/pos/bills/settled-count');
        if (countRes != null && countRes.data != null) {
          updatedSettledCount = countRes.data['settled_count'] as int? ?? updatedSettledCount;
        }
      } catch (_) {}

      emit(state.copyWith(
        status: PosStatus.checkoutSuccess,
        runningOrders: runningOrders,
        settledBillsCount: updatedSettledCount,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Checkout failed"));
    }
  }

  Future<void> _onCheckoutManualTable(CheckoutManualTableEvent event, Emitter<PosState> emit) async {
    emit(state.copyWith(status: PosStatus.loading));
    try {
      await apiClient.post('/api/v1/pos/manual/checkout', data: {
        'table_id': event.tableId,
        'customer_mobile': event.mobileNumber,
        'business_date': event.businessDateStr,
      });

      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];

      // 🌟 Fetch latest settled bills count (Synced for Regular POS & Manual Liquor)
      int updatedSettledCount = state.settledBillsCount;
      try {
        final countRes = await apiClient.get('/api/v1/pos/bills/settled-count');
        if (countRes != null && countRes.data != null) {
          updatedSettledCount = countRes.data['settled_count'] as int? ?? updatedSettledCount;
        }
      } catch (_) {}

      emit(state.copyWith(
        status: PosStatus.checkoutSuccess,
        runningOrders: runningOrders,
        settledBillsCount: updatedSettledCount,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Manual Checkout failed"));
    }
  }

  Future<void> _onCreateTable(CreateTableEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/tables/create', data: {
        'table_id': event.tableId,
        'table_name': event.tableName,
      });
      final tablesResponse = await apiClient.get('/api/v1/pos/tables');
      emit(state.copyWith(status: PosStatus.loaded, tables: tablesResponse.data['data'] as List<dynamic>? ?? []));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Table creation failed"));
    }
  }

  Future<void> _onRemoveOrderItem(RemoveOrderItemEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/order/remove', data: {'order_id': event.orderId});
      add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to remove item."));
    }
  }

  Future<void> _onAddItemToOrder(AddItemToOrderEvent event, Emitter<PosState> emit) async {
    if (state.selectedTableId == null) {
      emit(state.copyWith(
        status: PosStatus.failure,
        errorMessage: "Please select a Table first!",
      ));
      emit(state.copyWith(status: PosStatus.loaded));
      return;
    }
    if (state.previewItem == null) return;

    try {
      final double finalPrice = event.customPrice ??
          (double.tryParse(state.previewItem!['sale_price'].toString()) ?? 0.0);

      final String rawCatType = state.previewItem!['category_type']?.toString().toUpperCase().trim() ?? '';
      final String finalCategoryType = rawCatType.isNotEmpty
          ? rawCatType
          : (event.isManual ? 'LIQUOR' : 'FOOD');

      final response = await apiClient.post('/api/v1/pos/orders/add', data: {
        'table_id': state.selectedTableId,
        'employee_id': state.selectedEmployeeId?.toString() ?? '1',
        'item_name': state.previewItem!['product_name'],
        'category': state.previewItem!['category_id'].toString(),
        'category_type': finalCategoryType,
        'price': finalPrice,
        'qty': event.qty,
        'barcode': state.previewItem!['barcode'],
        'is_manual': event.isManual,
      });

      if (response != null && response.data != null) {
        if (response.data['status'] == 'FAIL') {
          final String serverMsg = response.data['message']?.toString() ?? "Table Conflict Detected!";
          emit(state.copyWith(
            status: PosStatus.failure,
            errorMessage: serverMsg,
          ));
          emit(state.copyWith(status: PosStatus.loaded));
          return;
        }
      }

      final ordersRes = await apiClient.get('/api/v1/pos/orders/ALL');
      emit(state.copyWith(
        status: PosStatus.loaded,
        runningOrders: ordersRes.data['data'] as List<dynamic>? ?? [],
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      String cleanErrorMsg = "Table conflict or error adding item.";

      final String fullStr = e.toString();
      if (fullStr.contains("MANUAL POS mode")) {
        cleanErrorMsg = "Table ${state.selectedTableId} is currently ACTIVE in MANUAL POS mode!";
      } else if (fullStr.contains("REGULAR POS mode")) {
        cleanErrorMsg = "Table ${state.selectedTableId} is currently ACTIVE in REGULAR POS mode!";
      } else {
        cleanErrorMsg = fullStr.replaceAll("Exception: ", "").replaceAll("DioException: ", "");
      }

      emit(state.copyWith(
        status: PosStatus.failure,
        errorMessage: cleanErrorMsg,
      ));
      emit(state.copyWith(status: PosStatus.loaded));
    }
  }
}*/


import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/print_service.dart';
import 'pos_event.dart';
import 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  PosBloc() : super(const PosState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectTableEvent>(_onSelectTable);
    on<SelectEmployeeEvent>(_onSelectEmployee);
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddItemToOrderEvent>(_onAddItemToOrder);
    on<CheckoutTableEvent>(_onCheckoutTable);
    on<CheckoutManualTableEvent>(_onCheckoutManualTable);
    on<CreateTableEvent>(_onCreateTable);
    on<UpdateItemPriceEvent>(_onUpdateItemPrice);
    on<SettleFoodKOTEvent>(_onSettleFoodKOT);
    on<RemoveOrderItemEvent>(_onRemoveOrderItem);
    on<TransferTableEvent>(_onTransferTable);
    on<LoadShortcutsEvent>(_onLoadShortcuts);

    // 🌟 KOT PRINTED STATUS UPDATE & REPRINT
    on<MarkKotPrintedEvent>(_onMarkKotPrinted);
    on<ReprintBillEvent>(_onReprintBill);
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<PosState> emit) async {
    emit(state.copyWith(status: PosStatus.loading));
    try {
      Map<String, String> shortcutsMap = {};
      try {
        final configsRes = await apiClient.get('/api/v1/pos/settings/configs');
        if (configsRes?.data != null && configsRes.data['data'] != null) {
          final Map<String, dynamic> configs = configsRes.data['data'];
          shortcutsMap = configs.map((k, v) => MapEntry(k, v.toString().toUpperCase()));
        }
      } catch (_) {}

      List<dynamic> printersData = [];
      try {
        final printersRes = await apiClient.get('/api/v1/pos/settings/printers');
        if (printersRes?.data != null && printersRes.data['data'] != null) {
          printersData = printersRes.data['data'] as List<dynamic>? ?? [];
        }
      } catch (_) {}

      final tablesResponse = await apiClient.get('/api/v1/pos/tables');
      final employeesResponse = await apiClient.get('/api/v1/pos/employees');
      final productsResponse = await apiClient.get('/api/v1/products');

      final tablesData = tablesResponse.data['data'] as List<dynamic>? ?? [];
      final employeesData = employeesResponse.data['data'] as List<dynamic>? ?? [];
      final catalogData = productsResponse.data['data'] as List<dynamic>? ?? [];

      final ordersResponse = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = ordersResponse.data['data'] as List<dynamic>? ?? [];

      // 🌟 Regular POS + Manual Liquor Count
      int settledCount = 0;
      try {
        final countRes = await apiClient.get('/api/v1/pos/bills/settled-count');
        if (countRes != null && countRes.data != null) {
          settledCount = countRes.data['settled_count'] as int? ?? 0;
        }
      } catch (_) {}

      // 🍲 Pure Independent Manual Food Count
      int manualFoodCount = 0;
      try {
        final foodCountRes = await apiClient.get('/api/v1/pos/manual-food/settled-count');
        if (foodCountRes != null && foodCountRes.data != null) {
          manualFoodCount = foodCountRes.data['settled_count'] as int? ?? 0;
        }
      } catch (_) {}

      emit(state.copyWith(
        status: PosStatus.loaded,
        tables: tablesData,
        employees: employeesData,
        catalogItems: catalogData,
        runningOrders: runningOrders,
        printers: printersData,
        settledBillsCount: settledCount,
        manualFoodSettledCount: manualFoodCount,
        shortcutsMap: shortcutsMap,
        selectedTableId: null,
        selectedEmployeeId: null,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to load master data."));
    }
  }

  Future<void> _onLoadShortcuts(LoadShortcutsEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/settings/configs');
      if (response?.data != null && response.data['data'] != null) {
        final Map<String, dynamic> configs = response.data['data'];
        final Map<String, String> shortcuts = configs.map(
              (k, v) => MapEntry(k, v.toString().toUpperCase()),
        );
        emit(state.copyWith(shortcutsMap: shortcuts));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onScanBarcode(ScanBarcodeEvent event, Emitter<PosState> emit) async {
    if (event.explicitItem != null) {
      emit(state.copyWith(
        previewItem: event.explicitItem,
        searchStatus: BarcodeSearchStatus.success,
      ));
      return;
    }

    if (event.barcode.trim().isEmpty) {
      emit(state.copyWith(
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
      return;
    }

    emit(state.copyWith(searchStatus: BarcodeSearchStatus.loading));

    try {
      final String cleanBarcode = event.barcode.trim().toLowerCase();
      final String encodedBarcode = Uri.encodeComponent(cleanBarcode);

      final String searchEndpoint = event.isManual
          ? '/api/v1/manual-liquor/products?barcode=$encodedBarcode'
          : '/api/v1/pos/products/search?barcode=$encodedBarcode';

      final response = await apiClient.get(searchEndpoint);

      if (response != null && response.data != null) {
        final resBody = response.data;
        if (resBody['status'] == 'SUCCESS' && resBody['data'] != null) {
          Map<String, dynamic> exactMatchProduct;
          if (resBody['data'] is List) {
            final List items = resBody['data'];
            if (items.isEmpty) {
              emit(state.copyWith(
                searchStatus: BarcodeSearchStatus.notFound,
                searchErrorMessage: "No product found in Manual Liquor DB matching Barcode: '${event.barcode}'",
                clearPreview: true,
              ));
              return;
            }
            exactMatchProduct = Map<String, dynamic>.from(items.first);
          } else {
            exactMatchProduct = Map<String, dynamic>.from(resBody['data']);
          }

          emit(state.copyWith(
            searchStatus: BarcodeSearchStatus.success,
            previewItem: exactMatchProduct,
          ));
          return;
        }
      }

      emit(state.copyWith(
        searchStatus: BarcodeSearchStatus.notFound,
        searchErrorMessage: "No product found matching Barcode: '${event.barcode}'",
        clearPreview: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        searchStatus: BarcodeSearchStatus.notFound,
        searchErrorMessage: "No product found matching Barcode: '${event.barcode}'",
        clearPreview: true,
      ));
    }
  }

  Future<void> _onSelectTable(SelectTableEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];

      emit(state.copyWith(
        status: PosStatus.loaded,
        runningOrders: runningOrders,
        selectedTableId: event.tableId == 'ALL' ? null : event.tableId,
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to fetch table orders"));
    }
  }

  Future<void> _onTransferTable(TransferTableEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/table/transfer', data: {
        'old_table_id': event.oldTableId,
        'new_table_id': event.newTableId,
      });
      add(SelectTableEvent(event.newTableId));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Table transfer failed!"));
    }
  }

  void _onSelectEmployee(SelectEmployeeEvent event, Emitter<PosState> emit) {
    emit(state.copyWith(selectedEmployeeId: event.employeeId));
  }

  Future<void> _onUpdateItemPrice(UpdateItemPriceEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/order/update-price', data: {
        'order_id': event.orderId,
        'price': event.newPrice,
      });
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];
      emit(state.copyWith(status: PosStatus.loaded, runningOrders: runningOrders));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to update item price"));
    }
  }

  Future<void> _onSettleFoodKOT(SettleFoodKOTEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/kot/settle', data: {
        'table_id': event.tableId,
      });
      final response = await apiClient.get('/api/v1/pos/orders/ALL');
      final runningOrders = response.data['data'] as List<dynamic>? ?? [];
      emit(state.copyWith(status: PosStatus.loaded, runningOrders: runningOrders));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to clear kitchen token orders"));
    }
  }

  Future<void> _onReprintBill(ReprintBillEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.get('/api/v1/pos/bill/reprint/${event.billNo}?type=${event.billType}');

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final billData = response.data['data'];
        final String resolvedPrinter = _resolveTargetPrinterName(state.printers, 'BILL');

        // 🖨️ Thermal Printer Execution (With Original DB Timestamp)
        await PrinterService.printThermalBill(
          tableId: billData['table_id'],
          mobile: billData['customer_mobile'] ?? '',
          foodItems: List<Map<String, dynamic>>.from(billData['food_items'] ?? []),
          liquorItems: List<Map<String, dynamic>>.from(billData['liquor_items'] ?? []),
          grandTotal: double.parse(billData['grand_total'].toString()),
          billNo: billData['bill_no'],
          targetPrinterName: resolvedPrinter,
          billDateTime: billData['created_at']?.toString(), // 👈 🌟 Exact DB Timestamp
        );

        if (event.onResult != null) {
          event.onResult!(true, "✅ Bill #${event.billNo} Reprinted Successfully!");
        }
      } else {
        if (event.onResult != null) {
          event.onResult!(false, "⚠️ Bill #${event.billNo} not found in ${event.billType} history!");
        }
      }
    } catch (e) {
      if (event.onResult != null) {
        event.onResult!(false, "🔴 Reprint Error: ${e.toString()}");
      }
    }
  }

  String _resolveTargetPrinterName(List<dynamic> printersList, String preferredType) {
    if (printersList.isEmpty) return "";
    for (var p in printersList) {
      final String pType = (p['printer_type'] ?? '').toString().toUpperCase();
      final String isActiveStr = (p['is_active'] ?? '').toString();
      final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');
      final String targetAddr = (p['target_address'] ?? '').toString().trim();

      if (pType == preferredType.toUpperCase() && isActive && targetAddr.isNotEmpty) {
        return targetAddr;
      }
    }
    for (var p in printersList) {
      final String isActiveStr = (p['is_active'] ?? '').toString();
      final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');
      final String targetAddr = (p['target_address'] ?? '').toString().trim();
      if (isActive && targetAddr.isNotEmpty) return targetAddr;
    }
    return printersList.isNotEmpty ? (printersList.first['target_address'] ?? '').toString().trim() : "";
  }

  Future<void> _onMarkKotPrinted(MarkKotPrintedEvent event, Emitter<PosState> emit) async {
    try {
      final response = await apiClient.post('/api/v1/pos/kot/mark-printed', data: {
        'table_id': event.tableId,
        'order_ids': event.orderIds,
      });

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final ordersRes = await apiClient.get('/api/v1/pos/orders/ALL');
        final runningOrders = ordersRes.data['data'] as List<dynamic>? ?? [];

        emit(state.copyWith(
          status: PosStatus.loaded,
          runningOrders: runningOrders,
        ));
      }
    } catch (e) {
      print("🔴 [PosBloc MarkKotPrinted Error]: $e");
    }
  }

  // 🖨️ 1. REGULAR POS CHECKOUT HANDLER (PRINT FROM DB RESPONSE)
  Future<void> _onCheckoutTable(CheckoutTableEvent event, Emitter<PosState> emit) async {
    try {
      final currentTable = state.selectedTableId;
      if (currentTable == null || currentTable == 'ALL') return;

      // 🛡️ Snapshot of items before checkout for printing
      final currentTableOrders = state.runningOrders.where((order) {
        final matches = order['table_id'].toString().toUpperCase() == currentTable.toUpperCase();
        final rawManual = order['is_manual'];
        final isRegular = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');
        return matches && isRegular;
      }).toList();

      List<Map<String, dynamic>> foodItems = [];
      List<Map<String, dynamic>> liquorItems = [];
      for (var o in currentTableOrders) {
        String catType = o['category_type']?.toString().toUpperCase() ?? 'FOOD';
        if (catType == 'LIQUOR') {
          liquorItems.add(Map<String, dynamic>.from(o));
        } else {
          foodItems.add(Map<String, dynamic>.from(o));
        }
      }

      // Step A: Server/DB ko checkout request bhejo
      final response = await apiClient.post('/api/v1/pos/checkout', data: {
        'table_id': currentTable,
        'customer_mobile': event.mobileNumber,
      });

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final dbData = response.data['data'];

        // 🌟 DATABASE SE AAYA CONFIRMED BILL NUMBER & DATE
        final String confirmedDbBillNo = dbData['daily_bill_no']?.toString() ?? dbData['bill_id']?.toString() ?? '1';
        final String confirmedCreatedAt = dbData['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final double confirmedGrandTotal = double.tryParse(dbData['grand_total']?.toString() ?? '0.0') ?? 0.0;

        // Step B: Agar Print flag true hai toh confirmed DB bill number se print karein
        if (event.shouldPrint) {
          final String resolvedPrinter = _resolveTargetPrinterName(state.printers, 'BILL');

          await PrinterService.printThermalBill(
            tableId: currentTable,
            mobile: event.mobileNumber ?? '',
            foodItems: foodItems,
            liquorItems: liquorItems,
            grandTotal: confirmedGrandTotal,
            billNo: confirmedDbBillNo, // 👈 🌟 100% DB CONFIRMED NUMBER
            billDateTime: confirmedCreatedAt, // 👈 🌟 100% DB CONFIRMED TIME
            targetPrinterName: resolvedPrinter,
          );
        }

        emit(state.copyWith(status: PosStatus.checkoutSuccess));
        add(LoadInitialDataEvent()); // Refresh state

        if (event.onResult != null) {
          event.onResult!(true, "✅ Bill #$confirmedDbBillNo Settled Successfully!");
        }
      } else {
        emit(state.copyWith(status: PosStatus.failure, errorMessage: "Checkout failed on server"));
        if (event.onResult != null) event.onResult!(false, "Checkout failed!");
      }
    } catch (e) {
      emit(state.copyWith(status: PosStatus.failure, errorMessage: e.toString()));
      if (event.onResult != null) event.onResult!(false, e.toString());
    }
  }

  // 🖨️ 2. MANUAL FOOD CHECKOUT HANDLER (PRINT FROM DB RESPONSE)
  Future<void> _onCheckoutManualTable(CheckoutManualTableEvent event, Emitter<PosState> emit) async {
    try {
      final currentTableOrders = state.runningOrders.where((order) {
        final matches = order['table_id'].toString().toUpperCase() == event.tableId.toUpperCase();
        final rawManual = order['is_manual'];
        final isManual = (rawManual == 1 || rawManual == true || rawManual.toString() == '1');
        final catType = order['category_type']?.toString().toUpperCase() ?? 'FOOD';
        return matches && isManual && (catType == 'FOOD' || catType != 'LIQUOR');
      }).toList();

      List<Map<String, dynamic>> foodItems = currentTableOrders.map((o) => Map<String, dynamic>.from(o)).toList();

      // Step A: Server/DB ko checkout request bhejo
      final response = await apiClient.post('/api/v1/pos/manual/checkout', data: {
        'table_id': event.tableId,
        'customer_mobile': event.mobileNumber,
        'business_date': event.businessDateStr,
      });

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final dbData = response.data['data'];

        // 🌟 DATABASE SE AAYA CONFIRMED FOOD BILL NUMBER & DATE
        final String confirmedFoodBillNo = dbData['food_bill_no']?.toString() ?? dbData['manual_bill_no']?.toString() ?? '1';
        final String confirmedCreatedAt = dbData['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final double confirmedGrandTotal = double.tryParse(dbData['grand_total']?.toString() ?? '0.0') ?? 0.0;

        // Step B: Confirmed number se print karein
        if (event.shouldPrint) {
          final String resolvedPrinter = _resolveTargetPrinterName(state.printers, 'BILL');

          await PrinterService.printThermalBill(
            tableId: event.tableId,
            mobile: event.mobileNumber ?? '',
            foodItems: foodItems,
            liquorItems: const [],
            grandTotal: confirmedGrandTotal,
            billNo: confirmedFoodBillNo, // 👈 🌟 100% DB CONFIRMED NUMBER
            billDateTime: confirmedCreatedAt,
            targetPrinterName: resolvedPrinter,
          );
        }

        emit(state.copyWith(status: PosStatus.checkoutSuccess));
        add(LoadInitialDataEvent());

        if (event.onResult != null) {
          event.onResult!(true, "✅ Manual Food Bill #$confirmedFoodBillNo Settled!");
        }
      } else {
        emit(state.copyWith(status: PosStatus.failure, errorMessage: "Manual checkout failed"));
        if (event.onResult != null) event.onResult!(false, "Checkout failed!");
      }
    } catch (e) {
      emit(state.copyWith(status: PosStatus.failure, errorMessage: e.toString()));
      if (event.onResult != null) event.onResult!(false, e.toString());
    }
  }

  Future<void> _onCreateTable(CreateTableEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/tables/create', data: {
        'table_id': event.tableId,
        'table_name': event.tableName,
      });
      final tablesResponse = await apiClient.get('/api/v1/pos/tables');
      emit(state.copyWith(status: PosStatus.loaded, tables: tablesResponse.data['data'] as List<dynamic>? ?? []));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Table creation failed"));
    }
  }

  Future<void> _onRemoveOrderItem(RemoveOrderItemEvent event, Emitter<PosState> emit) async {
    try {
      await apiClient.post('/api/v1/pos/order/remove', data: {'order_id': event.orderId});
      add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
    } catch (e) {
      emit(state.copyWith(status: PosStatus.error, errorMessage: "Failed to remove item."));
    }
  }

  Future<void> _onAddItemToOrder(AddItemToOrderEvent event, Emitter<PosState> emit) async {
    if (state.selectedTableId == null) {
      emit(state.copyWith(
        status: PosStatus.failure,
        errorMessage: "Please select a Table first!",
      ));
      emit(state.copyWith(status: PosStatus.loaded));
      return;
    }
    if (state.previewItem == null) return;

    try {
      final double finalPrice = event.customPrice ??
          (double.tryParse(state.previewItem!['sale_price'].toString()) ?? 0.0);

      final String rawCatType = state.previewItem!['category_type']?.toString().toUpperCase().trim() ?? '';
      final String finalCategoryType = rawCatType.isNotEmpty
          ? rawCatType
          : (event.isManual ? 'LIQUOR' : 'FOOD');

      final response = await apiClient.post('/api/v1/pos/orders/add', data: {
        'table_id': state.selectedTableId,
        'employee_id': state.selectedEmployeeId?.toString() ?? '1',
        'item_name': state.previewItem!['product_name'],
        'category': state.previewItem!['category_id'].toString(),
        'category_type': finalCategoryType,
        'price': finalPrice,
        'qty': event.qty,
        'barcode': state.previewItem!['barcode'],
        'is_manual': event.isManual,
      });

      if (response != null && response.data != null) {
        if (response.data['status'] == 'FAIL') {
          final String serverMsg = response.data['message']?.toString() ?? "Table Conflict Detected!";
          emit(state.copyWith(
            status: PosStatus.failure,
            errorMessage: serverMsg,
          ));
          emit(state.copyWith(status: PosStatus.loaded));
          return;
        }
      }

      final ordersRes = await apiClient.get('/api/v1/pos/orders/ALL');
      emit(state.copyWith(
        status: PosStatus.loaded,
        runningOrders: ordersRes.data['data'] as List<dynamic>? ?? [],
        clearPreview: true,
        searchStatus: BarcodeSearchStatus.initial,
      ));
    } catch (e) {
      String cleanErrorMsg = "Table conflict or error adding item.";

      final String fullStr = e.toString();
      if (fullStr.contains("MANUAL POS mode")) {
        cleanErrorMsg = "Table ${state.selectedTableId} is currently ACTIVE in MANUAL POS mode!";
      } else if (fullStr.contains("REGULAR POS mode")) {
        cleanErrorMsg = "Table ${state.selectedTableId} is currently ACTIVE in REGULAR POS mode!";
      } else {
        cleanErrorMsg = fullStr.replaceAll("Exception: ", "").replaceAll("DioException: ", "");
      }

      emit(state.copyWith(
        status: PosStatus.failure,
        errorMessage: cleanErrorMsg,
      ));
      emit(state.copyWith(status: PosStatus.loaded));
    }
  }
}