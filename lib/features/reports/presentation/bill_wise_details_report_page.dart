import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';

class BillwiseDetailedReportView extends StatefulWidget {
  const BillwiseDetailedReportView({super.key});

  @override
  State<BillwiseDetailedReportView> createState() => _BillwiseDetailedReportViewState();
}

class _BillwiseDetailedReportViewState extends State<BillwiseDetailedReportView> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  bool _isAscending = true;
  List<dynamic> _billsList = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final String startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final String endStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await apiClient.get(
        '/api/v1/reports/billwise-detailed?start_date=$startStr&end_date=$endStr',
      );

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        setState(() {
          _billsList = response.data['data'] as List<dynamic>? ?? [];
        });
      } else {
        setState(() => _billsList = []);
      }
    } catch (e) {
      debugPrint("🔴 Error fetching detailed bill report: $e");
      setState(() => _billsList = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00BCD4),
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReportData();
    }
  }

  String _formatTimestamp(String? rawIso) {
    if (rawIso == null || rawIso.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(rawIso);
      return DateFormat('dd/MM/yy hh:mm a').format(dt);
    } catch (_) {
      return rawIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 1. FILTER BY BILL NUMBER (Priority) OR TABLE
    final filteredBills = _billsList.where((b) {
      final billNo = b['bill_no']?.toString().trim().toUpperCase() ?? '';
      final tableId = b['table_id']?.toString().trim().toUpperCase() ?? '';
      final query = _searchQuery.trim().toUpperCase();

      if (query.isEmpty) return true;

      // Exact bill number match or starts with query
      return billNo == query || billNo.startsWith(query) || billNo.contains(query) || tableId == query;
    }).toList();

    // 🌟 2. SORTING ORDER (1, 2, 3... ASCENDING)
    filteredBills.sort((a, b) {
      final intNumA = int.tryParse(a['bill_no']?.toString() ?? '0') ?? 0;
      final intNumB = int.tryParse(b['bill_no']?.toString() ?? '0') ?? 0;

      if (_isAscending) {
        return intNumA.compareTo(intNumB); // 👈 1, 2, 3...
      } else {
        return intNumB.compareTo(intNumA); // 👈 3, 2, 1...
      }
    });

    double totalRevenue = 0.0;
    double totalFoodRevenue = 0.0;
    double totalLiquorRevenue = 0.0;

    for (var b in filteredBills) {
      totalRevenue += double.tryParse(b['grand_total']?.toString() ?? '0.0') ?? 0.0;
      totalFoodRevenue += double.tryParse(b['food_total']?.toString() ?? '0.0') ?? 0.0;
      totalLiquorRevenue += double.tryParse(b['liquor_total']?.toString() ?? '0.0') ?? 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ---------------- 1. TOP BAR WITH BILL SEARCH & SORT ----------------
          _buildTopFilterBar(context, filteredBills.length, totalRevenue, totalFoodRevenue, totalLiquorRevenue),

          // ---------------- 2. BILLS LIST (1, 2, 3...) ----------------
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4)))
                : filteredBills.isEmpty
                ? Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? "No Bill found matching '#$_searchQuery'"
                    : "No Settled Bills found for selected duration.",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const BouncingScrollPhysics(),
              itemCount: filteredBills.length,
              itemBuilder: (ctx, index) {
                final bill = filteredBills[index];
                return _buildBillDetailCard(bill);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilterBar(
      BuildContext context,
      int billCount,
      double totalRev,
      double foodRev,
      double liquorRev,
      ) {
    final String dateRangeDisplay =
        "${DateFormat('dd/MM/yyyy').format(_startDate)} — ${DateFormat('dd/MM/yyyy').format(_endDate)}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date Range Picker Button
              InkWell(
                onTap: () => _pickDateRange(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFF00BCD4), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        dateRangeDisplay,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 🔍 DEDICATED BILL NUMBER SEARCH BAR
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Enter Bill # (e.g. 1, 2, 3...)",
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF00BCD4)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 🌟 SORT ORDER TOGGLE BUTTON (ASC / DESC)
              InkWell(
                onTap: () {
                  setState(() {
                    _isAscending = !_isAscending;
                  });
                },
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 15,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAscending ? "1 ➔ 9" : "9 ➔ 1",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                onPressed: _fetchReportData,
                tooltip: "Reload Report",
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Summary Stats Pills
          Row(
            children: [
              _buildMetricPill("BILLS: $billCount", const Color(0xFF0F172A), Colors.white),
              const SizedBox(width: 6),
              _buildMetricPill("FOOD: ₹${foodRev.toStringAsFixed(0)}", const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
              const SizedBox(width: 6),
              _buildMetricPill("LIQUOR: ₹${liquorRev.toStringAsFixed(0)}", const Color(0xFFF3E8FF), const Color(0xFF6B21A8)),
              const Spacer(),
              _buildMetricPill("TOTAL: ₹${totalRev.toStringAsFixed(0)}", const Color(0xFFDCFCE7), const Color(0xFF15803D), isBold: true),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricPill(String text, Color bg, Color textCol, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 10.5,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBillDetailCard(Map<String, dynamic> bill) {
    final String billNo = bill['bill_no']?.toString() ?? 'N/A';
    final String tableId = bill['table_id']?.toString() ?? '1';
    final String timeStr = _formatTimestamp(bill['created_at']?.toString());
    final String sourceType = bill['source_type']?.toString() ?? 'REGULAR';
    final double grandTotal = double.tryParse(bill['grand_total']?.toString() ?? '0.0') ?? 0.0;
    final double foodTotal = double.tryParse(bill['food_total']?.toString() ?? '0.0') ?? 0.0;
    final double liquorTotal = double.tryParse(bill['liquor_total']?.toString() ?? '0.0') ?? 0.0;
    final List items = bill['items'] as List? ?? [];

    final bool isManualLiq = sourceType == 'MANUAL_LIQUOR';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            // Bill Number Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "#$billNo",
                style: const TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Table ID
            Text(
              "TABLE NO - $tableId",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.deepOrange),
            ),
            const SizedBox(width: 8),

            if (isManualLiq)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(3)),
                child: const Text("MRP LIQUOR", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
              ),

            const Spacer(),

            // Date & Exact DB Time
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Grand Total Amount
            Text(
              "₹${grandTotal.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
            ),
          ],
        ),
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: const Color(0xFF1E293B),
                  child: const Row(
                    children: [
                      Expanded(flex: 5, child: Text("ITEM PARTICULARS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("CATEGORY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

                // Table Items List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
                    final double amount = double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
                    final int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                    final String cat = item['category_type']?.toString().toUpperCase() ?? 'FOOD';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: cat == 'LIQUOR' ? Colors.purple : Colors.deepOrange,
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 1, child: Text("x$qty", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text("₹${price.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                          Expanded(flex: 2, child: Text("₹${amount.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Bill Bottom Summary Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Food: ₹${foodTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          const SizedBox(width: 12),
                          Text("Liquor: ₹${liquorTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                      Text("Net Total: ₹${grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}