

// ==========================================================================
// 🌟 1. POS EVENT MATRIX DEFINITIONS
// ==========================================================================
abstract class PosEvent {}

class LoadInitialDataEvent extends PosEvent {}

class SelectTableEvent extends PosEvent {
  final String tableId;
  SelectTableEvent(this.tableId);
}

class SelectEmployeeEvent extends PosEvent {
  final int employeeId;
  SelectEmployeeEvent(this.employeeId);
}

// 🌟 REGULAR POS CHECKOUT EVENT
class CheckoutTableEvent extends PosEvent {
  final String? mobileNumber;
  final bool shouldPrint;
  final Function(bool isSuccess, String message)? onResult;

  CheckoutTableEvent({
    this.mobileNumber,
    this.shouldPrint = true,
    this.onResult,
  });

  @override
  List<Object?> get props => [mobileNumber, shouldPrint];
}

// 🌟 MANUAL FOOD CHECKOUT EVENT
class CheckoutManualTableEvent extends PosEvent {
  final String tableId;
  final String? mobileNumber;
  final String businessDateStr;
  final bool shouldPrint;
  final Function(bool isSuccess, String message)? onResult;

  CheckoutManualTableEvent({
    required this.tableId,
    this.mobileNumber,
    required this.businessDateStr,
    this.shouldPrint = true,
    this.onResult,
  });

  @override
  List<Object?> get props => [tableId, mobileNumber, businessDateStr, shouldPrint];
}


class AddItemToOrderEvent extends PosEvent {
  final int qty;
  final double? customPrice;
  final bool isManual; // 👈 Ensure isManual field exists

  AddItemToOrderEvent(
      this.qty, {
        this.customPrice,
        this.isManual = false, // 👈 Default false (Regular POS ke liye)
      });
}

class CreateTableEvent extends PosEvent {
  final String tableId;
  final String tableName;
  CreateTableEvent({required this.tableId, required this.tableName});
}



class ScanBarcodeEvent extends PosEvent {
  final String barcode;
  final Map<String, dynamic>? explicitItem;
  final bool isManual; // 👈 Add this flag

  ScanBarcodeEvent(this.barcode, {this.explicitItem, this.isManual = false});
}

class MarkKotPrintedEvent extends PosEvent {
  final String tableId;
  final List<int> orderIds;

   MarkKotPrintedEvent({
    required this.tableId,
    required this.orderIds,
  });

  @override
  List<Object?> get props => [tableId, orderIds];
}

class ReprintBillEvent extends PosEvent {
  final String billNo;
  final String billType; // 'MANUAL_FOOD' ya 'REGULAR'
  final Function(bool isSuccess, String message)? onResult;

  ReprintBillEvent({
    required this.billNo,
    this.billType = 'REGULAR',
    this.onResult,
  });

  @override
  List<Object?> get props => [billNo, billType];
}

class UpdateItemPriceEvent extends PosEvent {
  final int orderId;
  final double newPrice;
  UpdateItemPriceEvent({required this.orderId, required this.newPrice});
}

// 🌟 NAYA EVENT 2: ALT+C Food Settle Trigger
class SettleFoodKOTEvent extends PosEvent {
  final String tableId;
  SettleFoodKOTEvent(this.tableId);
}

class RemoveOrderItemEvent extends PosEvent {
  final int orderId;
  RemoveOrderItemEvent(this.orderId);
}

class TransferTableEvent extends PosEvent {
  final String oldTableId;
  final String newTableId;
  TransferTableEvent({required this.oldTableId, required this.newTableId});
}

class StrictBarcodeSearchEvent extends PosEvent {
  final String barcode;
  StrictBarcodeSearchEvent(this.barcode);
}

class LoadShortcutsEvent extends PosEvent {}


