import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';

class ItemEditingMasterPage extends StatefulWidget {
  const ItemEditingMasterPage({super.key});

  @override
  State<ItemEditingMasterPage> createState() => _ItemEditingMasterPageState();
}

class _ItemEditingMasterPageState extends State<ItemEditingMasterPage> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  final int _rowLimit = 50;
  int _currentOffset = 0;

  // Search Parameters
  String _searchName = '';
  String _searchBarcode = '';
  String _selectedCategoryType = 'ALL';
  String _selectedCategoryId = 'ALL';
  Timer? _debounceTimer;

  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _barcodeSearchController = TextEditingController();
  final TextEditingController _groupSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isGroupDropdownOpen = false;
  String? _activeEditingCellKey;

  @override
  void initState() {
    super.initState();
    _fetchInitialMasterData();

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
    _groupSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialMasterData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final catResponse = await apiClient.get('/api/v1/groups');
      if (catResponse.data['status'] == 'SUCCESS') {
        _categories = catResponse.data['data'] ?? [];
        _filteredCategories = List.from(_categories);
      }
      await _fetchPaginatedProducts(isRefresh: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Initial Sync Failed: $e", Colors.red);
      }
    }
  }

  // 🌟 ON-DEMAND GLOBAL DATABASE SEARCH ENGINE
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
      final String endpoint = '/api/v1/products?'
          'limit=$_rowLimit&'
          'offset=$_currentOffset&'
          'name=${Uri.encodeComponent(_searchName)}&'
          'barcode=${Uri.encodeComponent(_searchBarcode)}&'
          'category_type=$_selectedCategoryType&'
          'category_id=$_selectedCategoryId';

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
        _showSnackBar("Catalog Sync Failure: $e", Colors.red);
      }
    }
  }

  void _onSearchNameChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = val.trim();
      if (_searchName != query) {
        _searchName = query;
        _fetchPaginatedProducts(isRefresh: true);
      }
    });
  }

  void _onSearchBarcodeChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = val.trim();
      if (_searchBarcode != query) {
        _searchBarcode = query;
        _fetchPaginatedProducts(isRefresh: true);
      }
    });
  }

  void _clearSearchFilters() {
    _nameSearchController.clear();
    _barcodeSearchController.clear();
    _groupSearchController.clear();
    setState(() {
      _searchName = '';
      _searchBarcode = '';
      _selectedCategoryType = 'ALL';
      _selectedCategoryId = 'ALL';
      _filteredCategories = List.from(_categories);
      _isGroupDropdownOpen = false;
    });
    _fetchPaginatedProducts(isRefresh: true);
  }

  void _filterGroupDropdownOptions(String query) {
    setState(() {
      _filteredCategories = _categories.where((cat) {
        final nameMatch = cat['category_name'].toString().toUpperCase().contains(query.toUpperCase());
        if (_selectedCategoryType != 'ALL') {
          return nameMatch && cat['category_type'].toString().toUpperCase() == _selectedCategoryType;
        }
        return nameMatch;
      }).toList();
    });
  }

  Future<void> _updateCellInline(int productId, String columnName, String newValue) async {
    try {
      final response = await apiClient.post('/api/v1/product/update-field', data: {
        'product_id': productId,
        'column': columnName,
        'value': newValue,
      });

      if (response.data['status'] == 'SUCCESS') {
        if (mounted) {
          setState(() {
            final item = _products.firstWhere((p) => p['id'] == productId);
            if (columnName == 'cost_price' || columnName == 'sale_price') {
              item[columnName] = double.tryParse(newValue) ?? 0.0;
            } else {
              item[columnName] = newValue.toUpperCase();
            }
          });
        }
      }
    } catch (e) {
      _showSnackBar("Failed inline alteration sync: $e", Colors.red);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            title: Text(
              isMobile ? "ITEM MASTER EDITOR" : "ENTERPRISE ITEM MASTER EDITOR",
              style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                onPressed: _fetchInitialMasterData,
                tooltip: "Refresh Master Data",
              )
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildSearchFilterPanelLayout(isMobile),
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
                          // 📊 HEADER ROW
                          Container(
                            color: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: const Row(
                              children: [
                                Expanded(flex: 1, child: Text("S.N", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white))),
                                Expanded(flex: 6, child: Text("PRODUCT NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white))),
                                Expanded(flex: 2, child: Text("COST (₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.right)),
                                Expanded(flex: 2, child: Text("SALE (₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.right)),
                                Expanded(flex: 2, child: Text("DEPT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                                Expanded(flex: 3, child: Text("BARCODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white), textAlign: TextAlign.center)),
                              ],
                            ),
                          ),

                          // 📊 DATA ROWS WITH SCROLLBAR & MOUSE WHEEL SCROLLING
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : _products.isEmpty
                                ? Center(
                              child: Text(
                                "No matching products found in database.",
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            )
                                : Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              thickness: 6,
                              radius: const Radius.circular(3),
                              child: ListView.separated(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
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

                                  final product = _products[index];
                                  final int productId = product['id'];

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 1, child: Text("${index + 1}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                                        Expanded(flex: 6, child: _buildEditableCellWidget(productId, 'product_name', product['product_name'].toString(), false)),
                                        Expanded(flex: 2, child: _buildEditableCellWidget(productId, 'cost_price', product['cost_price'].toString(), true)),
                                        Expanded(flex: 2, child: _buildEditableCellWidget(productId, 'sale_price', product['sale_price'].toString(), true)),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: product['category_type'] == 'LIQUOR' ? Colors.purple.shade50 : Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              child: Text(
                                                product['category_type']?.toString() ?? 'FOOD',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: product['category_type'] == 'LIQUOR' ? Colors.purple : Colors.orange.shade900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(flex: 3, child: _buildEditableCellWidget(productId, 'barcode', product['barcode'].toString(), false, isCenter: true)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isGroupDropdownOpen) _buildSearchableGroupOverlay(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchFilterPanelLayout(bool isMobile) {
    String currentGroupLabel = "ALL GROUPS";
    if (_selectedCategoryId != 'ALL') {
      final match = _categories.firstWhere((c) => c['id'].toString() == _selectedCategoryId, orElse: () => null);
      if (match != null) currentGroupLabel = match['category_name'].toString().toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
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
                flex: 3,
                child: TextField(
                  controller: _barcodeSearchController,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  onChanged: _onSearchBarcodeChanged,
                  decoration: InputDecoration(
                    hintText: "Scan Barcode...",
                    prefixIcon: const Icon(Icons.qr_code_scanner, size: 15),
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
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedCategoryType,
                  style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text("ALL DEPTS")),
                    DropdownMenuItem(value: 'FOOD', child: Text("FOOD ITEMS")),
                    DropdownMenuItem(value: 'LIQUOR', child: Text("LIQUOR")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryType = val!;
                      _selectedCategoryId = 'ALL';
                      if (_selectedCategoryType == 'ALL') {
                        _filteredCategories = List.from(_categories);
                      } else {
                        _filteredCategories = _categories
                            .where((c) => c['category_type'].toString().toUpperCase() == _selectedCategoryType)
                            .toList();
                      }
                    });
                    _fetchPaginatedProducts(isRefresh: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isGroupDropdownOpen = !_isGroupDropdownOpen;
                      if (_selectedCategoryType == 'ALL') {
                        _filteredCategories = List.from(_categories);
                      } else {
                        _filteredCategories = _categories
                            .where((c) => c['category_type'].toString().toUpperCase() == _selectedCategoryType)
                            .toList();
                      }
                      _groupSearchController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            currentGroupLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: _clearSearchFilters,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 13),
                  label: const Text("RESET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueGrey)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchableGroupOverlay(bool isMobile) {
    return Positioned(
      right: 10,
      top: 85,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(8),
          width: 250,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            children: [
              TextField(
                controller: _groupSearchController,
                style: const TextStyle(fontSize: 11),
                autofocus: true,
                onChanged: _filterGroupDropdownOptions,
                decoration: const InputDecoration(
                  hintText: "Search Group...",
                  prefixIcon: Icon(Icons.search, size: 12),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filteredCategories.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 0.5, color: Colors.black12),
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = 'ALL';
                            _isGroupDropdownOpen = false;
                          });
                          _fetchPaginatedProducts(isRefresh: true);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                          child: Text("ALL GROUPS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                      );
                    }

                    final cat = _filteredCategories[idx - 1];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = cat['id'].toString();
                          _isGroupDropdownOpen = false;
                        });
                        _fetchPaginatedProducts(isRefresh: true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat['category_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text("Type: ${cat['category_type']}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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