/*

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';
import '../widgets/print_service.dart';

class PosBillingPage extends StatelessWidget {
  const PosBillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PosBloc()..add(LoadInitialDataEvent()),
      child: const PosBillingView(),
    );
  }
}

class PosBillingView extends StatefulWidget {
  const PosBillingView({super.key});

  @override
  State<PosBillingView> createState() => _PosBillingViewState();
}

class _PosBillingViewState extends State<PosBillingView> with SingleTickerProviderStateMixin {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController(text: 'NO ITEM DETECTED');
  final TextEditingController _tableInputController = TextEditingController();
  final TextEditingController _empInputController = TextEditingController();

  // 🌟 STATIC WAITER LIST (ONLY 1 TO 10)
  static final List<String> _staticWaitersList = List.generate(10, (index) => "${index + 1}");

  List<dynamic> _filteredTablesCache = [];
  List<String> _filteredEmpCache = List.from(_staticWaitersList);

  OverlayEntry? _tableOverlayEntry;
  OverlayEntry? _empOverlayEntry;

  bool _isTableDropdownOpen = false;
  bool _isEmpDropdownOpen = false;
  int _tableSelectedIndex = 0;
  int _empSelectedIndex = 0;

  bool _isRateEditable = false;

  Map<String, dynamic>? _scannedItemCache;
  String _shortcutKeyBuffer = '';
  Timer? _shortcutBufferTimer;

  final FocusNode _tableFocusNode = FocusNode();
  final FocusNode _empFocusNode = FocusNode();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  final LayerLink _tableLayerLink = LayerLink();
  final LayerLink _empLayerLink = LayerLink();

  // ⚡ EXECUTIVE POS UNIFORM COMPONENT HEIGHT
  static const double uniformComponentHeight = 50.0;
  static const Color uniformFieldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableFocusNode.requestFocus();
    });
    HardwareKeyboard.instance.addHandler(_globalKeyboardFilterHook);

    _tableFocusNode.addListener(() {
      if (!_tableFocusNode.hasFocus) _closeTableOverlay();
    });
    _empFocusNode.addListener(() {
      if (!_empFocusNode.hasFocus) _closeEmpOverlay();
    });
  }

  @override
  void dispose() {
    _closeTableOverlay();
    _closeEmpOverlay();
    HardwareKeyboard.instance.removeHandler(_globalKeyboardFilterHook);
    _barcodeController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _itemNameController.dispose();
    _tableInputController.dispose();
    _empInputController.dispose();
    _tableFocusNode.dispose();
    _empFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  bool _isValidTableForDisplay(String tableName) {
    final cleanName = tableName.trim().toUpperCase();
    if (cleanName.isEmpty) return false;

    final cleanDigits = cleanName.replaceAll(RegExp(r'[^\d]'), '');
    final intVal = int.tryParse(cleanDigits);

    if (intVal != null) {
      if (intVal >= 50 && intVal <= 55) return false;
      if (intVal >= 1 && intVal <= 49) return true;
      if (intVal >= 101 && intVal <= 120) return true;
    }
    return true;
  }

  bool _isVipTable(String tableId) {
    final cleanId = tableId.replaceAll(RegExp(r'[^\d]'), '');
    final tableNum = int.tryParse(cleanId) ?? 0;
    return tableNum >= 101 && tableNum <= 120;
  }

  bool _isBarcodeInEditableRange(String rawBarcode) {
    if (rawBarcode.trim().isEmpty) return false;
    final String numericOnly = rawBarcode.replaceAll(RegExp(r'[^\d]'), '');
    final int? numValue = int.tryParse(numericOnly);
    if (numValue != null && numValue >= 175 && numValue <= 230) {
      return true;
    }
    return false;
  }

  void _closeTableOverlay() {
    _tableOverlayEntry?.remove();
    _tableOverlayEntry = null;
  }

  void _closeEmpOverlay() {
    _empOverlayEntry?.remove();
    _empOverlayEntry = null;
  }

  void _selectTableAndAutoRestoreWaiter(String tableId, PosState state) {
    _tableInputController.text = tableId.toUpperCase();
    context.read<PosBloc>().add(SelectTableEvent(tableId.toUpperCase()));

    final activeOrders = state.runningOrders.where(
            (o) => o['table_id'].toString().toUpperCase() == tableId.toUpperCase()
    ).toList();

    if (activeOrders.isNotEmpty) {
      final assignedEmpId = activeOrders.first['employee_id']?.toString().trim() ?? '';
      if (assignedEmpId.isNotEmpty) {
        _empInputController.text = assignedEmpId;
        final int parsedId = int.tryParse(assignedEmpId) ?? 1;
        context.read<PosBloc>().add(SelectEmployeeEvent(parsedId));
      }
    }
  }

  void _executeAbsoluteFormReset() {
    setState(() {
      _tableInputController.clear();
      _empInputController.clear();
      _barcodeController.clear();
      _itemNameController.text = "NO ITEM DETECTED";
      _qtyController.text = "1";
      _priceController.clear();
      _scannedItemCache = null;
      _isRateEditable = false;
    });

    _closeTableOverlay();
    _closeEmpOverlay();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        context.read<PosBloc>().add(SelectTableEvent('ALL'));
        _tableFocusNode.requestFocus();
      }
    });
  }

  bool _globalKeyboardFilterHook(KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool altPressed = HardwareKeyboard.instance.isAltPressed;
      final String pressedKey = event.logicalKey.keyLabel.toUpperCase();

      final state = context.read<PosBloc>().state;
      final shortcuts = state.shortcutsMap;

      final String configuredKotKey = shortcuts['SHORTCUT_KOT'] ?? 'ALT+C';
      if (altPressed && configuredKotKey.contains(pressedKey)) {
        _triggerInstantFoodKOTToken(state);
        _shortcutKeyBuffer = '';
        return true;
      }

      if (RegExp(r'^[0-9A-Z]$').hasMatch(pressedKey) || pressedKey.startsWith('F')) {
        _shortcutKeyBuffer += pressedKey;

        _shortcutBufferTimer?.cancel();
        _shortcutBufferTimer = Timer(const Duration(milliseconds: 1000), () {
          _shortcutKeyBuffer = '';
        });
      }

      if (event.logicalKey == LogicalKeyboardKey.enter && _shortcutKeyBuffer.isNotEmpty) {
        final String input = _shortcutKeyBuffer.trim();
        _shortcutKeyBuffer = '';

        final String focusTableShortcut = shortcuts['SHORTCUT_FOCUS_TABLE'] ?? '555';
        final String billCheckoutShortcut = shortcuts['SHORTCUT_BILL'] ?? '777';
        final String changeTableShortcut = shortcuts['SHORTCUT_CHANGE_TABLE'] ?? '999';

        if (input == focusTableShortcut) {
          _tableFocusNode.requestFocus();
          return true;
        }

        if (input == billCheckoutShortcut) {
          final String? selectedTable = state.selectedTableId;

          if (selectedTable == null || selectedTable.isEmpty) {
            _showSnackBarLocal("PLEASE SELECT A TABLE FIRST!", Colors.redAccent);
            _tableFocusNode.requestFocus();
            return true;
          }

          final bool isConflictInManualMode = state.runningOrders.any((item) =>
          item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
              (item['is_manual'] == 1 || item['is_manual'] == true));

          if (isConflictInManualMode) {
            _showSnackBarLocal("Table $selectedTable is currently ACTIVE in MANUAL POS mode! Billing Blocked.", Colors.redAccent);
            _tableFocusNode.requestFocus();
            return true;
          }

          final hasRegularOrdersForThisTable = state.runningOrders.any((item) =>
          item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
              (item['is_manual'] == 0 || item['is_manual'] == false || item['is_manual'] == null));

          if (hasRegularOrdersForThisTable) {
            _showCheckoutDialog(context, state);
          } else {
            _showSnackBarLocal("NO ACTIVE REGULAR ORDERS ON TABLE $selectedTable", Colors.amber);
          }
          return true;
        }

        if (input == changeTableShortcut) {
          if (state.selectedTableId != null) {
            _showTableTransferDialog(context, state);
          } else {
            _showSnackBarLocal("SELECT ANY TABLE FIRST", Colors.red);
          }
          return true;
        }
      }
    }
    return false;
  }

  String resolveTargetPrinterName(List<dynamic> printersList, String preferredType) {
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

      if (isActive && targetAddr.isNotEmpty) {
        return targetAddr;
      }
    }

    if (printersList.isNotEmpty) {
      final String firstAddr = (printersList.first['target_address'] ?? '').toString().trim();
      if (firstAddr.isNotEmpty) return firstAddr;
    }

    return "";
  }

  // 🌟 KOT PRINT FUNCTION (FOOD + LIQUOR INCLUDED, UNPRINTED ONLY, CIGARETTE/'K' EXCLUDED

  void _triggerInstantFoodKOTToken(PosState state) async {
    String currentTargetTable = _tableInputController.text.trim().toUpperCase();
    if (currentTargetTable.isEmpty && state.selectedTableId != null) {
      currentTargetTable = state.selectedTableId!.trim().toUpperCase();
    }

    final String currentWaiterId = _empInputController.text.trim();
    String waiterName = currentWaiterId.isNotEmpty ? "WAITER $currentWaiterId" : "WAITER #1";

    if (currentTargetTable.isEmpty || currentTargetTable == 'ALL') {
      _showSnackBarLocal("Please select a specific Table for KOT!", Colors.amber);
      return;
    }

    // 🌟 1. SEPARATE LISTS FOR FOOD & LIQUOR
    List<Map<String, dynamic>> unprintedFoodKOTList = [];
    List<Map<String, dynamic>> unprintedLiquorKOTList = [];
    List<int> unprintedOrderIds = [];

    for (var item in state.runningOrders) {
      final String orderTable = item['table_id']?.toString().trim().toUpperCase() ?? '';
      final String catType = item['category_type']?.toString().toUpperCase().trim() ?? '';
      final String catName = item['category_name']?.toString().toUpperCase().trim() ?? '';
      final String itemName = item['item_name']?.toString().toUpperCase().trim() ?? '';

      final dynamic rawManual = item['is_manual'];
      final bool isRegular = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');

      // 🛡️ STRICT TYPE-SAFE CHECK FOR ALREADY PRINTED ITEMS
      final dynamic rawPrinted = item['is_printed'];
      bool alreadyPrinted = false;

      if (rawPrinted != null) {
        if (rawPrinted is int) {
          alreadyPrinted = (rawPrinted == 1);
        } else if (rawPrinted is bool) {
          alreadyPrinted = rawPrinted;
        } else if (rawPrinted is String) {
          alreadyPrinted = (rawPrinted == '1' || rawPrinted.toLowerCase() == 'true');
        }
      }

      // 🛑 STRICT EXCLUSION FOR CIGARETTES / 'K' CATEGORY ITEMS
      final bool isCigaretteItem = (catName == 'K' ||
          catName == 'CIG' ||
          catName == 'CA' ||
          catName == 'S' ||
          catName.contains('CIGRATE') ||
          catName.contains('CIGARETTE') ||
          itemName.contains('CIGARETTE'));

      // 🎯 FILTER UNPRINTED & ELIGIBLE ITEMS FOR TARGET TABLE
      if (orderTable == currentTargetTable && !isCigaretteItem && isRegular && !alreadyPrinted) {
        // 🍲 2. CATEGORIZE INTO FOOD OR LIQUOR
        if (catType == 'LIQUOR' || catType.contains('LIQUOR')) {
          unprintedLiquorKOTList.add(Map<String, dynamic>.from(item));
        } else if (catType == 'FOOD' || catType.contains('FOOD')) {
          unprintedFoodKOTList.add(Map<String, dynamic>.from(item));
        }

        if (item['order_id'] != null) {
          unprintedOrderIds.add(int.parse(item['order_id'].toString()));
        }
      }
    }

    if (unprintedFoodKOTList.isEmpty && unprintedLiquorKOTList.isEmpty) {
      _showSnackBarLocal("⚠️ Table $currentTargetTable: All items already printed to KOT!", Colors.amber);
      return;
    }

    final String resolvedPrinter = await PrinterService.resolvePhysicalTargetPrinter(
      dbPrinters: state.printers,
      preferredType: 'KOT',
    );

    if (resolvedPrinter.isEmpty) {
      _showSnackBarLocal("🔴 NO ONLINE PRINTER CONNECTED! Check Printer USB/Power Cable.", Colors.redAccent);
      return;
    }

    try {
      // 🌟 3. PRINT FOOD KOT SLIP (IF FOOD ITEMS EXIST)
      if (unprintedFoodKOTList.isNotEmpty) {
        await PrinterService.printKitchenTokenSilent(
          tableId: currentTargetTable,
          foodItems: unprintedFoodKOTList,
          waiterId: currentWaiterId.isNotEmpty ? currentWaiterId : "1",
          waiterName: waiterName,
          targetPrinterName: resolvedPrinter,
        );
      }

      // 🌟 4. PRINT LIQUOR KOT SLIP (IF LIQUOR ITEMS EXIST - SEPARATE SLIP)
      if (unprintedLiquorKOTList.isNotEmpty) {
        await PrinterService.printKitchenTokenSilent(
          tableId: currentTargetTable,
          foodItems: unprintedLiquorKOTList, // Passes Liquor items on a separate slip
          waiterId: currentWaiterId.isNotEmpty ? currentWaiterId : "1",
          waiterName: waiterName,
          targetPrinterName: resolvedPrinter,
        );
      }

      // 5. Dispatch BLoC Event to mark DB
      context.read<PosBloc>().add(MarkKotPrintedEvent(
        tableId: currentTargetTable,
        orderIds: unprintedOrderIds,
      ));

      // 6. Instant Local Memory Update
      setState(() {
        for (var order in state.runningOrders) {
          if (unprintedOrderIds.contains(order['order_id'])) {
            order['is_printed'] = 1;
          }
        }
      });

      int totalPrintedCount = unprintedFoodKOTList.length + unprintedLiquorKOTList.length;
      _showSnackBarLocal("✅ KOT Printed ($totalPrintedCount Items) successfully in separate slips!", Colors.green);
    } catch (e) {
      _showSnackBarLocal("🔴 KOT Print Failed: $e", Colors.red);
    } finally {
      _executeAbsoluteFormReset();
    }
  }
  void _showSnackBarLocal(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 11)), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosBloc, PosState>(
      listenWhen: (previous, current) => previous.searchStatus != current.searchStatus || previous.status != current.status,
      listener: (context, blocState) {
        if (blocState.status == PosStatus.failure) {
          _showSnackBarLocal(
            blocState.errorMessage.isNotEmpty ? blocState.errorMessage : "Operation Blocked: Table Conflict or System Error!",
            Colors.redAccent,
          );
        }

        if (blocState.searchStatus == BarcodeSearchStatus.success && blocState.previewItem != null) {
          final item = blocState.previewItem!;
          _scannedItemCache = Map<String, dynamic>.from(item);

          final String rawBarcode = item['barcode']?.toString() ?? _barcodeController.text.trim();
          final bool isEditable = _isBarcodeInEditableRange(rawBarcode);

          setState(() {
            _itemNameController.text = item['product_name'].toString().toUpperCase();
            _priceController.text = item['sale_price'].toString();
            _qtyController.text = "1";
            _isRateEditable = isEditable;
          });

          if (isEditable) {
            _priceFocusNode.requestFocus();
          } else {
            _qtyFocusNode.requestFocus();
          }
        }

        if (blocState.searchStatus == BarcodeSearchStatus.notFound || blocState.searchStatus == BarcodeSearchStatus.failure) {
          _showSnackBarLocal(blocState.searchErrorMessage ?? "No product found matching barcode entry", Colors.red);

          setState(() {
            _barcodeController.clear();
            _itemNameController.text = "NO ITEM DETECTED";
            _priceController.clear();
            _scannedItemCache = null;
            _isRateEditable = false;
          });

          _barcodeFocusNode.requestFocus();
        }

        if (blocState.status == PosStatus.checkoutSuccess) {
          _executeAbsoluteFormReset();
        }
      },
      builder: (context, blocState) {
        if (blocState.status == PosStatus.initial && blocState.tables.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Column(
            children: [
              _buildRow1BillSummaryHeader(context, blocState),
              _buildRow2TableAndEmpHeader(context, blocState),
              _buildRow3BarcodeQtyAndItemStageLine(context, blocState),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: _buildSplitGridPanel(blocState, 'LIQUOR', const Color(0xFF7C3AED))),
                    VerticalDivider(width: 1, color: Colors.grey.shade300),
                    Expanded(flex: 10, child: _buildSplitGridPanel(blocState, 'FOOD', const Color(0xFFEA580C))),
                    VerticalDivider(width: 1, color: Colors.grey.shade300),
                    Expanded(flex: 3, child: _buildRightFloorTotalGrid(blocState)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow1BillSummaryHeader(BuildContext context, PosState state) {
    final int settledCount = state.settledBillsCount;
    final int pendingCount = state.pendingBillsCount;
    final int currentBillIndex = settledCount + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 3),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'BILL INDEX',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '#$currentBillIndex',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'SETTLED BILLS',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '$settledCount',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'PENDING BILLS',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: uniformComponentHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF00BCD4)),
              label: const Text(
                "REPRINT BILL",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: () => _showReprintBillDialog(context, state), // 👈 Open Reprint Modal
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 ROW 2: ENHANCED BOLD & BIGGER TABLE/WAITER DROPDOWN FIELDS (FONT SIZE 20 PRESERVED)
  Widget _buildRow2TableAndEmpHeader(BuildContext context, PosState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 1. TABLE INPUT FIELD (BIG & BOLD - FONT SIZE 20)
          CompositedTransformTarget(
            link: _tableLayerLink,
            child: SizedBox(
              width: 240,
              height: uniformComponentHeight, // 50.0 Height
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && _isTableDropdownOpen && _filteredTablesCache.isNotEmpty) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _tableSelectedIndex = (_tableSelectedIndex + 1) % _filteredTablesCache.length;
                      });
                      _showTableOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _tableSelectedIndex = (_tableSelectedIndex - 1 + _filteredTablesCache.length) % _filteredTablesCache.length;
                      });
                      _showTableOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      final item = _filteredTablesCache[_tableSelectedIndex];
                      final String selectedTableId = item['table_id'].toString().toUpperCase();

                      final bool hasManualConflict = state.runningOrders.any((o) =>
                      o['table_id'].toString().toUpperCase() == selectedTableId &&
                          (o['is_manual'] == 1 || o['is_manual'] == true));

                      if (hasManualConflict) {
                        _showSnackBarLocal("TABLE '$selectedTableId' IS CURRENTLY ACTIVE IN MANUAL POS MODE!", Colors.redAccent);
                        _tableInputController.clear();
                        _closeTableOverlay();
                        setState(() {
                          _isTableDropdownOpen = false;
                        });
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      _selectTableAndAutoRestoreWaiter(selectedTableId, state);
                      _closeTableOverlay();
                      setState(() {
                        _isTableDropdownOpen = false;
                      });
                      _empFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    final raw = _tableInputController.text.trim().toUpperCase();

                    if (raw.isNotEmpty) {
                      if (!_isValidTableForDisplay(raw)) {
                        _showSnackBarLocal("Table $raw is reserved for Excise Liquor Module!", Colors.redAccent);
                        _tableInputController.clear();
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      final bool existsInDb = state.tables.any((t) =>
                      t['table_name'].toString().trim().toUpperCase() == raw || t['table_id'].toString().trim().toUpperCase() == raw);

                      if (!existsInDb) {
                        _showSnackBarLocal("TABLE '$raw' DOES NOT EXIST IN DATABASE!", Colors.redAccent);
                        _tableInputController.clear();
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      final bool hasManualConflict = state.runningOrders.any(
                              (o) => o['table_id'].toString().toUpperCase() == raw && (o['is_manual'] == 1 || o['is_manual'] == true));

                      if (hasManualConflict) {
                        _showSnackBarLocal("TABLE '$raw' IS CURRENTLY ACTIVE IN MANUAL POS MODE!", Colors.redAccent);
                        _tableInputController.clear();
                        _closeTableOverlay();
                        setState(() {
                          _isTableDropdownOpen = false;
                        });
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      _selectTableAndAutoRestoreWaiter(raw, state);
                      _closeTableOverlay();
                      setState(() {
                        _isTableDropdownOpen = false;
                      });
                      _empFocusNode.requestFocus();
                    } else {
                      _tableFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  focusNode: _tableFocusNode,
                  controller: _tableInputController,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)), // 👈 20 FONT SIZE
                  onTap: () {
                    _isTableDropdownOpen = true;
                    _filteredTablesCache = state.tables.where((t) => _isValidTableForDisplay(t['table_name'].toString())).toList();
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  onChanged: (q) {
                    _isTableDropdownOpen = true;
                    final search = q.trim().toUpperCase();

                    List<dynamic> matchedTables = state.tables.where((t) {
                      final String tName = t['table_name'].toString().trim().toUpperCase();
                      final String tId = t['table_id'].toString().trim().toUpperCase();

                      bool isValid = _isValidTableForDisplay(tName);
                      if (!isValid) return false;

                      if (search.isEmpty) return true;
                      return tName.startsWith(search) || tName.contains(search) || tId.startsWith(search);
                    }).toList();

                    if (search.isNotEmpty) {
                      matchedTables.sort((a, b) {
                        final String aName = a['table_name'].toString().trim().toUpperCase();
                        final String bName = b['table_name'].toString().trim().toUpperCase();

                        if (aName == search) return -1;
                        if (bName == search) return 1;

                        bool aIsDirectSub = RegExp('^' + RegExp.escape(search) + r'[A-Z]+$').hasMatch(aName);
                        bool bIsDirectSub = RegExp('^' + RegExp.escape(search) + r'[A-Z]+$').hasMatch(bName);

                        if (aIsDirectSub && !bIsDirectSub) return -1;
                        if (!aIsDirectSub && bIsDirectSub) return 1;

                        bool aStarts = aName.startsWith(search);
                        bool bStarts = bName.startsWith(search);
                        if (aStarts && !bStarts) return -1;
                        if (!aStarts && bStarts) return 1;

                        if (aName.length != bName.length) {
                          return aName.length.compareTo(bName.length);
                        }

                        return aName.compareTo(bName);
                      });
                    }

                    _filteredTablesCache = matchedTables;
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  decoration: InputDecoration(
                    labelText: "ENTER TABLE ID",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _tableFocusNode.hasFocus ? const Color(0x1A2563EB) : uniformFieldBg,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. WAITER INPUT FIELD (BIG & BOLD - FONT SIZE 20)
          CompositedTransformTarget(
            link: _empLayerLink,
            child: SizedBox(
              width: 240,
              height: uniformComponentHeight, // 50.0 Height
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && _isEmpDropdownOpen && _filteredEmpCache.isNotEmpty) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _empSelectedIndex = (_empSelectedIndex + 1) % _filteredEmpCache.length;
                      });
                      _showEmpOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _empSelectedIndex = (_empSelectedIndex - 1 + _filteredEmpCache.length) % _filteredEmpCache.length;
                      });
                      _showEmpOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      final selectedIdStr = _filteredEmpCache[_empSelectedIndex];
                      final int empId = int.tryParse(selectedIdStr) ?? 1;

                      _empInputController.text = selectedIdStr;
                      context.read<PosBloc>().add(SelectEmployeeEvent(empId));
                      _closeEmpOverlay();
                      setState(() {
                        _isEmpDropdownOpen = false;
                      });
                      _barcodeFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    final raw = _empInputController.text.trim();
                    if (raw.isNotEmpty) {
                      final bool existsInList = _staticWaitersList.contains(raw);

                      if (!existsInList) {
                        _showSnackBarLocal("WAITER ID MUST BE BETWEEN 1 TO 10!", Colors.redAccent);
                        _empInputController.clear();
                        _empFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      final int empId = int.tryParse(raw) ?? 1;

                      context.read<PosBloc>().add(SelectEmployeeEvent(empId));
                      _closeEmpOverlay();
                      setState(() {
                        _isEmpDropdownOpen = false;
                      });
                      _barcodeFocusNode.requestFocus();
                    } else {
                      _empFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  focusNode: _empFocusNode,
                  controller: _empInputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)), // 👈 20 FONT SIZE
                  onTap: () {
                    _isEmpDropdownOpen = true;
                    _filteredEmpCache = List.from(_staticWaitersList);
                    _empSelectedIndex = 0;
                    _showEmpOverlay();
                  },
                  onChanged: (q) {
                    _isEmpDropdownOpen = true;
                    _filteredEmpCache = _staticWaitersList.where((id) => id.contains(q.trim())).toList();
                    _empSelectedIndex = 0;
                    _showEmpOverlay();
                  },
                  decoration: InputDecoration(
                    labelText: "ENTER WAITER ID (1-10)",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _empFocusNode.hasFocus ? const Color(0x1A2563EB) : uniformFieldBg,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            height: uniformComponentHeight,
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.add_box_rounded, color: Colors.orange, size: 40),
              onPressed: () => _showAddTableDialog(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow3BarcodeQtyAndItemStageLine(BuildContext context, PosState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 6),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            height: uniformComponentHeight,
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onSubmitted: (val) {
                final String input = val.trim().toUpperCase();
                if (input.isEmpty) {
                  _barcodeFocusNode.requestFocus();
                  return;
                }

                final shortcuts = context.read<PosBloc>().state.shortcutsMap;

                final String focusTableShortcut = shortcuts['SHORTCUT_FOCUS_TABLE'] ?? '555';
                final String billCheckoutShortcut = shortcuts['SHORTCUT_BILL'] ?? '777';
                final String changeTableShortcut = shortcuts['SHORTCUT_CHANGE_TABLE'] ?? '999';

                if (input == focusTableShortcut) {
                  _barcodeController.clear();
                  _tableFocusNode.requestFocus();
                  return;
                }

                if (input == billCheckoutShortcut) {
                  _barcodeController.clear();
                  final state = context.read<PosBloc>().state;
                  final String? selectedTable = state.selectedTableId;

                  if (selectedTable == null || selectedTable.isEmpty) {
                    _showSnackBarLocal("PLEASE SELECT A TABLE FIRST!", Colors.redAccent);
                    _tableFocusNode.requestFocus();
                    return;
                  }

                  final bool isConflictInManualMode = state.runningOrders.any((item) =>
                  item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
                      (item['is_manual'] == 1 || item['is_manual'] == true));

                  if (isConflictInManualMode) {
                    _showSnackBarLocal("Table $selectedTable is currently ACTIVE in MANUAL POS mode! Billing Blocked.", Colors.redAccent);
                    _tableFocusNode.requestFocus();
                    return;
                  }

                  final hasRegularOrdersForThisTable = state.runningOrders.any((item) =>
                  item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
                      (item['is_manual'] == 0 || item['is_manual'] == false || item['is_manual'] == null));

                  if (hasRegularOrdersForThisTable) {
                    _showCheckoutDialog(context, state);
                  } else {
                    _showSnackBarLocal("NO ACTIVE REGULAR ORDERS ON TABLE $selectedTable", Colors.amber);
                  }
                  return;
                }
                if (input == changeTableShortcut) {
                  _barcodeController.clear();
                  final state = context.read<PosBloc>().state;
                  if (state.selectedTableId != null) {
                    _showTableTransferDialog(context, state);
                  } else {
                    _showSnackBarLocal("SELECT ANY TABLE FIRST", Colors.red);
                  }
                  return;
                }

                context.read<PosBloc>().add(ScanBarcodeEvent(input));
              },
              decoration: const InputDecoration(
                labelText: "BARCODE",
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.qr_code, size: 16),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 80,
            height: uniformComponentHeight,
            child: TextField(
              controller: _qtyController,
              focusNode: _qtyFocusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onSubmitted: (val) {
                if (val.trim().isEmpty) {
                  _barcodeFocusNode.requestFocus();
                  return;
                }

                final String currentTable = _tableInputController.text.trim().toUpperCase();
                if (currentTable.isEmpty || _empInputController.text.trim().isEmpty) {
                  _showSnackBarLocal("Please input Table ID and Waiter Identity first!", Colors.redAccent);
                  if (currentTable.isEmpty) {
                    _tableFocusNode.requestFocus();
                  } else {
                    _empFocusNode.requestFocus();
                  }
                  return;
                }

                final targetItem = _scannedItemCache ?? blocStatePreviewItem(context);

                if (targetItem != null) {
                  int countQty = int.tryParse(val.trim()) ?? 1;
                  double? customRate = double.tryParse(_priceController.text.trim());

                  context.read<PosBloc>().add(AddItemToOrderEvent(countQty, customPrice: _isRateEditable ? customRate : null));

                  setState(() {
                    _barcodeController.clear();
                    _itemNameController.text = "NO ITEM DETECTED";
                    _qtyController.text = "1";
                    _priceController.clear();
                    _isRateEditable = false;
                  });

                  Future.delayed(const Duration(milliseconds: 50), () {
                    _scannedItemCache = null;
                    context.read<PosBloc>().add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
                    _barcodeFocusNode.requestFocus();
                  });
                } else {
                  _barcodeFocusNode.requestFocus();
                }
              },
              decoration: const InputDecoration(
                labelText: "QTY",
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            height: uniformComponentHeight,
            child: TextField(
              readOnly: false, // 👈 HAMESHA EDITABLE REHGA (No lock check)
              controller: _priceController,
              focusNode: _priceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black, // 👈 Text color hamesha clear black rahega
              ),
              onSubmitted: (val) {
                final String currentTable = _tableInputController.text.trim().toUpperCase();
                if (currentTable.isEmpty || _empInputController.text.trim().isEmpty) {
                  _showSnackBarLocal("Please input Table ID and Waiter Identity first!", Colors.redAccent);
                  if (currentTable.isEmpty) {
                    _tableFocusNode.requestFocus();
                  } else {
                    _empFocusNode.requestFocus();
                  }
                  return;
                }

                final targetItem = _scannedItemCache ?? blocStatePreviewItem(context);

                if (targetItem != null) {
                  int countQty = int.tryParse(_qtyController.text.trim()) ?? 1;
                  // User ne jo rate enter kiya/edit kiya hai wo yahan se lega, otherwise original sale_price use karega
                  double? customRate = double.tryParse(_priceController.text.trim());

                  context.read<PosBloc>().add(AddItemToOrderEvent(countQty, customPrice: customRate));

                  setState(() {
                    _barcodeController.clear();
                    _itemNameController.text = "NO ITEM DETECTED";
                    _qtyController.text = "1";
                    _priceController.clear();
                    _isRateEditable = true; // Always true
                  });

                  Future.delayed(const Duration(milliseconds: 50), () {
                    _scannedItemCache = null;
                    context.read<PosBloc>().add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
                    _barcodeFocusNode.requestFocus();
                  });
                } else {
                  _barcodeFocusNode.requestFocus();
                }
              },
              decoration: InputDecoration(
                labelText: "RATE",
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                prefixText: "₹",
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: Colors.amber.shade50, // 👈 Editable look ke liye soft amber background
              ),
            ),
          ),

          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: uniformComponentHeight,
              width: 200,
              child: TextField(
                controller: _itemNameController,
                readOnly: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                decoration: const InputDecoration(
                  labelText: "ITEM NAME",
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: uniformFieldBg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 TABLE DROPDOWN OVERLAY (ENHANCED BIGGER FONT)
  void _showTableOverlay() {
    _closeTableOverlay();
    _tableOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: _tableLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 180.0,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade600, width: 2.0), color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: _filteredTablesCache.isEmpty
                  ? const Center(child: Text("No records match", style: TextStyle(fontSize: 11)))
                  : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredTablesCache.length,
                itemBuilder: (ctx, idx) {
                  final t = _filteredTablesCache[idx];
                  final isSelected = idx == _tableSelectedIndex;
                  return Container(
                    height: 36,
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      t['table_name'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black), // 👈 15 FONT SIZE
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tableOverlayEntry!);
  }

  // 🌟 WAITER DROPDOWN OVERLAY (ENHANCED BIGGER FONT)
  void _showEmpOverlay() {
    _closeEmpOverlay();
    _empOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: _empLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 180.0,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade600, width: 2.0), color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: _filteredEmpCache.isEmpty
                  ? const Center(child: Text("No IDs found", style: TextStyle(fontSize: 11)))
                  : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredEmpCache.length,
                itemBuilder: (ctx, idx) {
                  final waiterId = _filteredEmpCache[idx];
                  final isSelected = idx == _empSelectedIndex;

                  return Container(
                    height: 36,
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      "WAITER ID: $waiterId",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black), // 👈 15 FONT SIZE
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_empOverlayEntry!);
  }

  Map<String, dynamic>? blocStatePreviewItem(BuildContext ctx) {
    try {
      return context.read<PosBloc>().state.previewItem;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSplitGridPanel(PosState state, String currentTargetFilterType, Color headerBarColor) {
    final bool isVip = _isVipTable(state.selectedTableId ?? '');

    final displayItems = state.runningOrders.where((item) {
      final String itemDirectType = item['category_type']?.toString().toUpperCase() ?? '';
      final bool matchesSelectedTable = state.selectedTableId != null && item['table_id'].toString().toUpperCase() == state.selectedTableId!.toUpperCase();

      final bool isRegularItem = (item['is_manual'] == 0 || item['is_manual'] == false || item['is_manual'] == null);

      return itemDirectType == currentTargetFilterType && matchesSelectedTable && isRegularItem;
    }).toList();

    double sectionTotal = displayItems.fold(0.0, (sum, item) {
      double itemAmt = double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
      if (itemAmt == 0.0) {
        double itemPrice = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        int itemQty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        itemAmt = itemPrice * itemQty;
      }
      return sum + itemAmt;
    });

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          Container(
            color: headerBarColor,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "$currentTargetFilterType STREAM",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                    ),
                    if (currentTargetFilterType == 'FOOD' && isVip) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3)),
                        child: const Text(
                          "VIP +5%",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8),
                        ),
                      ),
                    ]
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "TOTAL: ₹${sectionTotal.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("S.N", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("TBL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("QTY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text("RATE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text("TOTAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text("DEL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),

          Expanded(
            child: displayItems.isEmpty
                ? Center(child: Text("No items active on table ${state.selectedTableId ?? ''} under $currentTargetFilterType.", style: const TextStyle(color: Colors.grey, fontSize: 10)))
                : ListView.separated(
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => Divider(height: 0.5, color: Colors.grey.shade200),
              itemBuilder: (ctx, i) {
                final order = displayItems[i];
                double unitPrice = double.tryParse(order['price']?.toString() ?? '0.0') ?? 0.0;
                int qty = int.tryParse(order['qty']?.toString() ?? '1') ?? 1;
                double lineTotal = double.tryParse(order['amount']?.toString() ?? '0.0') ?? (unitPrice * qty);
                if (lineTotal == 0.0) lineTotal = unitPrice * qty;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text("${i + 1}", style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text(order['table_id'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                      Expanded(flex: 5, child: Text(order['item_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text(qty.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("₹${unitPrice.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
                      Expanded(flex: 2, child: Text("₹${lineTotal.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueAccent))),
                      Expanded(
                        flex: 1,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_forever, color: Colors.red, size: 16),
                          onPressed: () {
                            context.read<PosBloc>().add(RemoveOrderItemEvent(order['order_id'] as int));
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReprintBillDialog(BuildContext parentContext, PosState state) {
    final TextEditingController billNoController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print, color: Color(0xFF00BCD4), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "REPRINT SETTLED BILL",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ENTER SETTLED BILL NUMBER",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: billNoController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      cursorColor: const Color(0xFF00BCD4),
                      decoration: InputDecoration(
                        hintText: "e.g., 1, 2, 10...",
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF475569)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onSubmitted: (_) {
                        _triggerReprint(parentContext, ctx, billNoController, setDialogState, isLoading);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        icon: isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print, size: 14, color: Colors.white),
                        label: Text(
                          isLoading ? "FETCHING..." : "PRINT DUPLICATE",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isLoading
                            ? null
                            : () => _triggerReprint(parentContext, ctx, billNoController, setDialogState, isLoading),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// 🌟 Helper method for triggering event to Bloc
  void _triggerReprint(
      BuildContext parentContext,
      BuildContext dialogContext,
      TextEditingController billNoController,
      StateSetter setDialogState,
      bool isLoading,
      ) {
    final String billNo = billNoController.text.trim();
    if (billNo.isEmpty) {
      _showSnackBarLocal("Please enter a valid Bill Number!", Colors.redAccent);
      return;
    }

    setDialogState(() => isLoading = true);

    // 🌟 Event Dispatch with REGULAR tag (POS + Manual Liquor)
    parentContext.read<PosBloc>().add(
      ReprintBillEvent(
        billNo: billNo,
        billType: 'REGULAR', // 👈 Regular/Manual Liquor se dhundhega
        onResult: (isSuccess, message) {
          setDialogState(() => isLoading = false);
          if (isSuccess) {
            if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
            _showSnackBarLocal(message, Colors.green);
          } else {
            _showSnackBarLocal(message, Colors.orange);
          }
        },
      ),
    );
  }
  // 🌟 LIVE COUNTER MAP (SINGLE COLUMN VERTICAL)
  Widget _buildRightFloorTotalGrid(PosState state) {
    return SizedBox(
      width: 200,
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0F172A),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: const Text(
                "LIVE COUNTER MAP",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            Expanded(
              child: Builder(
                builder: (context) {
                  final activeSummaryList = state.tables
                      .where((tableElement) => _isValidTableForDisplay(tableElement['table_name'].toString()))
                      .map((tableElement) {
                    final String tableId = tableElement['table_id'].toString();
                    final bool isVip = _isVipTable(tableId);

                    double foodSubtotal = 0.0;
                    double liquorSubtotal = 0.0;

                    for (var element in state.runningOrders) {
                      final bool isRegularItem = (element['is_manual'] == 0 || element['is_manual'] == false || element['is_manual'] == null);

                      if (element['table_id'].toString().toUpperCase() == tableId.toUpperCase() && isRegularItem) {
                        double itemAmt = double.tryParse(element['amount']?.toString() ?? '0.0') ?? 0.0;
                        if (itemAmt == 0.0) {
                          double itemPrice = double.tryParse(element['price']?.toString() ?? '0.0') ?? 0.0;
                          int itemQty = int.tryParse(element['qty']?.toString() ?? '1') ?? 1;
                          itemAmt = itemPrice * itemQty;
                        }

                        String catType = element['category_type']?.toString().toUpperCase() ?? '';
                        if (catType == 'LIQUOR') {
                          liquorSubtotal += itemAmt;
                        } else {
                          foodSubtotal += itemAmt;
                        }
                      }
                    }

                    double vipFoodSurcharge = isVip ? (foodSubtotal * 0.05) : 0.0;
                    double cumulativeTableOutstandingTotal = (foodSubtotal + vipFoodSurcharge) + liquorSubtotal;

                    return {
                      'table_name': tableElement['table_name'].toString(),
                      'table_id': tableId,
                      'total': cumulativeTableOutstandingTotal,
                      'is_vip': isVip,
                    };
                  })
                      .where((element) => (element['total'] as double) > 0.0)
                      .toList();

                  if (activeSummaryList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                          SizedBox(height: 4),
                          Text(
                            "ALL TABLES\nCLEAR",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: activeSummaryList.length,
                    itemBuilder: (ctx, index) {
                      final node = activeSummaryList[index];
                      final bool isVipNode = node['is_vip'] as bool;
                      final String tableId = node['table_id'].toString();
                      final String tableName = node['table_name'].toString().toUpperCase();
                      final double totalAmt = node['total'] as double;

                      final bool isSelectedTable = state.selectedTableId?.toUpperCase() == tableId.toUpperCase();

                      return InkWell(
                        onTap: () {
                          _selectTableAndAutoRestoreWaiter(tableId, state);
                          _barcodeFocusNode.requestFocus();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelectedTable ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelectedTable
                                  ? const Color(0xFF2563EB)
                                  : (isVipNode ? Colors.amber.shade700 : const Color(0xFFCBD5E1)),
                              width: isSelectedTable || isVipNode ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 🌟 LEFT SIDE: Table Name & VIP Tag (Flexible to prevent overflow)
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chair_alt_rounded,
                                      size: 13,
                                      color: isVipNode ? Colors.amber.shade800 : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        tableName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12, // 👈 Reduced from 18 to 12
                                          fontWeight: FontWeight.w900,
                                          color: isVipNode ? Colors.amber.shade900 : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (isVipNode) ...[
                                      const SizedBox(width: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          "VIP",
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),

                              // 🌟 RIGHT SIDE: Total Amount Badge (Fits 5-Digit Amounts easily)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  "₹${totalAmt.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 11.5, // 👈 Perfect size for ₹99,999 without overflow
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showAddTableDialog(BuildContext parentContext) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 24,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.table_restaurant_rounded, color: Color(0xFF00BCD4), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "PROVISION NEW TABLE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ASSIGN UNIQUE IDENTIFIER",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        cursorColor: const Color(0xFF00BCD4),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: "e.g., TABLE 4B, VIP-1",
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.normal),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF475569), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            if (!_isValidTableForDisplay(val.trim().toUpperCase())) {
                              _showSnackBarLocal("Table ID 50-55 is reserved for Excise Module!", Colors.redAccent);
                              return;
                            }
                            parentContext.read<PosBloc>().add(CreateTableEvent(tableId: val.trim().toUpperCase(), tableName: val.trim().toUpperCase()));
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          "CANCEL",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isNotEmpty) {
                            if (!_isValidTableForDisplay(nameCtrl.text.trim().toUpperCase())) {
                              _showSnackBarLocal("Table ID 50-55 is reserved for Excise Module!", Colors.redAccent);
                              return;
                            }
                            parentContext.read<PosBloc>().add(CreateTableEvent(tableId: nameCtrl.text.trim().toUpperCase(), tableName: nameCtrl.text.trim().toUpperCase()));
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          "CONFIRM DISPATCH",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext parentContext, PosState state) {
    final mobileCtrl = TextEditingController();
    final FocusNode dialogFocusNode = FocusNode();

    final String currentTableId = state.selectedTableId ?? 'WALK-IN';
    final bool isVip = _isVipTable(currentTableId);

    final String currentBillNo = "${state.settledBillsCount + 1}";

    List<Map<String, dynamic>> foodItems = [];
    List<Map<String, dynamic>> liquorItems = [];

    final currentTableRunningOrders = state.runningOrders.where((order) {
      final bool matchesTable = order['table_id'].toString().toUpperCase() == currentTableId.toUpperCase();
      final bool isRegularItem = (order['is_manual'] == 0 || order['is_manual'] == false || order['is_manual'] == null);
      return matchesTable && isRegularItem;
    }).toList();

    for (var order in currentTableRunningOrders) {
      String catType = order['category_type']?.toString().toUpperCase() ?? 'FOOD';

      if (catType.isEmpty) {
        try {
          var catMatch = state.catalogItems.firstWhere((c) => c['category_id'].toString() == order['category'].toString());
          catType = catMatch['category_type'].toString().toUpperCase();
        } catch (_) {}
      }

      if (catType == 'LIQUOR') {
        liquorItems.add(order);
      } else {
        foodItems.add(order);
      }
    }

    double foodSubtotal = foodItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
    double liquorTotal = liquorItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));

    // 🌟 FIX 1: VIP Table ke liye 5% Food Surcharge Calculate Kiya Gaya
    double vipSurcharge = isVip ? (foodSubtotal * 0.05) : 0.0;

    // 🌟 FIX 2: Grand Total me VIP Surcharge Add Ho Gaya
    double grandTotal = foodSubtotal + vipSurcharge + liquorTotal;

    Future<void> executePrintAndCheckout(BuildContext dialogCtx) async {
      try {
        final String resolvedPrinter = resolveTargetPrinterName(state.printers, 'BILL');

        await PrinterService.printThermalBill(
          tableId: currentTableId,
          mobile: mobileCtrl.text,
          foodItems: foodItems,
          liquorItems: liquorItems,
          grandTotal: grandTotal, // 👈 Ab grandTotal me 5% VIP Charge Included Hai
          billNo: currentBillNo,
          targetPrinterName: resolvedPrinter,
        );

        parentContext.read<PosBloc>().add(CheckoutTableEvent(mobileNumber: mobileCtrl.text));
        _showSnackBarLocal("Bill Printed & Table Checked Out!", Colors.green);
      } catch (e) {
        _showSnackBarLocal("Print / Checkout Error: $e", Colors.red);
      } finally {
        if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);
        _executeAbsoluteFormReset();
      }
    }

    showDialog(
      context: parentContext,
      builder: (ctx) => Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            executePrintAndCheckout(ctx);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: const Color(0xFF0F172A),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text("Checkout Bill Settle: Table $currentTableId ${isVip ? '(VIP Table - +5% Surcharge)' : ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: mobileCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(labelText: "Customer Mobile (Optional)", prefixIcon: Icon(Icons.phone, size: 12), border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                        child: ListView(
                          padding: const EdgeInsets.all(6),
                          children: [
                            if (foodItems.isNotEmpty) ...[
                              const Text("FOOD ITEMS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ...foodItems.map((item) => Row(children: [
                                Expanded(flex: 3, child: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("x${item['qty']}", style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("₹${item['amount']}", style: const TextStyle(fontSize: 9), textAlign: TextAlign.right))
                              ])),
                            ],
                            if (liquorItems.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Text("LIQUOR ITEMS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                              ...liquorItems.map((item) => Row(children: [
                                Expanded(flex: 3, child: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("x${item['qty']}", style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("₹${item['amount']}", style: const TextStyle(fontSize: 9), textAlign: TextAlign.right))
                              ])),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 🌟 FIX 3: Breakdown Box Me VIP Surcharge Clear Dikhayein
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFFF8FAFC),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("FOOD & LIQUOR SUBTOTAL:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text("₹${(foodSubtotal + liquorTotal).toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (isVip && vipSurcharge > 0) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("VIP FOOD SURCHARGE (+5%):", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w900)),
                                  Text("₹${vipSurcharge.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                            const Divider(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("GRAND TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text("₹${grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 15))
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontSize: 11))),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => executePrintAndCheckout(ctx),
                            icon: const Icon(Icons.print, size: 12, color: Colors.white),
                            label: const Text("SETTLE & PRINT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                          )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTableTransferDialog(BuildContext context, PosState state) {
    final TextEditingController searchCtrl = TextEditingController();
    List filteredTables = state.tables.where((t) => _isValidTableForDisplay(t['table_name'].toString())).toList();
    int selectedIndex = 0;
    final posBloc = context.read<PosBloc>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00BCD4), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "TRANSFER TABLE: ${state.selectedTableId}",
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setDialogState(() {
                            if (selectedIndex < filteredTables.length - 1) {
                              selectedIndex++;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setDialogState(() {
                            if (selectedIndex > 0) {
                              selectedIndex--;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (filteredTables.isNotEmpty && state.selectedTableId != null) {
                            final targetTableId = filteredTables[selectedIndex]['table_id'].toString();
                            posBloc.add(TransferTableEvent(
                              oldTableId: state.selectedTableId!,
                              newTableId: targetTableId,
                            ));
                            Navigator.pop(ctx);
                          }
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      cursorColor: const Color(0xFF00BCD4),
                      decoration: InputDecoration(
                        hintText: "Type to Search Table (Use Arrow keys & Enter)",
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00BCD4), size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF475569)), borderRadius: BorderRadius.circular(4)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5), borderRadius: BorderRadius.circular(4)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filteredTables = state.tables
                              .where((t) => _isValidTableForDisplay(t['table_name'].toString()) && t['table_name'].toString().toUpperCase().contains(val.toUpperCase()))
                              .toList();
                          selectedIndex = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "AVAILABLE TARGET TABLES",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: filteredTables.isEmpty
                        ? const Center(child: Text("No Tables Found", style: TextStyle(color: Colors.grey, fontSize: 11)))
                        : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filteredTables.length,
                      itemBuilder: (c, i) {
                        final bool isSelected = i == selectedIndex;
                        return Container(
                          color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              filteredTables[i]['table_name'].toString().toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.white, size: 14) : null,
                            onTap: () {
                              posBloc.add(TransferTableEvent(
                                oldTableId: state.selectedTableId!,
                                newTableId: filteredTables[i]['table_id'].toString(),
                              ));
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Align(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CLOSE (ESC)", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}*/


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';
import '../widgets/print_service.dart';

