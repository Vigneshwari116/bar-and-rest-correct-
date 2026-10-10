import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';

class ManualLiquorItemEditingPage extends StatefulWidget {
  const ManualLiquorItemEditingPage({super.key});

  @override
  State<ManualLiquorItemEditingPage> createState() => _ManualLiquorItemEditingPageState();
}

class _ManualLiquorItemEditingPageState extends State<ManualLiquorItemEditingPage> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  List<dynamic> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  final int _rowLimit = 50;
  int _currentOffset = 0;

  // Search Parameters
  String _searchName = '';
  String _searchBarcode = '';
  Timer? _debounceTimer;

  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _barcodeSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _activeEditingCellKey;

  @override
  void initState() {
    super.initState();
    _fetchPaginatedProducts(isRefresh: true);

    // ⚡ Auto Load More on Scroll Bottom
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        if (!_isLoadingMore && _hasMoreData && !_isLoading) {
          _fetchPaginatedProducts(isRefresh: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameSearchController.dispose();
    _barcodeSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🌟 ON-DEMAND DATABASE SEARCH & PAGINATION ENGINE
  Future<void> _fetchPaginatedProducts({bool isRefresh = false}) async {
    if (isRefresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _currentOffset = 0;
          _products.clear();
          _hasMoreData = true;
        });
      }
    } else {
      if (!_hasMoreData || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final String endpoint = '/api/v1/manual-liquor/products?'
          'limit=$_rowLimit&'
          'offset=$_currentOffset&'
          'name=${Uri.encodeComponent(_searchName)}&'
          'barcode=${Uri.encodeComponent(_searchBarcode)}';

      final response = await apiClient.get(endpoint);

      if (response.data['status'] == 'SUCCESS') {
        final List<dynamic> fetchedList = response.data['data'] ?? [];

        if (mounted) {
          setState(() {
            if (isRefresh) {
              _products = fetchedList;
            } else {
              _products.addAll(fetchedList);
            }
            _isLoading = false;
            _isLoadingMore = false;

            if (fetchedList.length < _rowLimit) {
              _hasMoreData = false;
            } else {
              _currentOffset += _rowLimit;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        _showSnackBar("Database Fetch Error: $e", Colors.red);
      }
    }
  }

  // ⚡ DYNAMIC DEBOUNCED SEARCH (TYPE ACCORDINGLY & AUTO FETCH)
  void _onSearchNameChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      final query = val.trim();
      if (_searchName != query) {
        _searchName = query;
        _fetchPaginatedProducts(isRefresh: true);
      }
    });
  }

  void _onSearchBarcodeChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      final query = val.trim();
      if (_searchBarcode != query) {
        _searchBarcode = query;
        _fetchPaginatedProducts(isRefresh: true);
      }
    });
  }

  // ⚡ CLEAR SEARCH & RESET STATE TO TOP-1 DATA
  void _clearSearchFilters() {
    _nameSearchController.clear();
    _barcodeSearchController.clear();
    _searchName = '';
    _searchBarcode = '';
    _fetchPaginatedProducts(isRefresh: true);
  }

  // ⚡ INLINE CELL UPDATE
  Future<void> _updateCellInline(int productId, String columnName, String newValue) async {
    try {
      final response = await apiClient.post('/api/v1/manual-liquor/product/update-field', data: {
        'product_id': productId,
        'column': columnName,
        'value': newValue,
      });

      if (response.data['status'] == 'SUCCESS') {
        if (mounted) {
          setState(() {
            final item = _products.firstWhere((p) => p['id'] == productId);
            if (columnName == 'cost_price' || columnName == 'sale_price' || columnName == 'm_price') {
              item[columnName] = double.tryParse(newValue) ?? 0.0;
            } else {
              item[columnName] = newValue.toUpperCase();
            }
          });
        }
      }
    } catch (e) {
      _showSnackBar("Update Failed: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 11)), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("MANUAL LIQUOR ITEM EDITOR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            onPressed: () => _fetchPaginatedProducts(isRefresh: true),
            tooltip: "Reset & Sync Data",
          ),
        ],
      ),
      body: Column(
        children: [
          // 1️⃣ DYNAMIC SEARCH & CLEAR TOOLBAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nameSearchController,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    onChanged: _onSearchNameChanged,
                    decoration: InputDecoration(
                      hintText: "Search Product Name On-Demand...",
                      prefixIcon: const Icon(Icons.search, size: 15),
                      suffixIcon: _nameSearchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _nameSearchController.clear();
                          _onSearchNameChanged('');
                        },
                      )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _barcodeSearchController,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    onChanged: _onSearchBarcodeChanged,
                    decoration: InputDecoration(
                      hintText: "Scan Barcode...",
                      prefixIcon: const Icon(Icons.qr_code, size: 15),
                      suffixIcon: _barcodeSearchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _barcodeSearchController.clear();
                          _onSearchBarcodeChanged('');
                        },
                      )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: _clearSearchFilters,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 14),
                    label: const Text("RESET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueGrey)),
                  ),
                )
              ],
            ),
          ),

          // 2️⃣ SINGLE SCREEN FIT GRID TABLE (NO HORIZONTAL SCROLL)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // 📊 HEADER ROW (COLUMNS RE-ORDERED: NAME ➔ COST ➔ SALE ➔ M-PRICE ➔ BARCODE)
                  Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Row(
                      children: [
                        Expanded(flex: 1, child: Text("S.N", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white))),
                        Expanded(flex: 6, child: Text("PRODUCT NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white))),
                        Expanded(flex: 2, child: Text("COST (₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text("SALE (₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text("M-PRICE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.right)),
                        Expanded(flex: 3, child: Text("BARCODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),

                  // 📊 DATA ROWS STREAM
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : _products.isEmpty
                        ? Center(
                      child: Text(
                        "No matching products found in database for '$_searchName'.",
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    )
                        : ListView.separated(
                      controller: _scrollController,
                      itemCount: _products.length + (_hasMoreData ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(height: 0.5, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final p = _products[index];
                        final int pId = p['id'];

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text("${index + 1}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                              Expanded(flex: 6, child: _buildEditableCellWidget(pId, 'product_name', p['product_name'].toString(), false)),
                              Expanded(flex: 2, child: _buildEditableCellWidget(pId, 'cost_price', p['cost_price'].toString(), true)),
                              Expanded(flex: 2, child: _buildEditableCellWidget(pId, 'sale_price', p['sale_price'].toString(), true)),
                              Expanded(flex: 2, child: _buildEditableCellWidget(pId, 'm_price', p['m_price'].toString(), true)),
                              Expanded(flex: 3, child: _buildEditableCellWidget(pId, 'barcode', p['barcode'].toString(), false, isCenter: true)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📝 INLINE EDITABLE CELL WIDGET
  Widget _buildEditableCellWidget(int productId, String columnName, String currentValue, bool isNumeric, {bool isCenter = false}) {
    final cellKey = "${productId}_$columnName";
    final bool isEditing = _activeEditingCellKey == cellKey;

    if (isEditing) {
      final controller = TextEditingController(text: currentValue);
      return SizedBox(
        height: 26,
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          textAlign: isNumeric ? TextAlign.right : (isCenter ? TextAlign.center : TextAlign.left),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            isDense: true,
          ),
          onSubmitted: (val) {
            setState(() => _activeEditingCellKey = null);
            if (val.trim() != currentValue.trim()) {
              _updateCellInline(productId, columnName, val.trim());
            }
          },
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _activeEditingCellKey = cellKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: isNumeric ? Alignment.centerRight : (isCenter ? Alignment.center : Alignment.centerLeft),
        child: Text(
          isNumeric ? "₹${(double.tryParse(currentValue) ?? 0.0).toStringAsFixed(0)}" : currentValue,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isNumeric ? FontWeight.w900 : FontWeight.w600,
            color: isNumeric && columnName == 'sale_price' ? Colors.green.shade700 : const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}