
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/secure_storage_util.dart';

class MenuMasterPage extends StatefulWidget {
  const MenuMasterPage({super.key});

  @override
  State<MenuMasterPage> createState() => _MenuMasterPageState();
}

class _MenuMasterPageState extends State<MenuMasterPage> {
  final ApiClient _apiClient = GetIt.I<ApiClient>();

  bool _isLoading = false;
  List<dynamic> _categories = [];
  String _selectedType = 'LIQUOR';
  String _tenantId = '';

  final _itemFormKey = GlobalKey<FormState>();
  final _groupFormKey = GlobalKey<FormState>();
  String? _selectedCategoryId;

  final _productNameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController(text: '0.0');
  final _salePriceCtrl = TextEditingController(text: '0.0');
  final _groupNameCtrl = TextEditingController();

  static const Color emerald = Color(0xFF27AE60);
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color cardColor = Color(0xFF12161F);
  static const Color borderColor = Color(0xFF1F2533);
  static const Color textMuted = Color(0xFF7A849C);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _unitCtrl.dispose();
    _barcodeCtrl.dispose();
    _costPriceCtrl.dispose();
    _salePriceCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final String? tId = await SecureStorageUtil.getUserTenant();
    setState(() => _tenantId = tId ?? 'svenska_1');
    debugPrint("🚀 [MenuMaster] Initialized with Tenant: $_tenantId");
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    debugPrint("🔍 [API] Fetching Categories for Tenant: $_tenantId, Type: $_selectedType");
    try {
      final response = await _apiClient.get('/api/v1/groups',
          queryParams: {'tenant_id': _tenantId, 'type': _selectedType});

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) responseData = jsonDecode(responseData);
        final List<dynamic> data = responseData['data'] ?? [];
        debugPrint("✅ [API] Categories received: ${data.length}");
        setState(() => _categories = data);
      }
    } catch (e) {
      debugPrint("❌ [API Error]: $e");
      _showSnack('Failed to load groups', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGroup() async {
    if (!_groupFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _apiClient.post('/api/v1/group/create', data: {
        'tenant_id': _tenantId, 'type': _selectedType, 'name': _groupNameCtrl.text.trim()
      });
      _groupNameCtrl.clear();
      _showSnack('Group created successfully!');
      _fetchCategories();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveItem() async {
    if (!_itemFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _apiClient.post('/api/v1/product/create', data: {
        'tenant_id': _tenantId,
        'category_id': _selectedCategoryId,
        'product_name': _productNameCtrl.text.trim(),
        'unit_measure': _unitCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'cost_price': _costPriceCtrl.text.trim(),
        'sale_price': _salePriceCtrl.text.trim(),
      });
      _itemFormKey.currentState!.reset();
      setState(() => _selectedCategoryId = null);
      _showSnack('Item saved!');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importCsvData() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      final file = File(result.files.single.path!);
      final List<List<dynamic>> fields = Csv().decode(await file.readAsString());
      await _apiClient.post('/api/v1/bulk-import', data: {'tenant_id': _tenantId, 'csv_data': fields});
      _showSnack('CSV Imported!');
      _fetchCategories();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: isError ? Colors.red.shade700 : emerald,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          final bool isDesktop = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 12 : 20,
            ),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1️⃣ HEADER SECTION
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CATALOG MANAGEMENT",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _importCsvData,
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text("IMPORT CSV", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: emerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "CATALOG MANAGEMENT",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _importCsvData,
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text("IMPORT CSV", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: emerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // 2️⃣ TOGGLE BUTTONS
                Row(
                  children: [
                    _buildToggleBtn('LIQUOR'),
                    const SizedBox(width: 8),
                    _buildToggleBtn('FOOD'),
                  ],
                ),

                const SizedBox(height: 16),

                // 3️⃣ MAIN CONTENT (DESKTOP: SIDE-BY-SIDE | MOBILE: STACKED)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildModernCard("ADD NEW PRODUCT", _buildItemForm(isMobile))),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildModernCard("ADD NEW CATEGORY", _buildGroupForm())),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernCard("ADD NEW PRODUCT", _buildItemForm(isMobile)),
                      const SizedBox(height: 16),
                      _buildModernCard("ADD NEW CATEGORY", _buildGroupForm()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🃏 MODERN CARD WIDGET
  Widget _buildModernCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: emerald, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // 📝 ITEM FORM (RESPONSIVE FIELDS)
  Widget _buildItemForm(bool isMobile) {
    return Form(
      key: _itemFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // GROUP & PRODUCT NAME
          if (isMobile)
            Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(_categories.length),
                  value: _categories.any((c) => (c as Map)['id'].toString() == _selectedCategoryId) ? _selectedCategoryId : null,
                  dropdownColor: cardColor,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDec('Select Group', Icons.category_outlined),
                  icon: const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 18),
                  items: _categories.map((c) {
                    final item = c as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: item['id'].toString(),
                      child: Text(item['category_name']?.toString() ?? 'Unknown', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                  validator: (v) => v == null ? 'Req' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _productNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDec('Product Name', Icons.fastfood_outlined),
                  validator: (v) => v!.isEmpty ? 'Req' : null,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_categories.length),
                    value: _categories.any((c) => (c as Map)['id'].toString() == _selectedCategoryId) ? _selectedCategoryId : null,
                    dropdownColor: cardColor,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDec('Select Group', Icons.category_outlined),
                    icon: const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 18),
                    items: _categories.map((c) {
                      final item = c as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(item['category_name']?.toString() ?? 'Unknown', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? 'Req' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _productNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDec('Product Name', Icons.fastfood_outlined),
                    validator: (v) => v!.isEmpty ? 'Req' : null,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),

          // UNIT & BARCODE
          if (isMobile)
            Column(
              children: [
                TextFormField(controller: _unitCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Unit (ml)', Icons.local_drink_outlined)),
                const SizedBox(height: 10),
                TextFormField(controller: _barcodeCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Barcode', Icons.qr_code_2_outlined)),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: TextFormField(controller: _unitCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Unit (ml)', Icons.local_drink_outlined))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _barcodeCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Barcode', Icons.qr_code_2_outlined))),
              ],
            ),

          const SizedBox(height: 10),

          // COST PRICE & SALE PRICE
          if (isMobile)
            Column(
              children: [
                TextFormField(controller: _costPriceCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Cost Price', Icons.currency_rupee)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _salePriceCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDec('Sale Price', Icons.sell_outlined),
                  validator: (v) => v!.isEmpty ? 'Req' : null,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: TextFormField(controller: _costPriceCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Cost Price', Icons.currency_rupee))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDec('Sale Price', Icons.sell_outlined),
                    validator: (v) => v!.isEmpty ? 'Req' : null,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveItem,
              style: _primaryBtnStyle(),
              child: _isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("SAVE PRODUCT"),
            ),
          )
        ],
      ),
    );
  }

  // 📂 GROUP FORM
  Widget _buildGroupForm() {
    return Form(
      key: _groupFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _groupNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('New Group Name', Icons.format_list_bulleted_add),
            validator: (v) => v!.isEmpty ? 'Req' : null,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveGroup,
              style: _primaryBtnStyle(),
              child: const Text("CREATE GROUP"),
            ),
          )
        ],
      ),
    );
  }

  // 🔘 TOGGLE BUTTON
  Widget _buildToggleBtn(String type) {
    bool isSel = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategoryId = null;
        });
        _fetchCategories();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? emerald.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSel ? emerald : borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(type, style: TextStyle(color: isSel ? emerald : textMuted, fontWeight: FontWeight.bold, fontSize: 11.5)),
      ),
    );
  }

  // 🎨 COMMON BUTTON STYLE
  ButtonStyle _primaryBtnStyle() => ElevatedButton.styleFrom(
    backgroundColor: emerald,
    foregroundColor: Colors.white,
    elevation: 0,
    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  // 🎨 COMPACT INPUT DECORATION
  InputDecoration _inputDec(String label, [IconData? icon]) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelText: label,
      labelStyle: const TextStyle(color: textMuted, fontSize: 11.5),
      prefixIcon: icon != null ? Icon(icon, size: 15, color: textMuted) : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      filled: true,
      fillColor: bgDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: emerald)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.red.shade700)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.red.shade700)),
      errorStyle: const TextStyle(fontSize: 9.5, height: 0.8),
    );
  }
}