class PosBillingPage extends StatelessWidget {
  const PosBillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PosBloc()..add(LoadInitialDataEvent()),
      child: const PosBillingView(),
    );
  }
}

class PosBillingView extends StatefulWidget {
  const PosBillingView({super.key});

  @override
  State<PosBillingView> createState() => _PosBillingViewState();
}

class _PosBillingViewState extends State<PosBillingView> with SingleTickerProviderStateMixin {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController(text: 'NO ITEM DETECTED');
  final TextEditingController _tableInputController = TextEditingController();
  final TextEditingController _empInputController = TextEditingController();

  // 🌟 STATIC WAITER LIST (ONLY 1 TO 10)
  static final List<String> _staticWaitersList = List.generate(10, (index) => "${index + 1}");

  List<dynamic> _filteredTablesCache = [];
  List<String> _filteredEmpCache = List.from(_staticWaitersList);

  OverlayEntry? _tableOverlayEntry;
  OverlayEntry? _empOverlayEntry;

  bool _isTableDropdownOpen = false;
  bool _isEmpDropdownOpen = false;
  int _tableSelectedIndex = 0;
  int _empSelectedIndex = 0;

  bool _isRateEditable = false;

  Map<String, dynamic>? _scannedItemCache;
  String _shortcutKeyBuffer = '';
  Timer? _shortcutBufferTimer;

