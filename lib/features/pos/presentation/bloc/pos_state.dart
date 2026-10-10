/*
enum PosStatus { initial, loading, loaded, error, checkoutSuccess, failure }
enum BarcodeSearchStatus { initial, loading, success, notFound, failure }

class PosState {
  final PosStatus status;
  final List<dynamic> tables;
  final List<dynamic> employees;
  final List<dynamic> catalogItems;
  final List<dynamic> runningOrders;
  final List<dynamic> printers; // 👈 1. ADDED PRINTERS LIST
  final Map<String, dynamic>? previewItem;
  final String? selectedTableId;
  final int? selectedEmployeeId;
  final String errorMessage;

  final int settledBillsCount;
  final BarcodeSearchStatus searchStatus;
  final String? searchErrorMessage;
  final Map<String, String> shortcutsMap;

  const PosState({
    this.status = PosStatus.initial,
    this.tables = const [],
    this.employees = const [],
    this.catalogItems = const [],
    this.runningOrders = const [],
    this.printers = const [], // 👈 DEFAULT EMPTY LIST
    this.previewItem,
    this.selectedTableId,
    this.selectedEmployeeId,
    this.errorMessage = '',
    this.settledBillsCount = 0,
    this.searchStatus = BarcodeSearchStatus.initial,
    this.searchErrorMessage,
    this.shortcutsMap = const {},
  });

  int get pendingBillsCount {
    final distinctPendingTables = runningOrders
        .map((order) => order['table_id'].toString().toUpperCase())
        .toSet();
    return distinctPendingTables.length;
  }

  PosState copyWith({
    PosStatus? status,
    List<dynamic>? tables,
    List<dynamic>? employees,
    List<dynamic>? catalogItems,
    List<dynamic>? runningOrders,
    List<dynamic>? printers, // 👈 ADDED TO COPYWITH
    Map<String, dynamic>? previewItem,
    String? selectedTableId,
    int? selectedEmployeeId,
    String? errorMessage,
    int? settledBillsCount,
    bool clearPreview = false,
    BarcodeSearchStatus? searchStatus,
    String? searchErrorMessage,
    Map<String, String>? shortcutsMap,
  }) {
    return PosState(
      status: status ?? this.status,
      tables: tables ?? this.tables,
      employees: employees ?? this.employees,
      catalogItems: catalogItems ?? this.catalogItems,
      runningOrders: runningOrders ?? this.runningOrders,
      printers: printers ?? this.printers, // 👈 PASS PRINTERS
      previewItem: clearPreview ? null : (previewItem ?? this.previewItem),
      selectedTableId: selectedTableId ?? this.selectedTableId,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      errorMessage: errorMessage ?? this.errorMessage,
      settledBillsCount: settledBillsCount ?? this.settledBillsCount,
      searchStatus: searchStatus ?? this.searchStatus,
      searchErrorMessage: searchStatus == BarcodeSearchStatus.loading ? null : (searchErrorMessage ?? this.searchErrorMessage),
      shortcutsMap: shortcutsMap ?? this.shortcutsMap,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PosState &&
        other.status == status &&
        other.selectedTableId == selectedTableId &&
        other.selectedEmployeeId == selectedEmployeeId &&
        other.errorMessage == errorMessage &&
        other.previewItem == previewItem &&
        other.settledBillsCount == settledBillsCount &&
        other.searchStatus == searchStatus &&
        other.searchErrorMessage == searchErrorMessage &&
        other.tables.length == tables.length &&
        other.employees.length == employees.length &&
        other.catalogItems.length == catalogItems.length &&
        other.runningOrders.length == runningOrders.length &&
        other.printers.length == printers.length;
  }

  @override
  int get hashCode {
    return status.hashCode ^
    selectedTableId.hashCode ^
    selectedEmployeeId.hashCode ^
    tables.length.hashCode ^
    runningOrders.length.hashCode ^
    printers.length.hashCode ^
    settledBillsCount.hashCode ^
    searchStatus.hashCode ^
    searchErrorMessage.hashCode;
  }
}*/

enum PosStatus { initial, loading, loaded, error, checkoutSuccess, failure }
enum BarcodeSearchStatus { initial, loading, success, notFound, failure }

