
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';
import '../widgets/print_service.dart';

class ManualLiquorBillingPage extends StatelessWidget {
  const ManualLiquorBillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PosBloc()..add(LoadInitialDataEvent()),
      child: const ManualLiquorBillingView(),
    );
  }
}

class ManualLiquorBillingView extends StatefulWidget {
  const ManualLiquorBillingView({super.key});

  @override
  State<ManualLiquorBillingView> createState() => _ManualLiquorBillingViewState();
}

class _ManualLiquorBillingViewState extends State<ManualLiquorBillingView> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController(text: 'NO ITEM DETECTED');
  final TextEditingController _tableInputController = TextEditingController();

  DateTime _selectedManualDate = DateTime.now();
  Map<String, dynamic>? _scannedItemCache;

  List<dynamic> _filteredTablesCache = [];
  OverlayEntry? _tableOverlayEntry;

  bool _isTableDropdownOpen = false;
  int _tableSelectedIndex = 0;
  bool _isRateEditable = false;

  String _shortcutKeyBuffer = '';
  Timer? _shortcutBufferTimer;

  final FocusNode _tableFocusNode = FocusNode();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  final LayerLink _tableLayerLink = LayerLink();

  static const TextStyle cellTextBold = TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A));
  static const TextStyle cellTextNormal = TextStyle(fontSize: 11.0, color: Color(0xFF334155), fontWeight: FontWeight.w600);

  // ⚡ EXECUTIVE POS UNIFORM COMPONENT HEIGHT (50.0 Matching POS Screen)
  static const double uniformComponentHeight = 50.0;
  static const Color uniformFieldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableFocusNode.requestFocus();
      _ensureManualExciseTablesExist();
    });
    HardwareKeyboard.instance.addHandler(_globalKeyboardFilterHook);

    _tableFocusNode.addListener(() {
      if (!_tableFocusNode.hasFocus) _closeTableOverlay();
    });
  }

  void _ensureManualExciseTablesExist() {
    final bloc = context.read<PosBloc>();
    final existingTables = bloc.state.tables;

    for (int i = 50; i <= 55; i++) {
      final String tId = i.toString();
      final bool exists = existingTables.any((t) =>
      t['table_id'].toString().trim() == tId ||
          t['table_name'].toString().trim() == tId
      );
      if (!exists) {
        bloc.add(CreateTableEvent(tableId: tId, tableName: tId));
      }
    }
  }

  void _closeTableOverlay() {
    if (_tableOverlayEntry != null) {
      _tableOverlayEntry?.remove();
      _tableOverlayEntry = null;
    }
  }

  @override
  void dispose() {
    _shortcutBufferTimer?.cancel();
    _closeTableOverlay();
    HardwareKeyboard.instance.removeHandler(_globalKeyboardFilterHook);
    _barcodeController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _itemNameController.dispose();
    _tableInputController.dispose();
    _tableFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // ⚡ STRICTLY ALLOWS ONLY TABLES 50 TO 55 FOR EXCISE LIQUOR
  bool _isValidTableForDisplay(dynamic tableName) {
    if (tableName == null) return false;
    final cleanName = tableName.toString().trim().toUpperCase();
    if (cleanName.isEmpty) return false;

    final cleanDigits = cleanName.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) return false;

    final intVal = int.tryParse(cleanDigits) ?? 0;
    return intVal >= 50 && intVal <= 55;
  }

  bool _isBarcodeInEditableRange(String rawBarcode) {
    if (rawBarcode.trim().isEmpty) return false;
    final String numericOnly = rawBarcode.replaceAll(RegExp(r'[^\d]'), '');
    final int? numValue = int.tryParse(numericOnly);
    return numValue != null && numValue >= 175 && numValue <= 226;
  }

  void _executeKotPunchPipeline() {
    final String currentTable = _tableInputController.text.trim().toUpperCase();

    if (currentTable.isEmpty) {
      _showSnackBarLocal("KOT Blocked: Table ID required first!", Colors.redAccent);
      _tableFocusNode.requestFocus();
      return;
    }

    final targetItem = _scannedItemCache ?? blocStatePreviewItem(context);

    if (targetItem != null) {
      int countQty = int.tryParse(_qtyController.text.trim()) ?? 1;
      double? customRate = double.tryParse(_priceController.text.trim());

      context.read<PosBloc>().add(
        AddItemToOrderEvent(
          countQty,
          customPrice: customRate,
          isManual: true,
        ),
      );

      _clearInputBuffer();

      Future.delayed(const Duration(milliseconds: 50), () {
        context.read<PosBloc>().add(SelectTableEvent(context.read<PosBloc>().state.selectedTableId ?? 'ALL'));
        _barcodeFocusNode.requestFocus();
      });
    } else {
      _showSnackBarLocal("KOT Skipped: No product item scanned or cached!", Colors.amber);
      _barcodeFocusNode.requestFocus();
    }
  }

  bool _globalKeyboardFilterHook(KeyEvent event) {
    if (event is KeyDownEvent) {
      final String pressedKey = event.logicalKey.keyLabel.toUpperCase();
      final state = context.read<PosBloc>().state;
      final shortcuts = state.shortcutsMap;

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

        if (input == focusTableShortcut) {
          _tableFocusNode.requestFocus();
          return true;
        }

        if (input == billCheckoutShortcut) {
          final String currentTable = _tableInputController.text.trim().toUpperCase();

          if (currentTable.isEmpty) {
            _showSnackBarLocal("PLEASE SELECT A TABLE FIRST!", Colors.redAccent);
            _tableFocusNode.requestFocus();
            return true;
          }

          final hasActiveOrders = state.runningOrders.any((item) {
            final String itemTable = item['table_id'].toString().toUpperCase();
            final String itemType = item['category_type']?.toString().toUpperCase() ?? '';
            final bool isManual = (item['is_manual'] == 1 || item['is_manual'] == true);

            return itemTable == currentTable && isManual && itemType == 'LIQUOR';
          });

          if (hasActiveOrders) {
            _showCheckoutDialog(context, state);
          } else {
            _showSnackBarLocal("NO ACTIVE MANUAL LIQUOR ORDERS ON TABLE $currentTable", Colors.amber);
          }
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic>? blocStatePreviewItem(BuildContext ctx) {
    try {
      return context.read<PosBloc>().state.previewItem;
    } catch (_) {
      return null;
    }
  }

  void _showSnackBarLocal(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 11)), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  void _clearInputBuffer() {
    setState(() {
      _barcodeController.clear();
      _itemNameController.text = "NO ITEM DETECTED";
      _priceController.clear();
      _qtyController.text = "1";
      _scannedItemCache = null;
      _isRateEditable = false;
    });
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _pickManualAuditDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedManualDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: Color(0xFF00BCD4),
                onPrimary: Colors.white,
                surface: Color(0xFF0F172A),
                onSurface: Colors.white
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedManualDate) {
      setState(() {
        _selectedManualDate = picked;
      });
      _showSnackBarLocal("Audit timeline locked: ${DateFormat('dd-MM-yyyy').format(picked)}", Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosBloc, PosState>(
      listenWhen: (previous, current) => previous.searchStatus != current.searchStatus || previous.status != current.status,
      listener: (context, blocState) {
        if (blocState.status == PosStatus.failure) {
          _showSnackBarLocal(
            blocState.errorMessage.isNotEmpty ? blocState.errorMessage : "Operation Blocked: Conflict or System Error!",
            Colors.redAccent,
          );
          _barcodeFocusNode.requestFocus();
        }

        if (blocState.searchStatus == BarcodeSearchStatus.success && blocState.previewItem != null) {
          final item = blocState.previewItem!;
          final String rawCatType = item['category_type']?.toString().toUpperCase().trim() ?? '';
          final String itemCatType = rawCatType.isEmpty ? 'LIQUOR' : rawCatType;

          if (itemCatType != 'LIQUOR') {
            _showSnackBarLocal("SKIPPED: Barcode belongs to FOOD category.", Colors.redAccent);
            _clearInputBuffer();
            return;
          }

          _scannedItemCache = Map<String, dynamic>.from(item);
          final String rawBarcode = item['barcode']?.toString() ?? _barcodeController.text.trim();
          final bool isEditable = _isBarcodeInEditableRange(rawBarcode);

          setState(() {
            _itemNameController.text = item['product_name'].toString().toUpperCase();
            final dynamic rawMPrice = item['m_price'];
            _priceController.text = (rawMPrice != null && double.parse(rawMPrice.toString()) > 0)
                ? rawMPrice.toString()
                : item['sale_price'].toString();
            _qtyController.text = "1";
            _isRateEditable = isEditable;
          });

          if (_isRateEditable) {
            _priceFocusNode.requestFocus();
          } else {
            _qtyFocusNode.requestFocus();
          }
        }

        if (blocState.searchStatus == BarcodeSearchStatus.notFound || blocState.searchStatus == BarcodeSearchStatus.failure) {
          _showSnackBarLocal(blocState.searchErrorMessage ?? "No product found matching barcode entry", Colors.red);
          _clearInputBuffer();
        }

        if (blocState.status == PosStatus.checkoutSuccess) {
          _tableInputController.clear();
          _clearInputBuffer();
          _barcodeFocusNode.requestFocus();
          context.read<PosBloc>().add(SelectTableEvent('ALL'));
        }
      },
      builder: (context, blocState) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text("EXCISE LIQUOR MANUAL BILLING", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildRow1Header(context, blocState),
              _buildRow2TableHeader(context, blocState),
              _buildRow3BarcodeQtyAndItemStageLine(context, blocState),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 20, child: _buildSplitGridPanel(blocState, 'LIQUOR', const Color(0xFF7C3AED))),
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

  // 🌟 ROW 1: HEADER WITH REPRINT BILL BUTTON (Matching POS)
  Widget _buildRow1Header(BuildContext context, PosState state) {
    final String auditDateDisplay = DateFormat('dd-MM-yyyy').format(_selectedManualDate);
    final int settledCount = state.settledBillsCount;
    final int pendingCount = state.pendingBillsCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 3),
      color: Colors.white,
      child: Row(
        children: [
          InkWell(
            onTap: () => _pickManualAuditDate(context),
            child: Container(
              height: uniformComponentHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF0F172A)
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: Color(0xFF00BCD4), size: 14),
                  const SizedBox(width: 6),
                  Text("AUDIT DATE: $auditDateDisplay", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'SETTLED',
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              ),
              child: Text('$settledCount', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            height: uniformComponentHeight,
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'PENDING',
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              ),
              child: Text('$pendingCount', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),

          // 🌟 1) REPRINT BILL BUTTON ADDED
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

  // 🌟 ROW 2: TABLE INPUT WITH BIG & BOLD FONT SIZE 25 (Matching POS Screen)
  Widget _buildRow2TableHeader(BuildContext context, PosState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
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
                      final rawTable = item['table_name'].toString().toUpperCase();
                      _validateAndSelectTable(rawTable, state);
                      return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                    final rawTable = _tableInputController.text.trim().toUpperCase();
                    if (rawTable.isNotEmpty) {
                      _validateAndSelectTable(rawTable, state);
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
                  textCapitalization: TextCapitalization.characters,
                  // 🌟 2) BOLD & BIGGER FONT SIZE 25 ADDED
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  onTap: () {
                    _isTableDropdownOpen = true;
                    _filteredTablesCache = state.tables.where((t) => _isValidTableForDisplay(t['table_name'])).toList();
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  onChanged: (q) {
                    _isTableDropdownOpen = true;
                    final search = q.trim().toUpperCase();

                    List<dynamic> matched = state.tables.where((t) {
                      final String tName = t['table_name'].toString().trim().toUpperCase();
                      bool isValid = _isValidTableForDisplay(tName);
                      if (!isValid) return false;
                      if (search.isEmpty) return true;
                      return tName.startsWith(search) || tName.contains(search);
                    }).toList();

                    if (search.isNotEmpty) {
                      matched.sort((a, b) {
                        final String aName = a['table_name'].toString().trim().toUpperCase();
                        final String bName = b['table_name'].toString().trim().toUpperCase();
                        if (aName == search) return -1;
                        if (bName == search) return 1;
                        return aName.compareTo(bName);
                      });
                    }

                    _filteredTablesCache = matched;
                    _tableSelectedIndex = 0;
                    _showTableOverlay();
                  },
                  decoration: InputDecoration(
                    labelText: "ENTER TABLE ID (50-55)",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    filled: true,
                    fillColor: _tableFocusNode.hasFocus ? const Color(0x1A2563EB) : uniformFieldBg,
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

                if (input == focusTableShortcut) {
                  _barcodeController.clear();
                  _tableFocusNode.requestFocus();
                  return;
                }

                if (input == billCheckoutShortcut) {
                  _barcodeController.clear();
                  final String currentTable = _tableInputController.text.trim().toUpperCase();

                  if (currentTable.isEmpty) {
                    _showSnackBarLocal("PLEASE SELECT A TABLE FIRST!", Colors.redAccent);
                    _tableFocusNode.requestFocus();
                    return;
                  }

                  final hasActiveOrders = state.runningOrders.any((item) {
                    final String itemTable = item['table_id'].toString().toUpperCase();
                    final String itemType = item['category_type']?.toString().toUpperCase() ?? '';
                    final bool isManual = (item['is_manual'] == 1 || item['is_manual'] == true);

                    return itemTable == currentTable && isManual && itemType == 'LIQUOR';
                  });

                  if (hasActiveOrders) {
                    _showCheckoutDialog(context, state);
                  } else {
                    _showSnackBarLocal("NO ACTIVE MANUAL LIQUOR ORDERS ON TABLE $currentTable", Colors.amber);
                  }
                  return;
                }

                context.read<PosBloc>().add(ScanBarcodeEvent(input, isManual: true));
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
              onSubmitted: (val) => _executeKotPunchPipeline(),
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
              readOnly: !_isRateEditable,
              controller: _priceController,
              focusNode: _priceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isRateEditable ? Colors.black : Colors.blueGrey),
              onSubmitted: (val) => _executeKotPunchPipeline(),
              decoration: InputDecoration(
                labelText: "RATE",
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                prefixText: "₹",
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: _isRateEditable ? Colors.amber.shade50 : uniformFieldBg,
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: SizedBox(
              height: uniformComponentHeight,
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

  void _validateAndSelectTable(String rawTable, PosState state) {
    if (!_isValidTableForDisplay(rawTable)) {
      _showSnackBarLocal("TABLE '$rawTable' IS INVALID FOR EXCISE LIQUOR (50-55)!", Colors.redAccent);
      _tableInputController.clear();
      _closeTableOverlay();
      setState(() { _isTableDropdownOpen = false; });
      _tableFocusNode.requestFocus();
      return;
    }

    _tableInputController.text = rawTable;
    context.read<PosBloc>().add(SelectTableEvent(rawTable));
    _closeTableOverlay();
    setState(() { _isTableDropdownOpen = false; });
    _barcodeFocusNode.requestFocus();
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

  Widget _buildSplitGridPanel(PosState state, String targetType, Color headerBarColor) {
    final displayItems = state.runningOrders.where((item) {
      final String rawCatType = item['category_type']?.toString().trim().toUpperCase() ?? '';
      final String itemType = rawCatType.isEmpty ? 'LIQUOR' : rawCatType;

      final String currentSelectedTable = state.selectedTableId?.toString().trim().toUpperCase() ?? '';
      final String itemTableId = item['table_id']?.toString().trim().toUpperCase() ?? '';
      final bool matchesSelectedTable = currentSelectedTable.isNotEmpty && (itemTableId == currentSelectedTable);

      final dynamic rawIsManual = item['is_manual'];
      final bool isManualItem = (rawIsManual == 1 ||
          rawIsManual == true ||
          rawIsManual.toString() == '1' ||
          rawIsManual.toString().toLowerCase() == 'true');

      return itemType == targetType.toUpperCase() && matchesSelectedTable && isManualItem;
    }).toList();

    final int totalItemCount = displayItems.length;
    final double streamTotalAmount = displayItems.fold(0.0, (sum, item) {
      double unitPrice = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
      int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
      double amount = double.tryParse(item['amount']?.toString() ?? (unitPrice * qty).toString()) ?? (unitPrice * qty);
      return sum + amount;
    });

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          Container(
            color: headerBarColor,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "--- MANUAL $targetType STREAM ($totalItemCount ITEMS) ---",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "TOTAL: ₹${streamTotalAmount.toStringAsFixed(0)}",
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
                Expanded(flex: 2, child: Text("TABLE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("QTY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text("MRP/RATE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text("TOTAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text("DEL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: displayItems.isEmpty
                ? Center(
              child: Text(
                "No items active on table ${state.selectedTableId ?? ''} under $targetType.",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            )
                : ListView.builder(
              itemCount: displayItems.length,
              itemBuilder: (ctx, i) {
                final order = displayItems[i];
                final double unitPrice = double.tryParse(order['price']?.toString() ?? '0.0') ?? 0.0;
                final int qty = int.tryParse(order['qty']?.toString() ?? '1') ?? 1;
                final double totalAmount = double.tryParse(order['amount']?.toString() ?? (unitPrice * qty).toString()) ?? (unitPrice * qty);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text("${i + 1}", style: cellTextNormal)),
                      Expanded(flex: 2, child: Text(order['table_id'].toString().toUpperCase(), style: cellTextBold)),
                      Expanded(flex: 5, child: Text(order['item_name'].toString().toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text(qty.toString(), textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 2, child: Text("₹${unitPrice.toStringAsFixed(0)}", textAlign: TextAlign.right, style: cellTextNormal)),
                      Expanded(flex: 2, child: Text("₹${totalAmount.toStringAsFixed(0)}", textAlign: TextAlign.right, style: cellTextBold)),
                      Expanded(
                        flex: 1,
                        child: IconButton(
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

  // 🌟 4) EXCISE LIQUOR MAP (COMPACT & OVERFLOW-SAFE FOR 5-DIGIT AMOUNTS)
  Widget _buildRightFloorTotalGrid(PosState state) {
    final List<Map<String, dynamic>> activeSummaryList = [];

    for (int i = 50; i <= 55; i++) {
      final String tableId = i.toString();

      double cumulativeTotal = state.runningOrders
          .where((order) {
        final bool matchesTable = order['table_id'].toString().toUpperCase() == tableId.toUpperCase();
        final bool isManualItem = (order['is_manual'] == 1 || order['is_manual'] == true);
        final String catType = order['category_type']?.toString().toUpperCase() ?? 'LIQUOR';

        return matchesTable && isManualItem && (catType == 'LIQUOR');
      })
          .fold(0.0, (previousSum, element) {
        return previousSum + (double.tryParse(element['amount']?.toString() ?? '0.0') ?? 0.0);
      });

      if (cumulativeTotal > 0.0) {
        activeSummaryList.add({
          'table_name': tableId,
          'table_id': tableId,
          'total': cumulativeTotal,
        });
      }
    }

    return SizedBox(
      width: 200, // 👈 Compact fixed width
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 8, 6),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0F172A),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: const Text(
                "LIQUOR MAP (50-55)",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
            Expanded(
              child: activeSummaryList.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.purple, size: 24),
                    SizedBox(height: 4),
                    Text(
                      "ALL EXCISE\nTABLES CLEAR",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(4),
                physics: const BouncingScrollPhysics(),
                itemCount: activeSummaryList.length,
                itemBuilder: (ctx, index) {
                  final node = activeSummaryList[index];
                  final String tableId = node['table_id'].toString();
                  final String tableName = node['table_name'].toString().toUpperCase();
                  final double totalVal = node['total'] as double;

                  final bool isSelectedTable = state.selectedTableId?.toUpperCase() == tableId.toUpperCase();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _tableInputController.text = tableName;
                      });
                      context.read<PosBloc>().add(SelectTableEvent(tableId));
                      _barcodeFocusNode.requestFocus();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelectedTable ? Colors.purple.shade100 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelectedTable ? const Color(0xFF7C3AED) : const Color(0xFFE9D5FF),
                          width: isSelectedTable ? 1.5 : 1.0,
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
                          // Left: Chair Icon & Table Number (Flexible)
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.table_bar_rounded, size: 13, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    tableName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12, // 👈 Reduced Font size to prevent overflow
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 4),

                          // Right: 5-Digit Amount Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              "₹${totalVal.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5, // 👈 Clean fit for 5-digit amount
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
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
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("PROVISION NEW LIQUOR TABLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(hintText: "e.g., 50, 51, 52", hintStyle: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(fontSize: 11))),
                  ElevatedButton(
                    onPressed: () {
                      final val = nameCtrl.text.trim().toUpperCase();
                      if (val.isNotEmpty) {
                        if (!_isValidTableForDisplay(val)) {
                          _showSnackBarLocal("Table must be between 50 and 55!", Colors.redAccent);
                          return;
                        }
                        parentContext.read<PosBloc>().add(CreateTableEvent(tableId: val, tableName: val));
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4)),
                    child: const Text("CONFIRM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 1) REPRINT BILL DIALOG ADDED
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

    // 🍷 MANUAL LIQUOR REPRINT (Regular POS / Manual Liquor Archive target)
    parentContext.read<PosBloc>().add(
      ReprintBillEvent(
        billNo: billNo,
        billType: 'REGULAR', // 👈 Shared sequence for Regular POS & Manual Liquor
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

  // 🌟 3) CHECKOUT DIALOG WITH THREE OPTIONS: CANCEL, SAVE (WITHOUT PRINT), & SETTLE & PRINT
  // 🌟 1. CHECKOUT DIALOG (Strict Manual Liquor Filter & Zero-Guesswork)
  void _showCheckoutDialog(BuildContext parentContext, PosState state) {
    final mobileCtrl = TextEditingController();
    final FocusNode dialogFocusNode = FocusNode();

    List<Map<String, dynamic>> liquorItems = [];
    final String targetTable = _tableInputController.text.trim().toUpperCase();

    if (targetTable.isEmpty) {
      _showSnackBarLocal("Table selection required!", Colors.redAccent);
      return;
    }

    // 🛡️ STRICT ISOLATION: Sirf Manual Liquor items hi filter honge
    for (var order in state.runningOrders) {
      if (order['table_id'].toString().toUpperCase() != targetTable) continue;

      final dynamic rawIsManual = order['is_manual'];
      final bool isManualItem = (rawIsManual == 1 || rawIsManual == true || rawIsManual.toString() == '1');
      final String type = order['category_type']?.toString().toUpperCase() ?? 'LIQUOR';

      if (isManualItem && type == 'LIQUOR') {
        liquorItems.add(Map<String, dynamic>.from(order));
      }
    }

    double grandTotal = liquorItems.fold(
      0.0,
          (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0),
    );

    if (grandTotal == 0.0) {
      _showSnackBarLocal("No active Liquor items on Table $targetTable.", Colors.amber);
      return;
    }

    showDialog(
      context: parentContext,
      builder: (ctx) => Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            _processPrintAndCheckout(parentContext, ctx, targetTable, mobileCtrl.text, shouldPrint: true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFF0F172A),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFF00BCD4), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "SETTLE EXCISE BILL — TABLE $targetTable",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: "CUSTOMER MOBILE (OPTIONAL)",
                          labelStyle: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF00BCD4)),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("GRAND TOTAL NET:", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF0F172A))),
                            Text("₹${grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 15))
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 🌟 THREE BUTTON OPTIONS: CANCEL | SAVE (NO PRINT) | SETTLE & PRINT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("CANCEL", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () => _processPrintAndCheckout(parentContext, ctx, targetTable, mobileCtrl.text, shouldPrint: false),
                            icon: const Icon(Icons.save_rounded, size: 13, color: Color(0xFF10B981)),
                            label: const Text("SAVE (NO PRINT)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            onPressed: () => _processPrintAndCheckout(parentContext, ctx, targetTable, mobileCtrl.text, shouldPrint: true),
                            icon: const Icon(Icons.print_rounded, size: 13, color: Colors.white),
                            label: const Text("SETTLE & PRINT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
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

  // 🌟 2. PROCESS CHECKOUT (Server-First Confirmed Print Flow)
  void _processPrintAndCheckout(
      BuildContext parentCtx,
      BuildContext dialogCtx,
      String targetTable,
      String mobile, {
        required bool shouldPrint,
      }) {
    if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);

    final String auditDateStr = DateFormat('yyyy-MM-dd').format(_selectedManualDate);

    // 🚀 BLoC ko event dispatch hoga (DB transaction finish hone ke baad confirmed Bill # print hoga)
    parentCtx.read<PosBloc>().add(
      CheckoutManualTableEvent(
        tableId: targetTable,
        mobileNumber: mobile.trim(),
        businessDateStr: auditDateStr,
        shouldPrint: shouldPrint,
        onResult: (isSuccess, message) {
          _showSnackBarLocal(message, isSuccess ? Colors.green : Colors.red);
        },
      ),
    );
  }
}