  final FocusNode _tableFocusNode = FocusNode();
  final FocusNode _empFocusNode = FocusNode();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  final LayerLink _tableLayerLink = LayerLink();
  final LayerLink _empLayerLink = LayerLink();

  // ⚡ EXECUTIVE POS UNIFORM COMPONENT HEIGHT
  static const double uniformComponentHeight = 50.0;
  static const Color uniformFieldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableFocusNode.requestFocus();
    });
    HardwareKeyboard.instance.addHandler(_globalKeyboardFilterHook);

    _tableFocusNode.addListener(() {
      if (!_tableFocusNode.hasFocus) _closeTableOverlay();
    });
    _empFocusNode.addListener(() {
      if (!_empFocusNode.hasFocus) _closeEmpOverlay();
    });
  }

  @override
  void dispose() {
    _closeTableOverlay();
    _closeEmpOverlay();
    HardwareKeyboard.instance.removeHandler(_globalKeyboardFilterHook);
    _barcodeController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _itemNameController.dispose();
    _tableInputController.dispose();
    _empInputController.dispose();
    _tableFocusNode.dispose();
    _empFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  bool _isValidTableForDisplay(String tableName) {
    final cleanName = tableName.trim().toUpperCase();
    if (cleanName.isEmpty) return false;

    final cleanDigits = cleanName.replaceAll(RegExp(r'[^\d]'), '');
    final intVal = int.tryParse(cleanDigits);

    if (intVal != null) {
      if (intVal >= 50 && intVal <= 55) return false;
      if (intVal >= 1 && intVal <= 49) return true;
      if (intVal >= 101 && intVal <= 120) return true;
    }
    return true;
  }

  bool _isVipTable(String tableId) {
    final cleanId = tableId.replaceAll(RegExp(r'[^\d]'), '');
    final tableNum = int.tryParse(cleanId) ?? 0;
    return tableNum >= 101 && tableNum <= 120;
  }

  bool _isBarcodeInEditableRange(String rawBarcode) {
    if (rawBarcode.trim().isEmpty) return false;
    final String numericOnly = rawBarcode.replaceAll(RegExp(r'[^\d]'), '');
    final int? numValue = int.tryParse(numericOnly);
    if (numValue != null && numValue >= 175 && numValue <= 230) {
      return true;
    }
    return false;
  }

  void _closeTableOverlay() {
    _tableOverlayEntry?.remove();
    _tableOverlayEntry = null;
  }

  void _closeEmpOverlay() {
    _empOverlayEntry?.remove();
    _empOverlayEntry = null;
  }

  void _selectTableAndAutoRestoreWaiter(String tableId, PosState state) {
    _tableInputController.text = tableId.toUpperCase();
    context.read<PosBloc>().add(SelectTableEvent(tableId.toUpperCase()));

    final activeOrders = state.runningOrders.where((o) {
      final bool matches = o['table_id'].toString().toUpperCase() == tableId.toUpperCase();
      final dynamic rawManual = o['is_manual'];
      final bool isRegular = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');
      return matches && isRegular;
    }).toList();

    if (activeOrders.isNotEmpty) {
      final assignedEmpId = activeOrders.first['employee_id']?.toString().trim() ?? '';
      if (assignedEmpId.isNotEmpty) {
        _empInputController.text = assignedEmpId;
        final int parsedId = int.tryParse(assignedEmpId) ?? 1;
        context.read<PosBloc>().add(SelectEmployeeEvent(parsedId));
      }
    }
  }

  void _executeAbsoluteFormReset() {
    setState(() {
      _tableInputController.clear();
      _empInputController.clear();
      _barcodeController.clear();
      _itemNameController.text = "NO ITEM DETECTED";
      _qtyController.text = "1";
      _priceController.clear();
      _scannedItemCache = null;
      _isRateEditable = false;
    });

    _closeTableOverlay();
    _closeEmpOverlay();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        context.read<PosBloc>().add(SelectTableEvent('ALL'));
        _tableFocusNode.requestFocus();
      }
    });
  }

  bool _globalKeyboardFilterHook(KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool altPressed = HardwareKeyboard.instance.isAltPressed;
      final String pressedKey = event.logicalKey.keyLabel.toUpperCase();

      final state = context.read<PosBloc>().state;
      final shortcuts = state.shortcutsMap;

      final String configuredKotKey = shortcuts['SHORTCUT_KOT'] ?? 'ALT+C';
      if (altPressed && configuredKotKey.contains(pressedKey)) {
        _triggerInstantFoodKOTToken(state);
        _shortcutKeyBuffer = '';
        return true;
      }

      if (RegExp(r'^[0-9A-Z]$').hasMatch(pressedKey) || pressedKey.startsWith('F')) {
        _shortcutKeyBuffer += pressedKey;

        _shortcutBufferTimer?.cancel();
        _shortcutBufferTimer = Timer(const Duration(milliseconds: 1000), () {
          _shortcutKeyBuffer = '';
        });
      }

      if (event.logicalKey == LogicalKeyboardKey.enter && _shortcutKeyBuffer.isNotEmpty) {
        final String input = _shortcutKeyBuffer.trim();
        _shortcutKeyBuffer = '';

        final String focusTableShortcut = shortcuts['SHORTCUT_FOCUS_TABLE'] ?? '555';
        final String billCheckoutShortcut = shortcuts['SHORTCUT_BILL'] ?? '777';
        final String changeTableShortcut = shortcuts['SHORTCUT_CHANGE_TABLE'] ?? '999';

        if (input == focusTableShortcut) {
          _tableFocusNode.requestFocus();
          return true;
        }

        if (input == billCheckoutShortcut) {
          final String? selectedTable = state.selectedTableId;

          if (selectedTable == null || selectedTable.isEmpty || selectedTable == 'ALL') {
            _showSnackBarLocal("PLEASE SELECT A SPECIFIC TABLE FIRST!", Colors.redAccent);
            _tableFocusNode.requestFocus();
            return true;
          }

          final hasRegularOrdersForThisTable = state.runningOrders.any((item) =>
          item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
              (item['is_manual'] == 0 || item['is_manual'] == false || item['is_manual'] == null));

          if (hasRegularOrdersForThisTable) {
            _showCheckoutDialog(context, state);
          } else {
            _showSnackBarLocal("NO ACTIVE REGULAR ORDERS ON TABLE $selectedTable", Colors.amber);
          }
          return true;
        }

        if (input == changeTableShortcut) {
          if (state.selectedTableId != null && state.selectedTableId != 'ALL') {
            _showTableTransferDialog(context, state);
          } else {
            _showSnackBarLocal("SELECT ANY TABLE FIRST", Colors.red);
          }
          return true;
        }
      }
    }
    return false;
  }

  String resolveTargetPrinterName(List<dynamic> printersList, String preferredType) {
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

      if (isActive && targetAddr.isNotEmpty) {
        return targetAddr;
      }
    }

    if (printersList.isNotEmpty) {
      final String firstAddr = (printersList.first['target_address'] ?? '').toString().trim();
      if (firstAddr.isNotEmpty) return firstAddr;
    }

    return "";
  }

  // 🌟 KOT PRINT FUNCTION (FOOD + LIQUOR INCLUDED, UNPRINTED ONLY, CIGARETTE/'K' EXCLUDED)
  void _triggerInstantFoodKOTToken(PosState state) async {
    String currentTargetTable = _tableInputController.text.trim().toUpperCase();
    if (currentTargetTable.isEmpty && state.selectedTableId != null) {
      currentTargetTable = state.selectedTableId!.trim().toUpperCase();
    }

    final String currentWaiterId = _empInputController.text.trim();
    String waiterName = currentWaiterId.isNotEmpty ? "WAITER $currentWaiterId" : "WAITER #1";

    if (currentTargetTable.isEmpty || currentTargetTable == 'ALL') {
      _showSnackBarLocal("Please select a specific Table for KOT!", Colors.amber);
      return;
    }

    List<Map<String, dynamic>> unprintedFoodKOTList = [];
    List<Map<String, dynamic>> unprintedLiquorKOTList = [];
    List<int> unprintedOrderIds = [];

    for (var item in state.runningOrders) {
      final String orderTable = item['table_id']?.toString().trim().toUpperCase() ?? '';
      final String catType = item['category_type']?.toString().toUpperCase().trim() ?? '';
      final String catName = item['category_name']?.toString().toUpperCase().trim() ?? '';
      final String itemName = item['item_name']?.toString().toUpperCase().trim() ?? '';

      final dynamic rawManual = item['is_manual'];
      final bool isRegular = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');

      final dynamic rawPrinted = item['is_printed'];
      bool alreadyPrinted = false;

      if (rawPrinted != null) {
        if (rawPrinted is int) {
          alreadyPrinted = (rawPrinted == 1);
        } else if (rawPrinted is bool) {
          alreadyPrinted = rawPrinted;
        } else if (rawPrinted is String) {
          alreadyPrinted = (rawPrinted == '1' || rawPrinted.toLowerCase() == 'true');
        }
      }

      final bool isCigaretteItem = (catName == 'K' ||
          catName == 'CIG' ||
          catName == 'CA' ||
          catName == 'S' ||
          catName.contains('CIGRATE') ||
          catName.contains('CIGARETTE') ||
          itemName.contains('CIGARETTE'));

      if (orderTable == currentTargetTable && !isCigaretteItem && isRegular && !alreadyPrinted) {
        if (catType == 'LIQUOR' || catType.contains('LIQUOR')) {
          unprintedLiquorKOTList.add(Map<String, dynamic>.from(item));
        } else if (catType == 'FOOD' || catType.contains('FOOD')) {
          unprintedFoodKOTList.add(Map<String, dynamic>.from(item));
        }

        if (item['order_id'] != null) {
          unprintedOrderIds.add(int.parse(item['order_id'].toString()));
        }
      }
    }

    if (unprintedFoodKOTList.isEmpty && unprintedLiquorKOTList.isEmpty) {
      _showSnackBarLocal("⚠️ Table $currentTargetTable: All items already printed to KOT!", Colors.amber);
      return;
    }

    final String resolvedPrinter = await PrinterService.resolvePhysicalTargetPrinter(
      dbPrinters: state.printers,
      preferredType: 'KOT',
    );

    if (resolvedPrinter.isEmpty) {
      _showSnackBarLocal("🔴 NO ONLINE PRINTER CONNECTED! Check Printer USB/Power Cable.", Colors.redAccent);
      return;
    }

    try {
      if (unprintedFoodKOTList.isNotEmpty) {
        await PrinterService.printKitchenTokenSilent(
          tableId: currentTargetTable,
          foodItems: unprintedFoodKOTList,
          waiterId: currentWaiterId.isNotEmpty ? currentWaiterId : "1",
          waiterName: waiterName,
          targetPrinterName: resolvedPrinter,
        );
      }

      if (unprintedLiquorKOTList.isNotEmpty) {
        await PrinterService.printKitchenTokenSilent(
          tableId: currentTargetTable,
          foodItems: unprintedLiquorKOTList,
          waiterId: currentWaiterId.isNotEmpty ? currentWaiterId : "1",
          waiterName: waiterName,
          targetPrinterName: resolvedPrinter,
        );
      }

      context.read<PosBloc>().add(MarkKotPrintedEvent(
        tableId: currentTargetTable,
        orderIds: unprintedOrderIds,
      ));

      setState(() {
        for (var order in state.runningOrders) {
          if (unprintedOrderIds.contains(order['order_id'])) {
            order['is_printed'] = 1;
          }
        }
      });

      int totalPrintedCount = unprintedFoodKOTList.length + unprintedLiquorKOTList.length;
      _showSnackBarLocal("✅ KOT Printed ($totalPrintedCount Items) successfully!", Colors.green);
    } catch (e) {
      _showSnackBarLocal("🔴 KOT Print Failed: $e", Colors.red);
    } finally {
      _executeAbsoluteFormReset();
    }
  }

  void _showSnackBarLocal(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 11)), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosBloc, PosState>(
      listenWhen: (previous, current) => previous.searchStatus != current.searchStatus || previous.status != current.status,
      listener: (context, blocState) {
        if (blocState.status == PosStatus.failure) {
          _showSnackBarLocal(
            blocState.errorMessage.isNotEmpty ? blocState.errorMessage : "Operation Blocked: System Error!",
            Colors.redAccent,
          );
        }

        if (blocState.searchStatus == BarcodeSearchStatus.success && blocState.previewItem != null) {
          final item = blocState.previewItem!;
          _scannedItemCache = Map<String, dynamic>.from(item);

          final String rawBarcode = item['barcode']?.toString() ?? _barcodeController.text.trim();
          final bool isEditable = _isBarcodeInEditableRange(rawBarcode);

          setState(() {
            _itemNameController.text = item['product_name'].toString().toUpperCase();
            _priceController.text = item['sale_price'].toString();
            _qtyController.text = "1";
            _isRateEditable = isEditable;
          });

          if (isEditable) {
            _priceFocusNode.requestFocus();
          } else {
            _qtyFocusNode.requestFocus();
          }
        }

        if (blocState.searchStatus == BarcodeSearchStatus.notFound || blocState.searchStatus == BarcodeSearchStatus.failure) {
          _showSnackBarLocal(blocState.searchErrorMessage ?? "No product found matching barcode entry", Colors.red);

          setState(() {
            _barcodeController.clear();
            _itemNameController.text = "NO ITEM DETECTED";
            _priceController.clear();
            _scannedItemCache = null;
            _isRateEditable = false;
          });

          _barcodeFocusNode.requestFocus();
        }

        if (blocState.status == PosStatus.checkoutSuccess) {
          _executeAbsoluteFormReset();
        }
      },
      builder: (context, blocState) {
        if (blocState.status == PosStatus.initial && blocState.tables.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Column(
            children: [
              _buildRow1BillSummaryHeader(context, blocState),
              _buildRow2TableAndEmpHeader(context, blocState),
              _buildRow3BarcodeQtyAndItemStageLine(context, blocState),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: _buildSplitGridPanel(blocState, 'LIQUOR', const Color(0xFF7C3AED))),
                    VerticalDivider(width: 1, color: Colors.grey.shade300),
                    Expanded(flex: 10, child: _buildSplitGridPanel(blocState, 'FOOD', const Color(0xFFEA580C))),
                    VerticalDivider(width: 1, color: Colors.grey.shade300),
                    Expanded(flex: 3, child: _buildRightFloorTotalGrid(blocState)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow1BillSummaryHeader(BuildContext context, PosState state) {
    final int settledCount = state.settledBillsCount;
    final int pendingCount = state.pendingBillsCount;
    final int currentBillIndex = settledCount + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 3),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'BILL INDEX',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '#$currentBillIndex',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'SETTLED BILLS',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '$settledCount',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'PENDING BILLS',
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: uniformComponentHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF00BCD4)),
              label: const Text(
                "REPRINT BILL",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: () => _showReprintBillDialog(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow2TableAndEmpHeader(BuildContext context, PosState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 1. TABLE INPUT FIELD
          CompositedTransformTarget(
            link: _tableLayerLink,
            child: SizedBox(
              width: 240,
              height: uniformComponentHeight,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && _isTableDropdownOpen && _filteredTablesCache.isNotEmpty) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _tableSelectedIndex = (_tableSelectedIndex + 1) % _filteredTablesCache.length;
                      });
                      _showTableOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _tableSelectedIndex = (_tableSelectedIndex - 1 + _filteredTablesCache.length) % _filteredTablesCache.length;
                      });
                      _showTableOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      final item = _filteredTablesCache[_tableSelectedIndex];
                      final String selectedTableId = item['table_id'].toString().toUpperCase();

                      _selectTableAndAutoRestoreWaiter(selectedTableId, state);
                      _closeTableOverlay();
                      setState(() {
                        _isTableDropdownOpen = false;
                      });
                      _empFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    final raw = _tableInputController.text.trim().toUpperCase();

                    if (raw.isNotEmpty) {
                      if (!_isValidTableForDisplay(raw)) {
                        _showSnackBarLocal("Table $raw is reserved for Excise Liquor Module!", Colors.redAccent);
                        _tableInputController.clear();
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      final bool existsInDb = state.tables.any((t) =>
                      t['table_name'].toString().trim().toUpperCase() == raw ||
                          t['table_id'].toString().trim().toUpperCase() == raw);

                      if (!existsInDb) {
                        _showSnackBarLocal("TABLE '$raw' DOES NOT EXIST IN DATABASE!", Colors.redAccent);
                        _tableInputController.clear();
                        _tableFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      _selectTableAndAutoRestoreWaiter(raw, state);
                      _closeTableOverlay();
                      setState(() {
                        _isTableDropdownOpen = false;
                      });
                      _empFocusNode.requestFocus();
                    } else {
                      _tableFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  focusNode: _tableFocusNode,
                  controller: _tableInputController,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  onTap: () {
                    _isTableDropdownOpen = true;
                    _filteredTablesCache = state.tables.where((t) => _isValidTableForDisplay(t['table_name'].toString())).toList();
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  onChanged: (q) {
                    _isTableDropdownOpen = true;
                    final search = q.trim().toUpperCase();

                    List<dynamic> matchedTables = state.tables.where((t) {
                      final String tName = t['table_name'].toString().trim().toUpperCase();
                      final String tId = t['table_id'].toString().trim().toUpperCase();

                      bool isValid = _isValidTableForDisplay(tName);
                      if (!isValid) return false;

                      if (search.isEmpty) return true;
                      return tName.startsWith(search) || tName.contains(search) || tId.startsWith(search);
                    }).toList();

                    if (search.isNotEmpty) {
                      matchedTables.sort((a, b) {
                        final String aName = a['table_name'].toString().trim().toUpperCase();
                        final String bName = b['table_name'].toString().trim().toUpperCase();

                        if (aName == search) return -1;
                        if (bName == search) return 1;

                        bool aIsDirectSub = RegExp('^' + RegExp.escape(search) + r'[A-Z]+$').hasMatch(aName);
                        bool bIsDirectSub = RegExp('^' + RegExp.escape(search) + r'[A-Z]+$').hasMatch(bName);

                        if (aIsDirectSub && !bIsDirectSub) return -1;
                        if (!aIsDirectSub && bIsDirectSub) return 1;

                        bool aStarts = aName.startsWith(search);
                        bool bStarts = bName.startsWith(search);
                        if (aStarts && !bStarts) return -1;
                        if (!aStarts && bStarts) return 1;

                        if (aName.length != bName.length) {
                          return aName.length.compareTo(bName.length);
                        }

                        return aName.compareTo(bName);
                      });
                    }

                    _filteredTablesCache = matchedTables;
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  decoration: InputDecoration(
                    labelText: "ENTER TABLE ID",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _tableFocusNode.hasFocus ? const Color(0x1A2563EB) : uniformFieldBg,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. WAITER INPUT FIELD
          CompositedTransformTarget(
            link: _empLayerLink,
            child: SizedBox(
              width: 240,
              height: uniformComponentHeight,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && _isEmpDropdownOpen && _filteredEmpCache.isNotEmpty) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      setState(() {
                        _empSelectedIndex = (_empSelectedIndex + 1) % _filteredEmpCache.length;
                      });
                      _showEmpOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() {
                        _empSelectedIndex = (_empSelectedIndex - 1 + _filteredEmpCache.length) % _filteredEmpCache.length;
                      });
                      _showEmpOverlay();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      final selectedIdStr = _filteredEmpCache[_empSelectedIndex];
                      final int empId = int.tryParse(selectedIdStr) ?? 1;

                      _empInputController.text = selectedIdStr;
                      context.read<PosBloc>().add(SelectEmployeeEvent(empId));
                      _closeEmpOverlay();
                      setState(() {
                        _isEmpDropdownOpen = false;
                      });
                      _barcodeFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    final raw = _empInputController.text.trim();
                    if (raw.isNotEmpty) {
                      final bool existsInList = _staticWaitersList.contains(raw);

                      if (!existsInList) {
                        _showSnackBarLocal("WAITER ID MUST BE BETWEEN 1 TO 10!", Colors.redAccent);
                        _empInputController.clear();
                        _empFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }

                      final int empId = int.tryParse(raw) ?? 1;

                      context.read<PosBloc>().add(SelectEmployeeEvent(empId));
                      _closeEmpOverlay();
                      setState(() {
                        _isEmpDropdownOpen = false;
                      });
                      _barcodeFocusNode.requestFocus();
                    } else {
                      _empFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  focusNode: _empFocusNode,
                  controller: _empInputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  onTap: () {
                    _isEmpDropdownOpen = true;
                    _filteredEmpCache = List.from(_staticWaitersList);
                    _empSelectedIndex = 0;
                    _showEmpOverlay();
                  },
                  onChanged: (q) {
                    _isEmpDropdownOpen = true;
                    _filteredEmpCache = _staticWaitersList.where((id) => id.contains(q.trim())).toList();
                    _empSelectedIndex = 0;
                    _showEmpOverlay();
                  },
                  decoration: InputDecoration(
                    labelText: "ENTER WAITER ID (1-10)",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _empFocusNode.hasFocus ? const Color(0x1A2563EB) : uniformFieldBg,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            height: uniformComponentHeight,
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.add_box_rounded, color: Colors.orange, size: 40),
              onPressed: () => _showAddTableDialog(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow3BarcodeQtyAndItemStageLine(BuildContext context, PosState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 6),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            height: uniformComponentHeight,
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onSubmitted: (val) {
                final String input = val.trim().toUpperCase();
                if (input.isEmpty) {
                  _barcodeFocusNode.requestFocus();
                  return;
                }

                final shortcuts = context.read<PosBloc>().state.shortcutsMap;

                final String focusTableShortcut = shortcuts['SHORTCUT_FOCUS_TABLE'] ?? '555';
                final String billCheckoutShortcut = shortcuts['SHORTCUT_BILL'] ?? '777';
                final String changeTableShortcut = shortcuts['SHORTCUT_CHANGE_TABLE'] ?? '999';

                if (input == focusTableShortcut) {
                  _barcodeController.clear();
                  _tableFocusNode.requestFocus();
                  return;
                }

                if (input == billCheckoutShortcut) {
                  _barcodeController.clear();
                  final state = context.read<PosBloc>().state;
                  final String? selectedTable = state.selectedTableId;

                  if (selectedTable == null || selectedTable.isEmpty || selectedTable == 'ALL') {
                    _showSnackBarLocal("PLEASE SELECT A SPECIFIC TABLE FIRST!", Colors.redAccent);
                    _tableFocusNode.requestFocus();
                    return;
                  }

                  final hasRegularOrdersForThisTable = state.runningOrders.any((item) =>
                  item['table_id'].toString().toUpperCase() == selectedTable.toUpperCase() &&
                      (item['is_manual'] == 0 || item['is_manual'] == false || item['is_manual'] == null));

                  if (hasRegularOrdersForThisTable) {
                    _showCheckoutDialog(context, state);
                  } else {
                    _showSnackBarLocal("NO ACTIVE REGULAR ORDERS ON TABLE $selectedTable", Colors.amber);
                  }
                  return;
                }

                if (input == changeTableShortcut) {
                  _barcodeController.clear();
                  final state = context.read<PosBloc>().state;
                  if (state.selectedTableId != null && state.selectedTableId != 'ALL') {
                    _showTableTransferDialog(context, state);
                  } else {
                    _showSnackBarLocal("SELECT ANY TABLE FIRST", Colors.red);
                  }
                  return;
                }

                context.read<PosBloc>().add(ScanBarcodeEvent(input));
              },
              decoration: const InputDecoration(
                labelText: "BARCODE",
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.qr_code, size: 16),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 80,
            height: uniformComponentHeight,
            child: TextField(
              controller: _qtyController,
              focusNode: _qtyFocusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onSubmitted: (val) {
                if (val.trim().isEmpty) {
                  _barcodeFocusNode.requestFocus();
                  return;
                }

                final String currentTable = _tableInputController.text.trim().toUpperCase();
                if (currentTable.isEmpty || _empInputController.text.trim().isEmpty) {
                  _showSnackBarLocal("Please input Table ID and Waiter Identity first!", Colors.redAccent);
                  if (currentTable.isEmpty) {
                    _tableFocusNode.requestFocus();
                  } else {
                    _empFocusNode.requestFocus();
                  }
                  return;
                }

                final targetItem = _scannedItemCache ?? blocStatePreviewItem(context);

                if (targetItem != null) {
                  int countQty = int.tryParse(val.trim()) ?? 1;
                  double? customRate = double.tryParse(_priceController.text.trim());

                  context.read<PosBloc>().add(AddItemToOrderEvent(countQty, customPrice: _isRateEditable ? customRate : null));

                  setState(() {
                    _barcodeController.clear();
                    _itemNameController.text = "NO ITEM DETECTED";
                    _qtyController.text = "1";
                    _priceController.clear();
                    _isRateEditable = false;
                  });

                  Future.delayed(const Duration(milliseconds: 50), () {
                    _scannedItemCache = null;
                    context.read<PosBloc>().add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
                    _barcodeFocusNode.requestFocus();
                  });
                } else {
                  _barcodeFocusNode.requestFocus();
                }
              },
              decoration: const InputDecoration(
                labelText: "QTY",
                labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            height: uniformComponentHeight,
            child: TextField(
              readOnly: false,
              controller: _priceController,
              focusNode: _priceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              onSubmitted: (val) {
                final String currentTable = _tableInputController.text.trim().toUpperCase();
                if (currentTable.isEmpty || _empInputController.text.trim().isEmpty) {
                  _showSnackBarLocal("Please input Table ID and Waiter Identity first!", Colors.redAccent);
                  if (currentTable.isEmpty) {
                    _tableFocusNode.requestFocus();
                  } else {
                    _empFocusNode.requestFocus();
                  }
                  return;
                }

                final targetItem = _scannedItemCache ?? blocStatePreviewItem(context);

                if (targetItem != null) {
                  int countQty = int.tryParse(_qtyController.text.trim()) ?? 1;
                  double? customRate = double.tryParse(_priceController.text.trim());

                  context.read<PosBloc>().add(AddItemToOrderEvent(countQty, customPrice: customRate));

                  setState(() {
                    _barcodeController.clear();
                    _itemNameController.text = "NO ITEM DETECTED";
                    _qtyController.text = "1";
                    _priceController.clear();
                    _isRateEditable = true;
                  });

                  Future.delayed(const Duration(milliseconds: 50), () {
                    _scannedItemCache = null;
                    context.read<PosBloc>().add(SelectTableEvent(state.selectedTableId ?? 'ALL'));
                    _barcodeFocusNode.requestFocus();
                  });
                } else {
                  _barcodeFocusNode.requestFocus();
                }
              },
              decoration: InputDecoration(
                labelText: "RATE",
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                prefixText: "₹",
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: Colors.amber.shade50,
              ),
            ),
          ),

          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: uniformComponentHeight,
              width: 200,
              child: TextField(
                controller: _itemNameController,
                readOnly: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                decoration: const InputDecoration(
                  labelText: "ITEM NAME",
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: uniformFieldBg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTableOverlay() {
    _closeTableOverlay();
    _tableOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: _tableLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 180.0,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade600, width: 2.0), color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: _filteredTablesCache.isEmpty
                  ? const Center(child: Text("No records match", style: TextStyle(fontSize: 11)))
                  : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredTablesCache.length,
                itemBuilder: (ctx, idx) {
                  final t = _filteredTablesCache[idx];
                  final isSelected = idx == _tableSelectedIndex;
                  return Container(
                    height: 36,
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      t['table_name'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tableOverlayEntry!);
  }

  void _showEmpOverlay() {
    _closeEmpOverlay();
    _empOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: _empLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 180.0,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade600, width: 2.0), color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: _filteredEmpCache.isEmpty
                  ? const Center(child: Text("No IDs found", style: TextStyle(fontSize: 11)))
                  : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredEmpCache.length,
                itemBuilder: (ctx, idx) {
                  final waiterId = _filteredEmpCache[idx];
                  final isSelected = idx == _empSelectedIndex;

                  return Container(
                    height: 36,
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      "WAITER ID: $waiterId",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_empOverlayEntry!);
  }

  Map<String, dynamic>? blocStatePreviewItem(BuildContext ctx) {
    try {
      return context.read<PosBloc>().state.previewItem;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSplitGridPanel(PosState state, String currentTargetFilterType, Color headerBarColor) {
    final bool isVip = _isVipTable(state.selectedTableId ?? '');

    final displayItems = state.runningOrders.where((item) {
      final String itemDirectType = item['category_type']?.toString().toUpperCase() ?? '';
      final bool matchesSelectedTable = state.selectedTableId != null && item['table_id'].toString().toUpperCase() == state.selectedTableId!.toUpperCase();

      final dynamic rawManual = item['is_manual'];
      final bool isRegularItem = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');

      return itemDirectType == currentTargetFilterType && matchesSelectedTable && isRegularItem;
    }).toList();

    double sectionTotal = displayItems.fold(0.0, (sum, item) {
      double itemAmt = double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
      if (itemAmt == 0.0) {
        double itemPrice = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        int itemQty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        itemAmt = itemPrice * itemQty;
      }
      return sum + itemAmt;
    });

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          Container(
            color: headerBarColor,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "$currentTargetFilterType STREAM",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                    ),
                    if (currentTargetFilterType == 'FOOD' && isVip) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3)),
                        child: const Text(
                          "VIP +5%",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8),
                        ),
                      ),
                    ]
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "TOTAL: ₹${sectionTotal.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("S.N", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("TBL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("QTY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text("RATE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text("TOTAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text("DEL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),

          Expanded(
            child: displayItems.isEmpty
                ? Center(child: Text("No items active on table ${state.selectedTableId ?? ''} under $currentTargetFilterType.", style: const TextStyle(color: Colors.grey, fontSize: 10)))
                : ListView.separated(
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => Divider(height: 0.5, color: Colors.grey.shade200),
              itemBuilder: (ctx, i) {
                final order = displayItems[i];
                double unitPrice = double.tryParse(order['price']?.toString() ?? '0.0') ?? 0.0;
                int qty = int.tryParse(order['qty']?.toString() ?? '1') ?? 1;
                double lineTotal = double.tryParse(order['amount']?.toString() ?? '0.0') ?? (unitPrice * qty);
                if (lineTotal == 0.0) lineTotal = unitPrice * qty;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text("${i + 1}", style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text(order['table_id'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                      Expanded(flex: 5, child: Text(order['item_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text(qty.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("₹${unitPrice.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
                      Expanded(flex: 2, child: Text("₹${lineTotal.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueAccent))),
                      Expanded(
                        flex: 1,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_forever, color: Colors.red, size: 16),
                          onPressed: () {
                            context.read<PosBloc>().add(RemoveOrderItemEvent(order['order_id'] as int));
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReprintBillDialog(BuildContext parentContext, PosState state) {
    final TextEditingController billNoController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print, color: Color(0xFF00BCD4), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "REPRINT SETTLED BILL",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ENTER SETTLED BILL NUMBER",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: billNoController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      cursorColor: const Color(0xFF00BCD4),
                      decoration: InputDecoration(
                        hintText: "e.g., 1, 2, 10...",
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF475569)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onSubmitted: (_) {
                        _triggerReprint(parentContext, ctx, billNoController, setDialogState, isLoading);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        icon: isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print, size: 14, color: Colors.white),
                        label: Text(
                          isLoading ? "FETCHING..." : "PRINT DUPLICATE",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isLoading
                            ? null
                            : () => _triggerReprint(parentContext, ctx, billNoController, setDialogState, isLoading),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _triggerReprint(
      BuildContext parentContext,
      BuildContext dialogContext,
      TextEditingController billNoController,
      StateSetter setDialogState,
      bool isLoading,
      ) {
    final String billNo = billNoController.text.trim();
    if (billNo.isEmpty) {
      _showSnackBarLocal("Please enter a valid Bill Number!", Colors.redAccent);
      return;
    }

    setDialogState(() => isLoading = true);

    parentContext.read<PosBloc>().add(
      ReprintBillEvent(
        billNo: billNo,
        billType: 'REGULAR',
        onResult: (isSuccess, message) {
          setDialogState(() => isLoading = false);
          if (isSuccess) {
            if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
            _showSnackBarLocal(message, Colors.green);
          } else {
            _showSnackBarLocal(message, Colors.orange);
          }
        },
      ),
    );
  }

  Widget _buildRightFloorTotalGrid(PosState state) {
    return SizedBox(
      width: 200,
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0F172A),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: const Text(
                "LIVE COUNTER MAP",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            Expanded(
              child: Builder(
                builder: (context) {
                  final activeSummaryList = state.tables
                      .where((tableElement) => _isValidTableForDisplay(tableElement['table_name'].toString()))
                      .map((tableElement) {
                    final String tableId = tableElement['table_id'].toString();
                    final bool isVip = _isVipTable(tableId);

                    double foodSubtotal = 0.0;
                    double liquorSubtotal = 0.0;

                    for (var element in state.runningOrders) {
                      final dynamic rawManual = element['is_manual'];
                      final bool isRegularItem = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');

                      if (element['table_id'].toString().toUpperCase() == tableId.toUpperCase() && isRegularItem) {
                        double itemAmt = double.tryParse(element['amount']?.toString() ?? '0.0') ?? 0.0;
                        if (itemAmt == 0.0) {
                          double itemPrice = double.tryParse(element['price']?.toString() ?? '0.0') ?? 0.0;
                          int itemQty = int.tryParse(element['qty']?.toString() ?? '1') ?? 1;
                          itemAmt = itemPrice * itemQty;
                        }

                        String catType = element['category_type']?.toString().toUpperCase() ?? '';
                        if (catType == 'LIQUOR') {
                          liquorSubtotal += itemAmt;
                        } else {
                          foodSubtotal += itemAmt;
                        }
                      }
                    }

                    double vipFoodSurcharge = isVip ? (foodSubtotal * 0.05) : 0.0;
                    double cumulativeTableOutstandingTotal = (foodSubtotal + vipFoodSurcharge) + liquorSubtotal;

                    return {
                      'table_name': tableElement['table_name'].toString(),
                      'table_id': tableId,
                      'total': cumulativeTableOutstandingTotal,
                      'is_vip': isVip,
                    };
                  })
                      .where((element) => (element['total'] as double) > 0.0)
                      .toList();

                  if (activeSummaryList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                          SizedBox(height: 4),
                          Text(
                            "ALL TABLES\nCLEAR",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: activeSummaryList.length,
                    itemBuilder: (ctx, index) {
                      final node = activeSummaryList[index];
                      final bool isVipNode = node['is_vip'] as bool;
                      final String tableId = node['table_id'].toString();
                      final String tableName = node['table_name'].toString().toUpperCase();
                      final double totalAmt = node['total'] as double;

                      final bool isSelectedTable = state.selectedTableId?.toUpperCase() == tableId.toUpperCase();

                      return InkWell(
                        onTap: () {
                          _selectTableAndAutoRestoreWaiter(tableId, state);
                          _barcodeFocusNode.requestFocus();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelectedTable ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelectedTable
                                  ? const Color(0xFF2563EB)
                                  : (isVipNode ? Colors.amber.shade700 : const Color(0xFFCBD5E1)),
                              width: isSelectedTable || isVipNode ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chair_alt_rounded,
                                      size: 13,
                                      color: isVipNode ? Colors.amber.shade800 : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        tableName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: isVipNode ? Colors.amber.shade900 : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (isVipNode) ...[
                                      const SizedBox(width: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          "VIP",
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  "₹${totalAmt.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext parentContext) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 24,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.table_restaurant_rounded, color: Color(0xFF00BCD4), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "PROVISION NEW TABLE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ASSIGN UNIQUE IDENTIFIER",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        cursorColor: const Color(0xFF00BCD4),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: "e.g., TABLE 4B, VIP-1",
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.normal),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF475569), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            if (!_isValidTableForDisplay(val.trim().toUpperCase())) {
                              _showSnackBarLocal("Table ID 50-55 is reserved for Excise Module!", Colors.redAccent);
                              return;
                            }
                            parentContext.read<PosBloc>().add(CreateTableEvent(tableId: val.trim().toUpperCase(), tableName: val.trim().toUpperCase()));
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          "CANCEL",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isNotEmpty) {
                            if (!_isValidTableForDisplay(nameCtrl.text.trim().toUpperCase())) {
                              _showSnackBarLocal("Table ID 50-55 is reserved for Excise Module!", Colors.redAccent);
                              return;
                            }
                            parentContext.read<PosBloc>().add(CreateTableEvent(tableId: nameCtrl.text.trim().toUpperCase(), tableName: nameCtrl.text.trim().toUpperCase()));
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          "CONFIRM DISPATCH",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext parentContext, PosState state) {
    final mobileCtrl = TextEditingController();
    final FocusNode dialogFocusNode = FocusNode();

    final String currentTableId = state.selectedTableId ?? 'WALK-IN';
    final bool isVip = _isVipTable(currentTableId);

    List<Map<String, dynamic>> foodItems = [];
    List<Map<String, dynamic>> liquorItems = [];

    final currentTableRunningOrders = state.runningOrders.where((order) {
      final bool matchesTable = order['table_id'].toString().toUpperCase() == currentTableId.toUpperCase();
      final dynamic rawManual = order['is_manual'];
      final bool isRegularItem = (rawManual == 0 || rawManual == false || rawManual == null || rawManual.toString() == '0');
      return matchesTable && isRegularItem;
    }).toList();

    for (var order in currentTableRunningOrders) {
      String catType = order['category_type']?.toString().toUpperCase() ?? 'FOOD';
      if (catType == 'LIQUOR') {
        liquorItems.add(order);
      } else {
        foodItems.add(order);
      }
    }

    double foodSubtotal = foodItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
    double liquorTotal = liquorItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
    double vipSurcharge = isVip ? (foodSubtotal * 0.05) : 0.0;
    double grandTotal = foodSubtotal + vipSurcharge + liquorTotal;

    void executeCheckout(BuildContext dialogCtx, bool shouldPrint) {
      if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);

      // 🌟 DB-FIRST EVENT DISPATCH (Print will happen with confirmed DB Bill No)
      parentContext.read<PosBloc>().add(
        CheckoutTableEvent(
          mobileNumber: mobileCtrl.text.trim(),
          shouldPrint: shouldPrint,
          onResult: (isSuccess, message) {
            _showSnackBarLocal(message, isSuccess ? Colors.green : Colors.red);
          },
        ),
      );
    }

    showDialog(
      context: parentContext,
      builder: (ctx) => Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            executeCheckout(ctx, true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: const Color(0xFF0F172A),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text("Checkout Settle: Table $currentTableId ${isVip ? '(VIP Table - +5%)' : ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: mobileCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(labelText: "Customer Mobile (Optional)", prefixIcon: Icon(Icons.phone, size: 12), border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                        child: ListView(
                          padding: const EdgeInsets.all(6),
                          children: [
                            if (foodItems.isNotEmpty) ...[
                              const Text("FOOD ITEMS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ...foodItems.map((item) => Row(children: [
                                Expanded(flex: 3, child: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("x${item['qty']}", style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("₹${item['amount']}", style: const TextStyle(fontSize: 9), textAlign: TextAlign.right))
                              ])),
                            ],
                            if (liquorItems.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Text("LIQUOR ITEMS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                              ...liquorItems.map((item) => Row(children: [
                                Expanded(flex: 3, child: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("x${item['qty']}", style: const TextStyle(fontSize: 9))),
                                Expanded(flex: 1, child: Text("₹${item['amount']}", style: const TextStyle(fontSize: 9), textAlign: TextAlign.right))
                              ])),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFFF8FAFC),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("FOOD & LIQUOR SUBTOTAL:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text("₹${(foodSubtotal + liquorTotal).toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (isVip && vipSurcharge > 0) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("VIP FOOD SURCHARGE (+5%):", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w900)),
                                  Text("₹${vipSurcharge.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                            const Divider(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("GRAND TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text("₹${grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 15))
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontSize: 11))),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => executeCheckout(ctx, true),
                            icon: const Icon(Icons.print, size: 12, color: Colors.white),
                            label: const Text("SETTLE & PRINT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                          )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showTableTransferDialog(BuildContext context, PosState state) {
    final TextEditingController searchCtrl = TextEditingController();
    List filteredTables = state.tables.where((t) => _isValidTableForDisplay(t['table_name'].toString())).toList();
    int selectedIndex = 0;
    final posBloc = context.read<PosBloc>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00BCD4), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "TRANSFER TABLE: ${state.selectedTableId}",
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setDialogState(() {
                            if (selectedIndex < filteredTables.length - 1) {
                              selectedIndex++;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setDialogState(() {
                            if (selectedIndex > 0) {
                              selectedIndex--;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (filteredTables.isNotEmpty && state.selectedTableId != null) {
                            final targetTableId = filteredTables[selectedIndex]['table_id'].toString();
                            posBloc.add(TransferTableEvent(
                              oldTableId: state.selectedTableId!,
                              newTableId: targetTableId,
                            ));
                            Navigator.pop(ctx);
                          }
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      cursorColor: const Color(0xFF00BCD4),
                      decoration: InputDecoration(
                        hintText: "Type to Search Table (Use Arrow keys & Enter)",
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00BCD4), size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF475569)), borderRadius: BorderRadius.circular(4)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5), borderRadius: BorderRadius.circular(4)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filteredTables = state.tables
                              .where((t) => _isValidTableForDisplay(t['table_name'].toString()) && t['table_name'].toString().toUpperCase().contains(val.toUpperCase()))
                              .toList();
                          selectedIndex = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "AVAILABLE TARGET TABLES",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: filteredTables.isEmpty
                        ? const Center(child: Text("No Tables Found", style: TextStyle(color: Colors.grey, fontSize: 11)))
                        : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filteredTables.length,
                      itemBuilder: (c, i) {
                        final bool isSelected = i == selectedIndex;
                        return Container(
                          color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              filteredTables[i]['table_name'].toString().toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.white, size: 14) : null,
                            onTap: () {
                              posBloc.add(TransferTableEvent(
                                oldTableId: state.selectedTableId!,
                                newTableId: filteredTables[i]['table_id'].toString(),
                              ));
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Align(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CLOSE (ESC)", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}