class PosState {
  final PosStatus status;
  final List<dynamic> tables;
  final List<dynamic> employees;
  final List<dynamic> catalogItems;
  final List<dynamic> runningOrders;
  final List<dynamic> printers;
  final Map<String, dynamic>? previewItem;
  final String? selectedTableId;
  final int? selectedEmployeeId;
  final String errorMessage;

  final int settledBillsCount;
  final int manualFoodSettledCount; // 👈 1. ADDED MANUAL FOOD SETTLED COUNT
  final BarcodeSearchStatus searchStatus;
  final String? searchErrorMessage;
  final Map<String, String> shortcutsMap;

  const PosState({
    this.status = PosStatus.initial,
    this.tables = const [],
    this.employees = const [],
    this.catalogItems = const [],
    this.runningOrders = const [],
    this.printers = const [],
    this.previewItem,
    this.selectedTableId,
    this.selectedEmployeeId,
    this.errorMessage = '',
    this.settledBillsCount = 0,
    this.manualFoodSettledCount = 0, // 👈 2. DEFAULT VALUE 0
    this.searchStatus = BarcodeSearchStatus.initial,
    this.searchErrorMessage,
    this.shortcutsMap = const {},
  });

  int get pendingBillsCount {
    final distinctPendingTables = runningOrders
        .map((order) => order['table_id'].toString().toUpperCase())
        .toSet();
    return distinctPendingTables.length;
  }

  PosState copyWith({
    PosStatus? status,
    List<dynamic>? tables,
    List<dynamic>? employees,
    List<dynamic>? catalogItems,
    List<dynamic>? runningOrders,
    List<dynamic>? printers,
    Map<String, dynamic>? previewItem,
    String? selectedTableId,
    int? selectedEmployeeId,
    String? errorMessage,
    int? settledBillsCount,
    int? manualFoodSettledCount, // 👈 3. ADDED TO COPYWITH
    bool clearPreview = false,
    BarcodeSearchStatus? searchStatus,
    String? searchErrorMessage,
    Map<String, String>? shortcutsMap,
  }) {
    return PosState(
      status: status ?? this.status,
      tables: tables ?? this.tables,
      employees: employees ?? this.employees,
      catalogItems: catalogItems ?? this.catalogItems,
      runningOrders: runningOrders ?? this.runningOrders,
      printers: printers ?? this.printers,
      previewItem: clearPreview ? null : (previewItem ?? this.previewItem),
      selectedTableId: selectedTableId ?? this.selectedTableId,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      errorMessage: errorMessage ?? this.errorMessage,
      settledBillsCount: settledBillsCount ?? this.settledBillsCount,
      manualFoodSettledCount: manualFoodSettledCount ?? this.manualFoodSettledCount, // 👈 4. PASS VALUE
      searchStatus: searchStatus ?? this.searchStatus,
      searchErrorMessage: searchStatus == BarcodeSearchStatus.loading ? null : (searchErrorMessage ?? this.searchErrorMessage),
      shortcutsMap: shortcutsMap ?? this.shortcutsMap,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PosState &&
        other.status == status &&
        other.selectedTableId == selectedTableId &&
        other.selectedEmployeeId == selectedEmployeeId &&
        other.errorMessage == errorMessage &&
        other.previewItem == previewItem &&
        other.settledBillsCount == settledBillsCount &&
        other.manualFoodSettledCount == manualFoodSettledCount && // 👈 5. COMPARISON
        other.searchStatus == searchStatus &&
        other.searchErrorMessage == searchErrorMessage &&
        other.tables.length == tables.length &&
        other.employees.length == employees.length &&
        other.catalogItems.length == catalogItems.length &&
        other.runningOrders.length == runningOrders.length &&
        other.printers.length == printers.length;
  }

  @override
  int get hashCode {
    return status.hashCode ^
    selectedTableId.hashCode ^
    selectedEmployeeId.hashCode ^
    tables.length.hashCode ^
    runningOrders.length.hashCode ^
    printers.length.hashCode ^
    settledBillsCount.hashCode ^
    manualFoodSettledCount.hashCode ^ // 👈 6. HASH CODE
    searchStatus.hashCode ^
    searchErrorMessage.hashCode;
  }
}