import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/secure_storage_util.dart';

class ManualLiquorMenuMasterPage extends StatefulWidget {
  const ManualLiquorMenuMasterPage({super.key});

  @override
  State<ManualLiquorMenuMasterPage> createState() => _ManualLiquorMenuMasterPageState();
}

class _ManualLiquorMenuMasterPageState extends State<ManualLiquorMenuMasterPage> {
  final ApiClient _apiClient = GetIt.I<ApiClient>();

  bool _isCategoriesLoading = false;
  bool _isActionLoading = false;

  List<dynamic> _categories = [];
  String _tenantId = 'svenska_1';

  final _itemFormKey = GlobalKey<FormState>();
  final _groupFormKey = GlobalKey<FormState>();
  String? _selectedCategoryId;

  final _productNameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'ML');
  final _barcodeCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController(text: '0.0');
  final _salePriceCtrl = TextEditingController(text: '0.0');
  final _mPriceCtrl = TextEditingController(text: '0.0');
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
    _mPriceCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final String? tId = await SecureStorageUtil.getUserTenant();
      if (mounted) {
        setState(() {
          _tenantId = tId ?? 'svenska_1';
        });
      }
    } catch (_) {}
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() => _isCategoriesLoading = true);
    try {
      final response = await _apiClient.get(
        '/api/v1/manual-liquor/groups',
        queryParams: {'tenant_id': _tenantId},
      );
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) responseData = jsonDecode(responseData);
        final List<dynamic> data = responseData['data'] ?? [];
        if (mounted) {
          setState(() {
            _categories = data;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Categories fetch error: $e");
    } finally {
      if (mounted) {
        setState(() => _isCategoriesLoading = false);
      }
    }
  }

  Future<void> _saveGroup() async {
    if (!_groupFormKey.currentState!.validate()) return;
    setState(() => _isActionLoading = true);
    try {
      await _apiClient.post('/api/v1/manual-liquor/group/create', data: {
        'tenant_id': _tenantId,
        'name': _groupNameCtrl.text.trim(),
      });
      _groupNameCtrl.clear();
      _showSnack('Manual Liquor Group created!');
      _fetchCategories();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _saveItem() async {
    if (!_itemFormKey.currentState!.validate()) return;
    setState(() => _isActionLoading = true);
    try {
      await _apiClient.post('/api/v1/manual-liquor/product/create', data: {
        'tenant_id': _tenantId,
        'category_id': _selectedCategoryId,
        'product_name': _productNameCtrl.text.trim(),
        'unit_measure': _unitCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'cost_price': _costPriceCtrl.text.trim(),
        'sale_price': _salePriceCtrl.text.trim(),
        'm_price': _mPriceCtrl.text.trim(),
      });
      _itemFormKey.currentState!.reset();
      setState(() => _selectedCategoryId = null);
      _showSnack('Manual Liquor Item Saved!');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _importCsvData() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isActionLoading = true);
      try {
        final file = File(result.files.single.path!);
        final String rawCsvString = await file.readAsString();

        final List<List<dynamic>> fields = Csv().decode(rawCsvString);

        if (fields.isEmpty) {
          _showSnack('CSV file is empty!', isError: true);
          return;
        }

        final response = await _apiClient.post(
          '/api/v1/manual-liquor/bulk-import',
          data: {
            'tenant_id': _tenantId,
            'csv_data': fields,
          },
        );

        if (response.statusCode == 200 && response.data['status'] == 'SUCCESS') {
          _showSnack('Manual Liquor CSV Imported Successfully!');
          _fetchCategories();
        } else {
          _showSnack('Import failed: ${response.data['message'] ?? 'Unknown Error'}', isError: true);
        }
      } catch (e) {
        _showSnack('CSV Import Error: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ROW WITH ALWAYS VISIBLE CSV BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "MANUAL LIQUOR CATALOG MASTER",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        // 🌟 ALWAYS ENABLED (NEVER HIDDEN/DISABLED)
                        onPressed: _isActionLoading ? null : _importCsvData,
                        icon: _isActionLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file, size: 16),
                        label: const Text("IMPORT LIQUOR CSV", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildModernCard("ADD MANUAL LIQUOR PRODUCT", _buildItemForm(isMobile))),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildModernCard("ADD LIQUOR GROUP", _buildGroupForm())),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildModernCard("ADD MANUAL LIQUOR PRODUCT", _buildItemForm(isMobile)),
                      const SizedBox(height: 16),
                      _buildModernCard("ADD LIQUOR GROUP", _buildGroupForm()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: emerald, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildItemForm(bool isMobile) {
    return Form(
      key: _itemFormKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _categories.any((c) => (c as Map)['id'].toString() == _selectedCategoryId) ? _selectedCategoryId : null,
            dropdownColor: cardColor,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('Select Liquor Group', Icons.category_outlined),
            hint: _isCategoriesLoading
                ? const Text("Loading groups...", style: TextStyle(color: textMuted, fontSize: 12))
                : const Text("Select Group", style: TextStyle(color: textMuted, fontSize: 12)),
            items: _categories.map((c) {
              final item = c as Map<String, dynamic>;
              return DropdownMenuItem<String>(
                value: item['id'].toString(),
                child: Text(item['category_name']?.toString() ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
            validator: (v) => v == null ? 'Req' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _productNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('Liquor Product Name', Icons.local_bar_outlined),
            validator: (v) => v!.isEmpty ? 'Req' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _unitCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Unit (e.g. 750ml)', Icons.local_drink_outlined))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _barcodeCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Barcode', Icons.qr_code_2_outlined))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _costPriceCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Cost Price', Icons.currency_rupee))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _salePriceCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('Sale Price', Icons.sell_outlined))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _mPriceCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDec('M-Price (MRP)', Icons.price_change_outlined))),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _saveItem,
              style: _primaryBtnStyle(),
              child: const Text("SAVE MANUAL LIQUOR PRODUCT"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGroupForm() {
    return Form(
      key: _groupFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _groupNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDec('New Liquor Group Name', Icons.format_list_bulleted_add),
            validator: (v) => v!.isEmpty ? 'Req' : null,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _saveGroup,
              style: _primaryBtnStyle(),
              child: const Text("CREATE LIQUOR GROUP"),
            ),
          )
        ],
      ),
    );
  }

  ButtonStyle _primaryBtnStyle() => ElevatedButton.styleFrom(
    backgroundColor: emerald,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  InputDecoration _inputDec(String label, [IconData? icon]) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelText: label,
      labelStyle: const TextStyle(color: textMuted, fontSize: 11.5),
      prefixIcon: icon != null ? Icon(icon, size: 15, color: textMuted) : null,
      filled: true,
      fillColor: bgDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: emerald)),
    );
  }
}