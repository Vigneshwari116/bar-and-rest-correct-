/*
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import 'audit_pdf_printer.dart';

class ReportDashboardPage extends StatelessWidget {
  const ReportDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBloc()..add(LoadReportDataEvent()),
      child: const ReportDashboardView(),
    );
  }
}

class ReportDashboardView extends StatefulWidget {
  const ReportDashboardView({super.key});

  @override
  State<ReportDashboardView> createState() => _ReportDashboardPageState();
}

class _ReportDashboardPageState extends State<ReportDashboardView> {
  static const double compactRowHeight = 30.0;
  static const TextStyle cellTextBold = TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A));
  static const TextStyle cellTextNormal = TextStyle(fontSize: 11.0, color: Color(0xFF334155), fontWeight: FontWeight.w600);

  int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  final List<String> _months = [
    "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
    "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
  ];
  String? _selectedWaiterId;

  Future<void> _showResetConfirmationDialog(BuildContext context) async {
    final reportBloc = context.read<ReportBloc>();
    final TextEditingController confirmCodeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: screenWidth > 500 ? 440 : screenWidth * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "END OF DAY WIPE RESET",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure you want to trigger EOD Reset?\nThis will clear all running live tracking ledgers and reset bill numbers for the next business day. Manual entries and Excise records remain 100% secure.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),

                // 🔒 SECURITY CONFIRMATION CODE INPUT
                const Text(
                  "TYPE SECURITY CODE TO RESET",
                  style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: confirmCodeController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    cursorColor: const Color(0xFF00BCD4),
                    decoration: InputDecoration(
                      hintText: "Enter SECURITY CODE",
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () async {
                        final String inputCode = confirmCodeController.text.trim();

                        // 🔒 CHECK CONFIRMATION CODE
                        if (inputCode != "AAA@UP") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("❌ Invalid Security Code! Type 'AAA@UP' exactly to proceed."),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        try {
                          final ApiClient client = GetIt.I<ApiClient>();
                          final response = await client.post('/api/v1/reports/daily-reset');

                          if (response != null && response.data['status'] == 'SUCCESS') {
                            reportBloc.add(LoadReportDataEvent());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("System Reset Successful. Live ledger wiped."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            final String errorMsg = response?.data['message'] ?? "Cannot reset system. Pending orders are running!";
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("⚠️ $errorMsg"),
                                  backgroundColor: Colors.orange.shade800,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("⚠️ Cannot reset: Open/Pending orders detected on tables!"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text("YES, WIPE SYSTEM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeHardwareAbstractPrint(
      ReportState state, double liq, double fod, double soft, double oth, double grand) async {
    final String dateStr = DateFormat('dd-MM-yyyy').format(state.startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(state.endDate);

    try {
      final pdf = pw.Document();

      // 🌟 FIX: Roll80 Format set kiya gaya hai taaki paper ulta/rotated na chhappe
      final pageFormat = PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min, // 👈 Strict vertical orientation
              children: [
                pw.Center(
                  child: pw.Text("ABSTRACT REPORT", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text("DATE: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),

                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2),
                    1: pw.FlexColumnWidth(1.8),
                    2: pw.FlexColumnWidth(2.0),
                    3: pw.FlexColumnWidth(2.0),
                    4: pw.FlexColumnWidth(2.0),
                    5: pw.FlexColumnWidth(2.0),
                    6: pw.FlexColumnWidth(2.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                      children: [
                        pw.Text("BILL", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("TAB", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("LIQ", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("FOD", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("SOF", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("OTH", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("TOTAL", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ],
                    ),
                    ...state.reportData.map((item) {
                      final String bNo = (item['bill_no'] ?? '0').toString();
                      final String tId = (item['table_id'] ?? '1A').toString().toUpperCase();
                      final double lVal = double.tryParse(item['liquor_total']?.toString() ?? '0') ?? 0.0;
                      final double fVal = double.tryParse(item['food_total']?.toString() ?? '0') ?? 0.0;
                      final double sVal = double.tryParse(item['soft_total']?.toString() ?? '0') ?? 0.0;
                      final double oVal = double.tryParse(item['others_total']?.toString() ?? '0') ?? 0.0;
                      final double subVal = double.tryParse(item['grand_total']?.toString() ?? '0') ?? 0.0;

                      return pw.TableRow(
                        children: [
                          pw.Text(bNo, style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(tId, style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(lVal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(fVal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(sVal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(oVal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(subVal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),

                _buildThermalSummaryRow("LIQUOR TOTAL:", liq),
                _buildThermalSummaryRow("FOOD TOTAL:", fod),
                _buildThermalSummaryRow("SOFT DRINKS:", soft),
                _buildThermalSummaryRow("OTHERS TOTAL:", oth),
                pw.Divider(thickness: 1.2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("GRAND TOTAL:", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Rs. ${grand.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 1.2),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text("*** END OF ABSTRACT ***", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      await _handleCrossPlatformPdfOutput(bytes, "Abstract_Report_$dateStr");
    } catch (e, stack) {
      dev.log("🔴 [EXCEPTION IN ABSTRACT PRINT]: $e", name: "PRINT_ENGINE", error: e, stackTrace: stack);
    }
  }

  pw.Widget _buildThermalSummaryRow(String label, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text("Rs. ${amount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

// 🌟 SALES SLIP (FONT SIZES INCREASED FOR BETTER READABILITY)
  Future<void> _executeHardwareSalesPrint(
      ReportState state, Map<String, List<dynamic>> groupedData, double grandTotal) async {
    final String dateStr = DateFormat('dd-MM-yyyy').format(state.startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(state.endDate);

    try {
      final pdf = pw.Document();

      final pageFormat = PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 3 * PdfPageFormat.mm,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            final List<pw.Widget> widgets = [];

            // Header (Bada Font Size)
            widgets.add(pw.Center(child: pw.Text("DAILY SALES REPORT", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))));
            widgets.add(pw.SizedBox(height: 2));
            widgets.add(pw.Center(child: pw.Text("DATE: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))));
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Divider(thickness: 1));

            for (var entry in groupedData.entries) {
              double categorySum = entry.value.fold(
                  0.0, (sum, item) => sum + (double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0));

              // Category Box Title (Font size 9.5)
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  color: PdfColors.grey300,
                  child: pw.Text("CATEGORY: ${entry.key}", style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                ),
              );
              widgets.add(pw.SizedBox(height: 3));

              // Items List Table (Font size 8.5)
              widgets.add(
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(6),
                    1: pw.FlexColumnWidth(2),
                    2: pw.FlexColumnWidth(3),
                  },
                  children: entry.value.map((item) {
                    final String name = (item['item_name'] ?? '').toString().toUpperCase();
                    final String qty = (item['sold_qty'] ?? '0').toString();
                    final double revVal = double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text("x$qty", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text("Rs.${revVal.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );

              widgets.add(pw.SizedBox(height: 3));
              widgets.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("SUBTOTAL:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Rs. ${categorySum.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(pw.Divider(thickness: 0.8));
            }

            // Grand Total (Bada Aur Bold Font)
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("GRAND TOTAL REVENUE:", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            );
            widgets.add(pw.Divider(thickness: 1.2));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Center(child: pw.Text("*** END OF SALES REPORT ***", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))));

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: widgets,
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      await _handleCrossPlatformPdfOutput(bytes, "Sales_Report_$dateStr");
    } catch (e, stack) {
      dev.log("🔴 [EXCEPTION IN SALES PRINT]: $e", name: "PRINT_ENGINE", error: e, stackTrace: stack);
    }
  }

  Future<void> _handleCrossPlatformPdfOutput(Uint8List bytes, String filename) async {
    try {
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
          format: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        );
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File("${tempDir.path}\\$filename.pdf");
        await file.writeAsBytes(bytes, flush: true);

        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else {
          await Printing.layoutPdf(
            onLayout: (format) async => bytes,
            name: filename,
            format: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
          );
        }
      } else {
        await Printing.sharePdf(bytes: bytes, filename: "$filename.pdf");
      }
    } catch (e) {
      await Printing.sharePdf(bytes: bytes, filename: "$filename.pdf");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        final bool isAuditTab = state.activeReport == PosReportType.liquorAudit ||
            state.activeReport == PosReportType.foodAudit ||
            state.activeReport == PosReportType.waiterPerformance;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 700;

            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F172A),
                elevation: 0,
                toolbarHeight: isMobile ? 84 : 52,
                titleSpacing: 12,
                title: isMobile
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF00BCD4), size: 16),
                        SizedBox(width: 6),
                        Text("SVENSKA LEDGER ENGINE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildHeaderToggleButton(context, state, PosReportType.dailySales, "DAILY SALES"),
                          _buildHeaderToggleButton(context, state, PosReportType.billwiseAbstract, "ABSTRACT"),
                          _buildHeaderToggleButton(context, state, PosReportType.foodAudit, "FOOD AUDIT"),
                          _buildHeaderToggleButton(context, state, PosReportType.liquorAudit, "LIQUOR AUDIT"),
                          _buildHeaderToggleButton(context, state, PosReportType.waiterPerformance, "WAITER REPORT"),
                          _buildHeaderToggleButton(context, state, PosReportType.deletedItemsAudit, "DELETED AUDIT"),
                        ],
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF00BCD4), size: 18),
                        SizedBox(width: 8),
                        Text("SVENSKA LEDGER ENGINE", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              _buildHeaderToggleButton(context, state, PosReportType.dailySales, "DAILY SALES REPORT"),
                              _buildHeaderToggleButton(context, state, PosReportType.billwiseAbstract, "BILL WISE ABSTRACT"),
                              _buildHeaderToggleButton(context, state, PosReportType.foodAudit, "FOOD AUDIT"),
                              _buildHeaderToggleButton(context, state, PosReportType.liquorAudit, "LIQUOR AUDIT"),
                              _buildHeaderToggleButton(context, state, PosReportType.waiterPerformance, "WAITER PERFORMANCE"),
                              _buildHeaderToggleButton(context, state, PosReportType.deletedItemsAudit, "DELETED AUDIT"),

                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.published_with_changes_rounded, color: Colors.redAccent, size: 20),
                    tooltip: "End of Day Reset",
                    onPressed: () => _showResetConfirmationDialog(context),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (isAuditTab)
                    Container(
                      color: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: isMobile
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip("TODAY", () {
                                  final now = DateTime.now();
                                  context.read<ReportBloc>().add(ChangeDateRangeEvent(now, now));
                                }),
                                const SizedBox(width: 6),
                                _buildFilterChip("CUSTOM DATE", () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: state.startDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(picked, picked));
                                  }
                                }),
                                const SizedBox(width: 6),
                                _buildFilterChip("DATE RANGE", () async {
                                  final picked = await showDialog<DateTimeRange>(
                                    context: context,
                                    builder: (BuildContext ctx) {
                                      return Dialog(
                                        backgroundColor: const Color(0xFF0F172A),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        child: SizedBox(
                                          width: 340,
                                          height: 480,
                                          child: Theme(
                                            data: ThemeData.dark().copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF00BCD4),
                                                onPrimary: Colors.white,
                                                surface: Color(0xFF1E293B),
                                                onSurface: Colors.white,
                                              ),
                                            ),
                                            child: DateRangePickerDialog(
                                              initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime(2035),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                  if (picked != null) {
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(picked.start, picked.end));
                                  }
                                }),
                                const SizedBox(width: 6),
                                _buildHistoryButton(() {
                                  final start = DateTime(2024, 1, 1);
                                  final end = DateTime.now();
                                  context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedMonth,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_months[index]))),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedMonth = val);
                                        final start = DateTime(_selectedYear, val, 1);
                                        final end = DateTime(_selectedYear, val + 1, 0);
                                        context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                "${DateFormat('dd/MM/yy').format(state.startDate)} - ${DateFormat('dd/MM/yy').format(state.endDate)}",
                                style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        ],
                      )
                          : Row(
                        children: [
                          _buildFilterChip("TODAY", () {
                            final now = DateTime.now();
                            context.read<ReportBloc>().add(ChangeDateRangeEvent(now, now));
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("CUSTOM DATE", () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: state.startDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              context.read<ReportBloc>().add(ChangeDateRangeEvent(picked, picked));
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("DATE RANGE", () async {
                            final picked = await showDialog<DateTimeRange>(
                              context: context,
                              builder: (BuildContext ctx) {
                                return Dialog(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  child: SizedBox(
                                    width: 380,
                                    height: 520,
                                    child: Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: Color(0xFF00BCD4),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF1E293B),
                                          onSurface: Colors.white,
                                        ),
                                      ),
                                      child: DateRangePickerDialog(
                                        initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2035),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );

                            if (picked != null) {
                              context.read<ReportBloc>().add(ChangeDateRangeEvent(picked.start, picked.end));
                            }
                          }),
                          const SizedBox(width: 12),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMonth,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_months[index]))),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMonth = val);
                                    final start = DateTime(_selectedYear, val, 1);
                                    final end = DateTime(_selectedYear, val + 1, 0);
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildHistoryButton(() {
                            final start = DateTime(2024, 1, 1);
                            final end = DateTime.now();
                            context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                          }),
                          const Spacer(),
                          Text(
                            "FILTER: ${DateFormat('dd/MM/yyyy').format(state.startDate)} - ${DateFormat('dd/MM/yyyy').format(state.endDate)}",
                            style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 16, 0, isMobile ? 8 : 16, isMobile ? 8 : 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: state.status == ReportStatus.loading
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BCD4)))
                            : _renderActiveReportEngine(state, isMobile),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistoryButton(VoidCallback onTap) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.history_rounded, size: 13, color: Colors.white),
        label: const Text("SHOW ALL HISTORY", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
      ),
    );
  }

  Widget _buildHeaderToggleButton(BuildContext ctx, ReportState state, PosReportType type, String label) {
    final bool isSelected = state.activeReport == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMonth = DateTime.now().month;
          _selectedWaiterId = null;
        });
        ctx.read<ReportBloc>().add(ChangeReportTypeEvent(type));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _renderActiveReportEngine(ReportState state, bool isMobile) {
    if (state.reportData.isEmpty) {
      return Center(child: Text("No records found for selection date bounds.", style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)));
    }
    switch (state.activeReport) {
      case PosReportType.dailySales:
        return _buildDailySalesReportView(state, isMobile);
      case PosReportType.billwiseAbstract:
        return _buildBillwiseAbstractView(state, isMobile);
      case PosReportType.foodAudit:
        return _buildFoodAuditView(state, isMobile);
      case PosReportType.liquorAudit:
        return _buildLiquorAuditView(state, isMobile);
      case PosReportType.waiterPerformance:
        return _buildWaiterPerformanceView(state, isMobile);
      case PosReportType.deletedItemsAudit:
        return _buildDeletedItemsAuditView(state, isMobile);
    }
  }


  // 🌟 TAB 6: DELETED ITEMS AUDIT VIEW
  Widget _buildDeletedItemsAuditView(ReportState state, bool isMobile) {
    double totalDeletedAmount = 0.0;
    int totalDeletedQty = 0;

    for (var item in state.reportData) {
      totalDeletedAmount += double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
      totalDeletedQty += int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFFFF1F2),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFFECDD3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DELETED ITEMS AUDIT LOG",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF9F1239), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | TOTAL DELETED QTY: $totalDeletedQty",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF9F1239), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "TOTAL LOST: ₹${totalDeletedAmount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF881337),
            child: const Row(
              children: [
                SizedBox(width: 55, child: Text("TABLE", style: TextStyle(color: Color(0xFFFECDD3), fontSize: 9.5, fontWeight: FontWeight.bold))),
                SizedBox(width: 50, child: Text("EMP", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("ITEM DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("DELETED AT", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFFFE4E6)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final String tableId = (item['table_id'] ?? 'N/A').toString().toUpperCase();
                final String empId = (item['employee_id'] ?? '1').toString();
                final String itemName = (item['item_name'] ?? '').toString().toUpperCase();
                final int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                final double amount = double.tryParse(item['amount']?.toString() ?? '0') ?? (price * qty);
                final String deletedAtRaw = item['deleted_at']?.toString() ?? '';

                String formattedTime = 'N/A';
                if (deletedAtRaw.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(deletedAtRaw);
                    formattedTime = DateFormat('dd/MM hh:mm a').format(dt);
                  } catch (_) {
                    formattedTime = deletedAtRaw;
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 55, child: Text(tableId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)))),
                      SizedBox(width: 50, child: Text("ID:$empId", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 5, child: Text(itemName, style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("x$qty", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 2, child: Text("₹${price.toStringAsFixed(0)}", textAlign: TextAlign.right, style: cellTextNormal)),
                      Expanded(flex: 3, child: Text("₹${amount.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                      Expanded(flex: 3, child: Text(formattedTime, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4)))),
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

  // 🌟 TAB 5: WAITER PERFORMANCE VIEW
  Widget _buildWaiterPerformanceView(ReportState state, bool isMobile) {
    final List<dynamic> foodOnlyData = state.reportData.where((item) {
      final String catType = (item['category_type'] ?? item['cat_type'] ?? 'FOOD').toString().toUpperCase();
      final bool isManual = (item['is_manual'] == 1 || item['is_manual'] == true);
      return (catType == 'FOOD' || catType.contains('FOOD')) && !isManual;
    }).toList();

    final Map<String, String> waitersMap = {};
    for (var item in foodOnlyData) {
      final String empId = (item['employee_id'] ?? item['emp_id'] ?? '1').toString();
      final String empName = (item['employee_id'] ?? item['emp_id'] ?? 'WAITER #$empId').toString().toUpperCase();
      waitersMap[empId] = empName;
    }

    if (_selectedWaiterId == null && waitersMap.isNotEmpty) {
      _selectedWaiterId = waitersMap.keys.first;
    }

    final List<dynamic> selectedWaiterOrders = foodOnlyData.where((item) {
      final String empId = (item['employee_id'] ?? item['emp_id'] ?? '1').toString();
      return _selectedWaiterId == null || empId == _selectedWaiterId;
    }).toList();

    double waiterTotalFoodSales = 0.0;
    int waiterTotalItemsQty = 0;

    for (var item in selectedWaiterOrders) {
      waiterTotalFoodSales += double.tryParse(item['amount']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
      waiterTotalItemsQty += int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: isMobile
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_rounded, color: Color(0xFF00BCD4), size: 18),
                    const SizedBox(width: 6),
                    const Text("WAITER:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedWaiterId,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            isExpanded: true,
                            items: waitersMap.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text("ID: ${e.key}", overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedWaiterId = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("QTY: $waiterTotalItemsQty UNITS", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    Text("TOTAL: ₹${waiterTotalFoodSales.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                  ],
                )
              ],
            )
                : Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFF00BCD4), size: 22),
                const SizedBox(width: 8),
                const Text("SELECT WAITER:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(width: 10),

                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWaiterId,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      items: waitersMap.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text("ID: ${e.key}"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedWaiterId = val);
                      },
                    ),
                  ),
                ),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: Row(
                    children: [
                      const Text("FOOD QTY: ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text("$waiterTotalItemsQty UNITS", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Text("TOTAL SALES: ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("₹${waiterTotalFoodSales.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                SizedBox(width: 65, child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
                SizedBox(width: 55, child: Text("TABLE", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("PARTICULARS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: selectedWaiterOrders.isEmpty
                ? const Center(child: Text("No Food Sales records found for this Waiter.", style: TextStyle(fontSize: 11, color: Colors.grey)))
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: selectedWaiterOrders.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = selectedWaiterOrders[idx];
                final bool isEven = idx % 2 == 0;

                final String billNo = (item['bill_no'] ?? 'N/A').toString();
                final String tableId = (item['table_id'] ?? '1A').toString().toUpperCase();
                final String itemName = (item['particulars'] ?? item['item_name'] ?? '').toString().toUpperCase();
                final int qty = int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
                final double rate = double.tryParse(item['rate']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
                final double amount = double.tryParse(item['amount']?.toString() ?? (rate * qty).toString()) ?? (rate * qty);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 65, child: Text("#$billNo", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      SizedBox(width: 55, child: Text(tableId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                      Expanded(flex: 5, child: Text(itemName, style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("x$qty", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 3, child: Text("₹${amount.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: isMobile
                ? Column(
              children: [
                Text(
                  "PERFORMANCE: ₹${waiterTotalFoodSales.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                    label: const Text("PRINT INCENTIVE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    onPressed: () {
                      _printWaiterIncentiveSlip(
                        waiterName: waitersMap[_selectedWaiterId] ?? 'WAITER',
                        waiterId: _selectedWaiterId ?? '1',
                        orders: selectedWaiterOrders,
                        totalSales: waiterTotalFoodSales,
                        totalQty: waiterTotalItemsQty,
                        startDate: state.startDate,
                        endDate: state.endDate,
                      );
                    },
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WAITER: ${waitersMap[_selectedWaiterId] ?? 'N/A'}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "PERFORMANCE VOLUME: ₹${waiterTotalFoodSales.toStringAsFixed(2)} (ELIGIBLE FOR FOOD INCENTIVE)",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    icon: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
                    label: const Text("PRINT WAITER INCENTIVE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      _printWaiterIncentiveSlip(
                        waiterName: waitersMap[_selectedWaiterId] ?? 'WAITER',
                        waiterId: _selectedWaiterId ?? '1',
                        orders: selectedWaiterOrders,
                        totalSales: waiterTotalFoodSales,
                        totalQty: waiterTotalItemsQty,
                        startDate: state.startDate,
                        endDate: state.endDate,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printWaiterIncentiveSlip({
    required String waiterName,
    required String waiterId,
    required List<dynamic> orders,
    required double totalSales,
    required int totalQty,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(endDate);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text("SVENSKA RESTAURANT & BAR", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 1),
              pw.Center(child: pw.Text("--- WAITER PERFORMANCE SLIP ---", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 2),
              pw.Text("WAITER: $waiterName (ID: $waiterId)", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text("PERIOD: $dateStr TO $toDateStr", style: const pw.TextStyle(fontSize: 6.5)),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(5.0),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text("ITEM", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text("QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text("AMT", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...orders.map((item) {
                    final String name = (item['particulars'] ?? item['item_name'] ?? 'ITEM').toString().toUpperCase();
                    final int qty = int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
                    final double rate = double.tryParse(item['rate']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
                    final double amt = double.tryParse(item['amount']?.toString() ?? (rate * qty).toString()) ?? (rate * qty);

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(name, style: const pw.TextStyle(fontSize: 6.5), softWrap: true),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Text(amt.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL FOOD QTY:", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text("$totalQty UNITS", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL FOOD SALES:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. ${totalSales.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 6),
              pw.Center(child: pw.Text("*** INCENTIVE BASE SLIP ***", style: const pw.TextStyle(fontSize: 6.5))),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _handleCrossPlatformPdfOutput(bytes, "Performance_${waiterId}_$dateStr");
  }

  // 🌟 TAB 1: DAILY SALES REPORT VIEW
  Widget _buildDailySalesReportView1(ReportState state, bool isMobile) {
    final Map<String, List<dynamic>> groupedData = {};
    for (var item in state.reportData) {
      String sectionHeader = 'FOOD';
      final String currentCatName = item['category_name']?.toString().toUpperCase() ?? '';
      final String currentCatType = item['category_type']?.toString().toUpperCase() ?? '';
      final String itemName = item['item_name']?.toString().toUpperCase() ?? '';

      if (currentCatName == 'M' || (currentCatType == 'LIQUOR' && currentCatName != 'COD' && currentCatName != 'CIG')) {
        sectionHeader = 'LIQUOR';
      } else if (currentCatName == 'COD' || itemName.contains('SODA') || itemName.contains('WATER')) {
        sectionHeader = 'COLD DRINKS';
      } else if (currentCatName == 'CIG' || currentCatName.contains('CIGRATE') || currentCatName == 'K' || itemName == 'GLASS' || itemName == 'CONTAINER') {
        sectionHeader = 'OTHERS';
      }

      if (!groupedData.containsKey(sectionHeader)) groupedData[sectionHeader] = [];
      groupedData[sectionHeader]!.add(item);
    }

    final String dateStr = DateFormat('dd-MM-yyyy').format(state.startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(state.endDate);

    double dailyReportGrandTotal = 0.0;
    for (var list in groupedData.values) {
      for (var item in list) {
        dailyReportGrandTotal += double.tryParse(item['total_revenue']?.toString() ?? '0.0') ?? 0.0;
      }
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DAILY SALES BREAKDOWN",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "AUDIT: $dateStr TO $toDateStr",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "TOTAL: ₹${dailyReportGrandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                Expanded(flex: 6, child: Text("ITEM DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              itemCount: groupedData.entries.length,
              itemBuilder: (context, entryIdx) {
                final entry = groupedData.entries.elementAt(entryIdx);
                double categorySum = entry.value.fold(
                  0.0,
                      (sum, item) => sum + (double.tryParse(item['total_revenue'].toString()) ?? 0.0),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: const Color(0xFFF1F5F9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            Text("Subtotal: ₹${categorySum.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entry.value.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, itemIdx) {
                          final item = entry.value[itemIdx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(flex: 6, child: Text(item['item_name'].toString().toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Expanded(flex: 2, child: Text("x${item['sold_qty']}", textAlign: TextAlign.center, style: cellTextBold)),
                                Expanded(flex: 3, child: Text("₹${double.parse(item['total_revenue'].toString()).toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: isMobile
                ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                    onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                    icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                    label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                    icon: const Icon(Icons.analytics_rounded, size: 14, color: Colors.white),
                    label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                      onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                      onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                      icon: const Icon(Icons.analytics_rounded, size: 16, color: Colors.white),
                      label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesReportView(ReportState state, bool isMobile) {
    final Map<String, List<dynamic>> groupedData = {};

    for (var item in state.reportData) {
      final String currentCatType = item['category_type']?.toString().toUpperCase().trim() ?? '';
      final String currentCatName = item['category_name']?.toString().toUpperCase().trim() ?? '';
      final String itemName = item['item_name']?.toString().toUpperCase().trim() ?? '';

      String sectionHeader = 'FOOD';

      // 🎯 PRIORITY 1: COLD DRINKS & BEVERAGES (Water, Soda, Soft Drinks, K, COLD)
      if (currentCatType == 'COLD DRINKS' ||
          currentCatName == 'COLD' ||
          currentCatName == 'K' ||
          currentCatName == 'MILK' ||
          itemName.contains('WATER') ||
          itemName.contains('SODA') ||
          itemName.contains('SOFT DRINKS')) {
        sectionHeader = 'COLD DRINKS & BEVERAGES';
      }
      // 🎯 PRIORITY 2: OTHERS (C, CA, Cigarettes, Glasses, Containers)
      else if (currentCatName == 'CA' ||
          currentCatName == 'CIG' ||
          currentCatName.contains('CIGRATE') ||
          itemName == 'C' ||
          itemName.contains('GLASS') ||
          itemName.contains('CONTAINER')) {
        sectionHeader = 'OTHERS';
      }
      // 🎯 PRIORITY 3: BEER
      else if (currentCatName == 'BEER' ||
          itemName.contains('BEER') ||
          itemName.contains('KF STRONG') ||
          itemName.contains('BUDWEISER') ||
          itemName.contains('TUBORG') ||
          itemName.contains('CARLSBERG')) {
        sectionHeader = 'BEER';
      }
      // 🎯 PRIORITY 4: PURE LIQUOR (Whisky, Scotch, Rum, Vodka, Wine, Gin, Brandy, Bacardi)
      else if (currentCatType == 'LIQUOR' ||
          currentCatName == 'WHISKY' ||
          currentCatName == 'SCOTCH' ||
          currentCatName == 'RUM' ||
          currentCatName == 'VODKA' ||
          currentCatName == 'WINE' ||
          currentCatName == 'GIN' ||
          currentCatName == 'BRANDY' ||
          currentCatName == 'BACARDI') {
        sectionHeader = 'LIQUOR';
      }
      // 🎯 PRIORITY 5: PURE FOOD
      else {
        sectionHeader = 'FOOD';
      }

      if (!groupedData.containsKey(sectionHeader)) {
        groupedData[sectionHeader] = [];
      }
      groupedData[sectionHeader]!.add(item);
    }

    final String dateStr = DateFormat('dd-MM-yyyy').format(state.startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(state.endDate);

    double dailyReportGrandTotal = 0.0;
    for (var list in groupedData.values) {
      for (var item in list) {
        dailyReportGrandTotal += double.tryParse(item['total_revenue']?.toString() ?? '0.0') ?? 0.0;
      }
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DAILY SALES BREAKDOWN",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "AUDIT: $dateStr TO $toDateStr",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "TOTAL: ₹${dailyReportGrandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                Expanded(flex: 6, child: Text("ITEM DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              itemCount: groupedData.entries.length,
              itemBuilder: (context, entryIdx) {
                final entry = groupedData.entries.elementAt(entryIdx);
                final String categoryTitle = entry.key;

                double categorySum = entry.value.fold(
                  0.0,
                      (sum, item) => sum + (double.tryParse(item['total_revenue'].toString()) ?? 0.0),
                );

                // Section Header Styling
                Color headerBgColor = const Color(0xFFF1F5F9);
                Color headerTextColor = const Color(0xFF0F172A);

                if (categoryTitle == 'LIQUOR') {
                  headerBgColor = const Color(0xFFF3E8FF);
                  headerTextColor = const Color(0xFF581C87);
                } else if (categoryTitle == 'BEER') {
                  headerBgColor = const Color(0xFFFEF3C7);
                  headerTextColor = const Color(0xFFB45309);
                } else if (categoryTitle == 'COLD DRINKS & BEVERAGES') {
                  headerBgColor = const Color(0xFFE0F2FE);
                  headerTextColor = const Color(0xFF0369A1);
                } else if (categoryTitle == 'FOOD') {
                  headerBgColor = const Color(0xFFFFEDD5);
                  headerTextColor = const Color(0xFFC2410C);
                } else if (categoryTitle == 'OTHERS') {
                  headerBgColor = const Color(0xFFE2E8F0);
                  headerTextColor = const Color(0xFF334155);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: headerBgColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                categoryTitle,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: headerTextColor)
                            ),
                            Text("Subtotal: ₹${categorySum.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entry.value.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, itemIdx) {
                          final item = entry.value[itemIdx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(flex: 6, child: Text(item['item_name'].toString().toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Expanded(flex: 2, child: Text("x${item['sold_qty']}", textAlign: TextAlign.center, style: cellTextBold)),
                                Expanded(flex: 3, child: Text("₹${double.parse(item['total_revenue'].toString()).toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: isMobile
                ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                    onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                    icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                    label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                    icon: const Icon(Icons.analytics_rounded, size: 14, color: Colors.white),
                    label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                      onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                      onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                      icon: const Icon(Icons.analytics_rounded, size: 16, color: Colors.white),
                      label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // 🌟 TAB 2: BILLWISE ABSTRACT VIEW (STRICT 1 ROW PER BILL NUMBER)
  Widget _buildBillwiseAbstractView(ReportState state, bool isMobile) {
    double totalLiquor = 0.0;
    double totalFood = 0.0;
    double totalSoft = 0.0;
    double totalOthers = 0.0;
    double overallGrandTotal = 0.0;

    for (var item in state.reportData) {
      totalLiquor += double.tryParse(item['liquor_total']?.toString() ?? '0.0') ?? 0.0;
      totalFood += double.tryParse(item['food_total']?.toString() ?? '0.0') ?? 0.0;
      totalSoft += double.tryParse(item['soft_total']?.toString() ?? '0.0') ?? 0.0;
      totalOthers += double.tryParse(item['others_total']?.toString() ?? '0.0') ?? 0.0;
      overallGrandTotal += double.tryParse(item['grand_total']?.toString() ?? '0.0') ?? 0.0;
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: isMobile ? 650 : MediaQuery.of(context).size.width - 240),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 32,
                    horizontalMargin: 12,
                    columnSpacing: isMobile ? 12 : 20,
                    showBottomBorder: true,
                    columns: const [
                      DataColumn(label: Text("BILL", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("TABLE", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("LIQUOR", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("FOOD", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("SOFT DRINKS", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("OTHERS", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("SUBTOTAL", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("GRAND TOTAL", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.w900)), numeric: true),
                    ],
                    rows: state.reportData.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final item = entry.value;
                      final bool isPending = item['bill_no'].toString().toUpperCase().contains('PENDING');

                      final double lVal = double.tryParse(item['liquor_total']?.toString() ?? '0.0') ?? 0.0;
                      final double fVal = double.tryParse(item['food_total']?.toString() ?? '0.0') ?? 0.0;
                      final double sVal = double.tryParse(item['soft_total']?.toString() ?? '0.0') ?? 0.0;
                      final double oVal = double.tryParse(item['others_total']?.toString() ?? '0.0') ?? 0.0;

                      final double subTotalSum = lVal + fVal + sVal + oVal;
                      final double grandTotalVal = double.tryParse(item['grand_total']?.toString() ?? '0.0') ?? subTotalSum;

                      return DataRow(
                        color: WidgetStateProperty.all(
                          isPending ? const Color(0xFFFEF2F2) : (index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
                        ),
                        cells: [
                          DataCell(Text(
                            isPending ? "PENDING" : item['bill_no'].toString(),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPending ? const Color(0xFFE11D48) : const Color(0xFF0F172A)),
                          )),
                          DataCell(Text("${item['table_id']}", style: cellTextNormal)),
                          DataCell(Text("₹${lVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${fVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${sVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${oVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${subTotalSum.toStringAsFixed(2)}", style: cellTextNormal)),
                          DataCell(Text("₹${grandTotalVal.toStringAsFixed(2)}", style: cellTextBold)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
            ),
            child: Column(
              children: [
                if (isMobile) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactFooterMetric("LIQ", totalLiquor),
                      _buildCompactFooterMetric("FOOD", totalFood),
                      _buildCompactFooterMetric("SOFT", totalSoft),
                      _buildCompactFooterMetric("OTH", totalOthers),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("GRAND TOTAL:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      Text("₹${overallGrandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                    ],
                  )
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactFooterMetric("LIQUOR TOTAL", totalLiquor),
                      _buildCompactFooterMetric("FOOD TOTAL", totalFood),
                      _buildCompactFooterMetric("SOFT DRINKS", totalSoft),
                      _buildCompactFooterMetric("OTHERS TOTAL", totalOthers),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("GRAND TOTAL COLLECTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text("₹${overallGrandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                        ],
                      )
                    ],
                  ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(color: Color(0xFFE2E8F0))),
                isMobile
                    ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                        onPressed: () => _executeHardwareAbstractPrint(state, totalLiquor, totalFood, totalSoft, totalOthers, overallGrandTotal),
                        icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                        label: const Text("PRINT ABSTRACT ROLL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                        onPressed: () => _openTableWiseDetailsModal(context, state),
                        icon: const Icon(Icons.preview_rounded, size: 14, color: Colors.white),
                        label: const Text("PREVIEW DATA BREAKDOWN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                          onPressed: () => _executeHardwareAbstractPrint(state, totalLiquor, totalFood, totalSoft, totalOthers, overallGrandTotal),
                          icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                          label: const Text("PRINT ABSTRACT ROLL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                          onPressed: () => _openTableWiseDetailsModal(context, state),
                          icon: const Icon(Icons.preview_rounded, size: 14, color: Colors.white),
                          label: const Text("PREVIEW DATA BREAKDOWN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCompactFooterMetric(String title, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 1),
        Text("₹${val.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  void _openSalesGridDetailedPopupModal(BuildContext context, ReportState state) {
    final Map<String, List<dynamic>> groupedData = {};
    for (var item in state.reportData) {
      String cat = item['category_type']?.toString().toUpperCase() ?? 'FOOD';
      if (!groupedData.containsKey(cat)) groupedData[cat] = [];
      groupedData[cat]!.add(item);
    }

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: screenWidth > 600 ? 520 : screenWidth * 0.92,
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("DAILY SALES ANALYSIS GRID", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: groupedData.entries.map((entry) {
                        double categorySum = entry.value.fold(0.0, (sum, item) => sum + (double.tryParse(item['total_revenue'].toString()) ?? 0.0));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              child: Text(entry.key, style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(6),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(3),
                              },
                              children: entry.value.map((item) {
                                return TableRow(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5))),
                                  children: [
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text(item['item_name'].toString().toUpperCase(), style: cellTextNormal)),
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text(item['sold_qty'].toString(), style: cellTextNormal, textAlign: TextAlign.center)),
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text("₹${double.parse(item['total_revenue'].toString()).toStringAsFixed(2)}", style: cellTextNormal, textAlign: TextAlign.right)),
                                  ],
                                );
                              }).toList(),
                            ),
                            Container(
                              height: compactRowHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              color: const Color(0xFFF8FAFC),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("TOTAL ${entry.key}:", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  Text("₹${categorySum.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTableWiseDetailsModal(BuildContext context, ReportState state) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: screenWidth > 650 ? 560 : screenWidth * 0.92,
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("BILL ABSTRACT BREAKDOWN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.reportData.length,
                    itemBuilder: (context, idx) {
                      final item = state.reportData[idx];
                      final List<dynamic> servedItems = item['items_served'] ?? [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              color: const Color(0xFF0F172A),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("BILL NO: ${item['bill_no']}", style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(2)),
                                    child: Text("TABLE: ${item['table_id']}".toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(6),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(3),
                                },
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1.2))),
                                    children: [
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("ITEM", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("QTY", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("RATE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("AMOUNT", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                                    ],
                                  ),
                                  ...servedItems.map((subItem) {
                                    return TableRow(
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8))),
                                      children: [
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(subItem['name'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(subItem['qty'].toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF334155)), textAlign: TextAlign.center)),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(double.parse(subItem['price'].toString()).toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: Color(0xFF334155)), textAlign: TextAlign.right)),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text("₹${double.parse(subItem['total'].toString()).toStringAsFixed(2)}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.right)),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              color: const Color(0xFFF8FAFC),
                              child: Column(
                                children: [
                                  _buildBillFooterSplitRow("LIQUOR TOTAL:", double.parse(item['liquor_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("FOOD TOTAL:", double.parse(item['food_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("SOFT DRINKS TOTAL:", double.parse(item['soft_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("OTHERS TOTAL:", double.parse(item['others_total'].toString())),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: Divider(color: Color(0xFFCBD5E1), thickness: 0.8)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("GRAND TOTAL:", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                      Text("₹${double.parse(item['grand_total'].toString()).toStringAsFixed(2)}", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillFooterSplitRow(String label, double val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        Text(val > 0 ? "₹${val.toStringAsFixed(2)}" : "0.00", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: val > 0 ? const Color(0xFF1E293B) : Colors.grey.shade400)),
      ],
    );
  }

  // 🌟 TAB 3: PROFESSIONAL FOOD AUDIT VIEW
  Widget _buildFoodAuditView(ReportState state, bool isMobile) {
    double totalFoodRevenue = 0.0;
    int totalFoodUnits = 0;

    for (var item in state.reportData) {
      totalFoodRevenue += double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      totalFoodUnits += int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FOOD AUDIT LEDGER MATRIX",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | UNITS: $totalFoodUnits",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "TOTAL: ₹${totalFoodRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                SizedBox(width: 60, child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("PARTICULARS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final double rateVal = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                final double amountVal = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final int unitVal = int.tryParse(item['unit']?.toString() ?? '0') ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 60, child: Text("#${item['bill_no'] ?? ''}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      Expanded(flex: 5, child: Text("${item['particulars'] ?? ''}".toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("₹${rateVal.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextNormal)),
                      Expanded(flex: 2, child: Text("x$unitVal", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 3, child: Text("₹${amountVal.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT A4 FOOD AUDIT REPORT (PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printFoodAuditReport(
                    rawRows: List<Map<String, dynamic>>.from(state.reportData),
                    startDate: state.startDate,
                    endDate: state.endDate,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  // 🌟 TAB 4: LIQUOR AUDIT VIEW
  Widget _buildLiquorAuditView1(ReportState state, bool isMobile) {
    double totalLiquorRevenue = 0.0;
    int totalLiquorUnits = 0;

    for (var item in state.reportData) {
      totalLiquorRevenue += double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      totalLiquorUnits += int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFFAF5FF),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LIQUOR AUDIT SUMMARY REPORT",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF581C87), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "BRANDS: ${state.reportData.length} | UNITS: $totalLiquorUnits",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF581C87),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "EXCISE: ₹${totalLiquorRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF3B0764),
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text("PARTICULARS", style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("UNITS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF3E8FF)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final double totalAmt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final int totalUnits = int.tryParse(item['unit']?.toString() ?? '0') ?? 0;

                final double unitPrice = item['rate'] != null
                    ? (double.tryParse(item['rate'].toString()) ?? 0.0)
                    : (totalUnits > 0 ? (totalAmt / totalUnits) : 0.0);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          "${item['particulars']}".toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B0764)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "₹${unitPrice.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "$totalUnits U",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B21A8)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          "₹${totalAmt.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E22CE),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT A4 LIQUOR AUDIT REPORT (PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printLiquorAuditReport(
                    rawRows: List<Map<String, dynamic>>.from(state.reportData),
                    startDate: state.startDate,
                    endDate: state.endDate,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }


  // 🌟 TAB 4: LIQUOR AUDIT VIEW (WITH BILL NO COLUMN)
  Widget _buildLiquorAuditView(ReportState state, bool isMobile) {
    double totalLiquorRevenue = 0.0;
    int totalLiquorUnits = 0;

    for (var item in state.reportData) {
      totalLiquorRevenue += double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      totalLiquorUnits += int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFFAF5FF),
      child: Column(
        children: [
          // Header Total Summary Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LIQUOR AUDIT SUMMARY REPORT",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF581C87), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | UNITS: $totalLiquorUnits",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF581C87),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "EXCISE: ₹${totalLiquorRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 PURPLE TABLE HEADER WITH DEDICATED BILL NO COLUMN
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF3B0764),
            child: const Row(
              children: [
                SizedBox(
                    width: 65,
                    child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 5,
                    child: Text("PARTICULARS", style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 2,
                    child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 2,
                    child: Text("UNITS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 3,
                    child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),

          // 🌟 DATA LIST
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF3E8FF)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                // ⚡ DYNAMIC BILL NO RESOLVER
                final String billNo = (item['bill_no'] ?? item['excise_bill_no'] ?? 'N/A').toString();
                final double totalAmt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final int totalUnits = int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
                final double rateVal = double.tryParse(item['rate']?.toString() ?? '0') ?? (totalUnits > 0 ? totalAmt / totalUnits : 0.0);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      // 🌟 1. EXCISE BILL NO COLUMN (#5000, #5001...)
                      SizedBox(
                        width: 65,
                        child: Text(
                          billNo != 'N/A' ? "#$billNo" : "N/A",
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4)),
                        ),
                      ),
                      // 🌟 2. BRAND PARTICULARS
                      Expanded(
                        flex: 5,
                        child: Text(
                          "${item['particulars']}".toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B0764)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 🌟 3. RATE
                      Expanded(
                        flex: 2,
                        child: Text(
                          "₹${rateVal.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      // 🌟 4. UNITS (COMBINED e.g. 1 U, 3 U)
                      Expanded(
                        flex: 2,
                        child: Text(
                          "$totalUnits U",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B21A8)),
                        ),
                      ),
                      // 🌟 5. TOTAL REVENUE
                      Expanded(
                        flex: 3,
                        child: Text(
                          "₹${totalAmt.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer Print PDF Button
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E22CE),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT A4 LIQUOR AUDIT REPORT (PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printLiquorAuditReport(
                    rawRows: List<Map<String, dynamic>>.from(state.reportData),
                    startDate: state.startDate,
                    endDate: state.endDate,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}*/


import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import 'audit_pdf_printer.dart';

class ReportDashboardPage extends StatelessWidget {
  const ReportDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBloc()..add(LoadReportDataEvent()),
      child: const ReportDashboardView(),
    );
  }
}

class ReportDashboardView extends StatefulWidget {
  const ReportDashboardView({super.key});

  @override
  State<ReportDashboardView> createState() => _ReportDashboardPageState();
}

class _ReportDashboardPageState extends State<ReportDashboardView> {
  static const double compactRowHeight = 30.0;
  static const TextStyle cellTextBold = TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A));
  static const TextStyle cellTextNormal = TextStyle(fontSize: 11.0, color: Color(0xFF334155), fontWeight: FontWeight.w600);

  int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  final List<String> _months = [
    "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
    "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
  ];
  String? _selectedWaiterId;

  Future<void> _showResetConfirmationDialog(BuildContext context) async {
    final reportBloc = context.read<ReportBloc>();
    final TextEditingController confirmCodeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: screenWidth > 500 ? 440 : screenWidth * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "END OF DAY WIPE RESET",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure you want to trigger EOD Reset?\nThis will clear all running live tracking ledgers and reset bill numbers for the next business day. Manual entries and Excise records remain 100% secure.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),

                const Text(
                  "TYPE SECURITY CODE TO RESET",
                  style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: confirmCodeController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    cursorColor: const Color(0xFF00BCD4),
                    decoration: InputDecoration(
                      hintText: "Enter SECURITY CODE",
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () async {
                        final String inputCode = confirmCodeController.text.trim();

                        if (inputCode != "AAA@UP") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("❌ Invalid Security Code! Type 'AAA@UP' exactly to proceed."),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        try {
                          final ApiClient client = GetIt.I<ApiClient>();
                          final response = await client.post('/api/v1/reports/daily-reset');

                          if (response != null && response.data['status'] == 'SUCCESS') {
                            reportBloc.add(LoadReportDataEvent());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("System Reset Successful. Live ledger wiped."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            final String errorMsg = response?.data['message'] ?? "Cannot reset system. Pending orders are running!";
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("⚠️ $errorMsg"),
                                  backgroundColor: Colors.orange.shade800,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("⚠️ Cannot reset: Open/Pending orders detected on tables!"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text("YES, WIPE SYSTEM", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }


  void _executeHardwareSalesPrint(
      ReportState state, Map<String, List<dynamic>> groupedData, double grandTotal) {
    AuditPdfPrinter.printDailySalesReport(
      groupedData: groupedData,
      grandTotal: grandTotal,
      startDate: state.startDate,
      endDate: state.endDate,
      dbPrinters: state.printers,
    );
  }

  // 🌟 2. CLEAN HANDLER: BILLWISE ABSTRACT HARDWARE PRINT
  void _executeHardwareAbstractPrint(
      ReportState state, double liq, double fod, double soft, double oth, double grand) {
    AuditPdfPrinter.printBillwiseAbstractReport(
      reportData: state.reportData,
      totalLiquor: liq,
      totalFood: fod,
      totalSoft: soft,
      totalOthers: oth,
      grandTotal: grand,
      startDate: state.startDate,
      endDate: state.endDate,
      dbPrinters: state.printers,
    );
  }





  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        final bool isAuditTab = state.activeReport == PosReportType.liquorAudit ||
            state.activeReport == PosReportType.foodAudit ||
            state.activeReport == PosReportType.waiterPerformance;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 700;

            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F172A),
                elevation: 0,
                toolbarHeight: isMobile ? 84 : 52,
                titleSpacing: 12,
                title: isMobile
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF00BCD4), size: 16),
                        SizedBox(width: 6),
                        Text("SVENSKA LEDGER ENGINE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildHeaderToggleButton(context, state, PosReportType.dailySales, "DAILY SALES"),
                          _buildHeaderToggleButton(context, state, PosReportType.billwiseAbstract, "ABSTRACT"),
                          _buildHeaderToggleButton(context, state, PosReportType.foodAudit, "FOOD AUDIT"),
                          _buildHeaderToggleButton(context, state, PosReportType.liquorAudit, "LIQUOR AUDIT"),
                          _buildHeaderToggleButton(context, state, PosReportType.waiterPerformance, "WAITER REPORT"),
                          _buildHeaderToggleButton(context, state, PosReportType.deletedItemsAudit, "DELETED AUDIT"),
                        ],
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF00BCD4), size: 18),
                        SizedBox(width: 8),
                        Text("SVENSKA LEDGER ENGINE", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              _buildHeaderToggleButton(context, state, PosReportType.dailySales, "DAILY SALES REPORT"),
                              _buildHeaderToggleButton(context, state, PosReportType.billwiseAbstract, "BILL WISE ABSTRACT"),
                              _buildHeaderToggleButton(context, state, PosReportType.foodAudit, "FOOD AUDIT"),
                              _buildHeaderToggleButton(context, state, PosReportType.liquorAudit, "LIQUOR AUDIT"),
                              _buildHeaderToggleButton(context, state, PosReportType.waiterPerformance, "WAITER PERFORMANCE"),
                              _buildHeaderToggleButton(context, state, PosReportType.deletedItemsAudit, "DELETED AUDIT"),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.published_with_changes_rounded, color: Colors.redAccent, size: 20),
                    tooltip: "End of Day Reset",
                    onPressed: () => _showResetConfirmationDialog(context),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (isAuditTab)
                    Container(
                      color: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: isMobile
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip("TODAY", () {
                                  final now = DateTime.now();
                                  context.read<ReportBloc>().add(ChangeDateRangeEvent(now, now));
                                }),
                                const SizedBox(width: 6),
                                _buildFilterChip("CUSTOM DATE", () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: state.startDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(picked, picked));
                                  }
                                }),
                                const SizedBox(width: 6),
                                _buildFilterChip("DATE RANGE", () async {
                                  final picked = await showDialog<DateTimeRange>(
                                    context: context,
                                    builder: (BuildContext ctx) {
                                      return Dialog(
                                        backgroundColor: const Color(0xFF0F172A),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        child: SizedBox(
                                          width: 340,
                                          height: 480,
                                          child: Theme(
                                            data: ThemeData.dark().copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF00BCD4),
                                                onPrimary: Colors.white,
                                                surface: Color(0xFF1E293B),
                                                onSurface: Colors.white,
                                              ),
                                            ),
                                            child: DateRangePickerDialog(
                                              initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime(2035),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                  if (picked != null) {
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(picked.start, picked.end));
                                  }
                                }),
                                const SizedBox(width: 6),
                                _buildHistoryButton(() {
                                  final start = DateTime(2024, 1, 1);
                                  final end = DateTime.now();
                                  context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedMonth,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_months[index]))),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedMonth = val);
                                        final start = DateTime(_selectedYear, val, 1);
                                        final end = DateTime(_selectedYear, val + 1, 0);
                                        context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                "${DateFormat('dd/MM/yy').format(state.startDate)} - ${DateFormat('dd/MM/yy').format(state.endDate)}",
                                style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        ],
                      )
                          : Row(
                        children: [
                          _buildFilterChip("TODAY", () {
                            final now = DateTime.now();
                            context.read<ReportBloc>().add(ChangeDateRangeEvent(now, now));
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("CUSTOM DATE", () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: state.startDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              context.read<ReportBloc>().add(ChangeDateRangeEvent(picked, picked));
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("DATE RANGE", () async {
                            final picked = await showDialog<DateTimeRange>(
                              context: context,
                              builder: (BuildContext ctx) {
                                return Dialog(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  child: SizedBox(
                                    width: 380,
                                    height: 520,
                                    child: Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: Color(0xFF00BCD4),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF1E293B),
                                          onSurface: Colors.white,
                                        ),
                                      ),
                                      child: DateRangePickerDialog(
                                        initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2035),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );

                            if (picked != null) {
                              context.read<ReportBloc>().add(ChangeDateRangeEvent(picked.start, picked.end));
                            }
                          }),
                          const SizedBox(width: 12),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMonth,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(_months[index]))),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMonth = val);
                                    final start = DateTime(_selectedYear, val, 1);
                                    final end = DateTime(_selectedYear, val + 1, 0);
                                    context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildHistoryButton(() {
                            final start = DateTime(2024, 1, 1);
                            final end = DateTime.now();
                            context.read<ReportBloc>().add(ChangeDateRangeEvent(start, end));
                          }),
                          const Spacer(),
                          Text(
                            "FILTER: ${DateFormat('dd/MM/yyyy').format(state.startDate)} - ${DateFormat('dd/MM/yyyy').format(state.endDate)}",
                            style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 16, 0, isMobile ? 8 : 16, isMobile ? 8 : 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: state.status == ReportStatus.loading
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BCD4)))
                            : _renderActiveReportEngine(state, isMobile),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistoryButton(VoidCallback onTap) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.history_rounded, size: 13, color: Colors.white),
        label: const Text("SHOW ALL HISTORY", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
      ),
    );
  }

  Widget _buildHeaderToggleButton(BuildContext ctx, ReportState state, PosReportType type, String label) {
    final bool isSelected = state.activeReport == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMonth = DateTime.now().month;
          _selectedWaiterId = null;
        });
        ctx.read<ReportBloc>().add(ChangeReportTypeEvent(type));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _renderActiveReportEngine(ReportState state, bool isMobile) {
    if (state.reportData.isEmpty) {
      return Center(child: Text("No records found for selection date bounds.", style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)));
    }
    switch (state.activeReport) {
      case PosReportType.dailySales:
        return _buildDailySalesReportView(state, isMobile);
      case PosReportType.billwiseAbstract:
        return _buildBillwiseAbstractView(state, isMobile);
      case PosReportType.foodAudit:
        return _buildFoodAuditView(state, isMobile);
      case PosReportType.liquorAudit:
        return _buildLiquorAuditView(state, isMobile);
      case PosReportType.waiterPerformance:
        return _buildWaiterPerformanceView(state, isMobile);
      case PosReportType.deletedItemsAudit:
        return _buildDeletedItemsAuditView(state, isMobile);
    }
  }

  // 🌟 TAB 6: DELETED ITEMS AUDIT VIEW (WITH THERMAL / FALLBACK PDF PRINT)
  Widget _buildDeletedItemsAuditView(ReportState state, bool isMobile) {
    double totalDeletedAmount = 0.0;
    int totalDeletedQty = 0;

    for (var item in state.reportData) {
      totalDeletedAmount += double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
      totalDeletedQty += int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFFFF1F2),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFFECDD3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DELETED ITEMS AUDIT LOG",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF9F1239), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | TOTAL DELETED QTY: $totalDeletedQty",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF9F1239), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "TOTAL LOST: ₹${totalDeletedAmount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF881337),
            child: const Row(
              children: [
                SizedBox(width: 55, child: Text("TABLE", style: TextStyle(color: Color(0xFFFECDD3), fontSize: 9.5, fontWeight: FontWeight.bold))),
                SizedBox(width: 50, child: Text("EMP", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("ITEM DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("DELETED AT", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFFFE4E6)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final String tableId = (item['table_id'] ?? 'N/A').toString().toUpperCase();
                final String empId = (item['employee_id'] ?? '1').toString();
                final String itemName = (item['item_name'] ?? '').toString().toUpperCase();
                final int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                final double amount = double.tryParse(item['amount']?.toString() ?? '0') ?? (price * qty);
                final String deletedAtRaw = item['deleted_at']?.toString() ?? '';

                String formattedTime = 'N/A';
                if (deletedAtRaw.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(deletedAtRaw);
                    formattedTime = DateFormat('dd/MM hh:mm a').format(dt);
                  } catch (_) {
                    formattedTime = deletedAtRaw;
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 55, child: Text(tableId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)))),
                      SizedBox(width: 50, child: Text("ID:$empId", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 5, child: Text(itemName, style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("x$qty", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 2, child: Text("₹${price.toStringAsFixed(0)}", textAlign: TextAlign.right, style: cellTextNormal)),
                      Expanded(flex: 3, child: Text("₹${amount.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                      Expanded(flex: 3, child: Text(formattedTime, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4)))),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFFECDD3))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF881337),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT DELETED AUDIT SLIP (THERMAL ROLL / PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printDeletedAuditSlip(
                    rows: state.reportData,
                    startDate: state.startDate,
                    endDate: state.endDate,
                    dbPrinters: state.printers,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  // 🌟 TAB 5: WAITER PERFORMANCE VIEW
  Widget _buildWaiterPerformanceView(ReportState state, bool isMobile) {
    final List<dynamic> foodOnlyData = state.reportData.where((item) {
      final String catType = (item['category_type'] ?? item['cat_type'] ?? 'FOOD').toString().toUpperCase();
      final bool isManual = (item['is_manual'] == 1 || item['is_manual'] == true);
      return (catType == 'FOOD' || catType.contains('FOOD')) && !isManual;
    }).toList();

    final Map<String, String> waitersMap = {};
    for (var item in foodOnlyData) {
      final String empId = (item['employee_id'] ?? item['emp_id'] ?? '1').toString();
      final String empName = (item['employee_id'] ?? item['emp_id'] ?? 'WAITER #$empId').toString().toUpperCase();
      waitersMap[empId] = empName;
    }

    if (_selectedWaiterId == null && waitersMap.isNotEmpty) {
      _selectedWaiterId = waitersMap.keys.first;
    }

    final List<dynamic> selectedWaiterOrders = foodOnlyData.where((item) {
      final String empId = (item['employee_id'] ?? item['emp_id'] ?? '1').toString();
      return _selectedWaiterId == null || empId == _selectedWaiterId;
    }).toList();

    double waiterTotalFoodSales = 0.0;
    int waiterTotalItemsQty = 0;

    for (var item in selectedWaiterOrders) {
      waiterTotalFoodSales += double.tryParse(item['amount']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
      waiterTotalItemsQty += int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: isMobile
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_rounded, color: Color(0xFF00BCD4), size: 18),
                    const SizedBox(width: 6),
                    const Text("WAITER:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedWaiterId,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            isExpanded: true,
                            items: waitersMap.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text("ID: ${e.key}", overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedWaiterId = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("QTY: $waiterTotalItemsQty UNITS", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    Text("TOTAL: ₹${waiterTotalFoodSales.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                  ],
                )
              ],
            )
                : Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFF00BCD4), size: 22),
                const SizedBox(width: 8),
                const Text("SELECT WAITER:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(width: 10),

                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWaiterId,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      items: waitersMap.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text("ID: ${e.key}"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedWaiterId = val);
                      },
                    ),
                  ),
                ),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: Row(
                    children: [
                      const Text("FOOD QTY: ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text("$waiterTotalItemsQty UNITS", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Text("TOTAL SALES: ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("₹${waiterTotalFoodSales.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                SizedBox(width: 65, child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
                SizedBox(width: 55, child: Text("TABLE", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("PARTICULARS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: selectedWaiterOrders.isEmpty
                ? const Center(child: Text("No Food Sales records found for this Waiter.", style: TextStyle(fontSize: 11, color: Colors.grey)))
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: selectedWaiterOrders.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = selectedWaiterOrders[idx];
                final bool isEven = idx % 2 == 0;

                final String billNo = (item['bill_no'] ?? 'N/A').toString();
                final String tableId = (item['table_id'] ?? '1A').toString().toUpperCase();
                final String itemName = (item['particulars'] ?? item['item_name'] ?? '').toString().toUpperCase();
                final int qty = int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
                final double rate = double.tryParse(item['rate']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
                final double amount = double.tryParse(item['amount']?.toString() ?? (rate * qty).toString()) ?? (rate * qty);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 65, child: Text("#$billNo", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      SizedBox(width: 55, child: Text(tableId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                      Expanded(flex: 5, child: Text(itemName, style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("x$qty", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 3, child: Text("₹${amount.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: isMobile
                ? Column(
              children: [
                Text(
                  "PERFORMANCE: ₹${waiterTotalFoodSales.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                    label: const Text("PRINT INCENTIVE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    onPressed: () {
                      AuditPdfPrinter.printWaiterIncentiveSlip(
                        waiterName: waitersMap[_selectedWaiterId] ?? 'WAITER',
                        waiterId: _selectedWaiterId ?? '1',
                        orders: selectedWaiterOrders,
                        totalSales: waiterTotalFoodSales,
                        totalQty: waiterTotalItemsQty,
                        startDate: state.startDate,
                        endDate: state.endDate,
                        dbPrinters: state.printers, // 👈 Printers list pass ho jayegi
                      );
                    },
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WAITER: ${waitersMap[_selectedWaiterId] ?? 'N/A'}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "PERFORMANCE VOLUME: ₹${waiterTotalFoodSales.toStringAsFixed(2)} (ELIGIBLE FOR FOOD INCENTIVE)",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    icon: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
                    label: const Text("PRINT WAITER INCENTIVE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      AuditPdfPrinter.printWaiterIncentiveSlip(
                        waiterName: waitersMap[_selectedWaiterId] ?? 'WAITER',
                        waiterId: _selectedWaiterId ?? '1',
                        orders: selectedWaiterOrders,
                        totalSales: waiterTotalFoodSales,
                        totalQty: waiterTotalItemsQty,
                        startDate: state.startDate,
                        endDate: state.endDate,
                        dbPrinters: state.printers, // 👈 Printers list pass ho jayegi
                      );
                    },                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // 🌟 TAB 1: DAILY SALES REPORT VIEW
  Widget _buildDailySalesReportView(ReportState state, bool isMobile) {
    // 🌟 Auto-Merge duplicate items per section using Map
    final Map<String, Map<String, Map<String, dynamic>>> sectionItemMap = {};

    for (var rawItem in state.reportData) {
      final String currentCatType = rawItem['category_type']?.toString().toUpperCase().trim() ?? '';
      final String currentCatName = rawItem['category_name']?.toString().toUpperCase().trim() ?? '';
      final String itemName = rawItem['item_name']?.toString().toUpperCase().trim() ?? '';
      final int qty = int.tryParse(rawItem['sold_qty']?.toString() ?? '1') ?? 1;
      final double rev = double.tryParse(rawItem['total_revenue']?.toString() ?? '0.0') ?? 0.0;

      String sectionHeader = 'FOOD';

      if (currentCatType == 'COLD DRINKS' ||
          currentCatName == 'COLD' ||
          currentCatName == 'K' ||
          currentCatName == 'MILK' ||
          itemName.contains('WATER') ||
          itemName.contains('SODA') ||
          itemName.contains('SOFT DRINKS')) {
        sectionHeader = 'COLD DRINKS & BEVERAGES';
      } else if (currentCatName == 'CA' ||
          currentCatName == 'CIG' ||
          currentCatName.contains('CIGRATE') ||
          itemName == 'C' ||
          itemName.contains('GLASS') ||
          itemName.contains('CONTAINER')) {
        sectionHeader = 'OTHERS';
      } else if (currentCatName == 'BEER' ||
          itemName.contains('BEER') ||
          itemName.contains('KF STRONG') ||
          itemName.contains('BUDWEISER') ||
          itemName.contains('TUBORG') ||
          itemName.contains('CARLSBERG')) {
        sectionHeader = 'BEER';
      } else if (currentCatType == 'LIQUOR' ||
          currentCatName == 'WHISKY' ||
          currentCatName == 'SCOTCH' ||
          currentCatName == 'RUM' ||
          currentCatName == 'VODKA' ||
          currentCatName == 'WINE' ||
          currentCatName == 'GIN' ||
          currentCatName == 'BRANDY' ||
          currentCatName == 'BACARDI') {
        sectionHeader = 'LIQUOR';
      } else {
        sectionHeader = 'FOOD';
      }

      if (!sectionItemMap.containsKey(sectionHeader)) {
        sectionItemMap[sectionHeader] = {};
      }

      // 🌟 IF ITEM ALREADY EXISTS IN SECTION -> MERGE QTY & REVENUE
      if (sectionItemMap[sectionHeader]!.containsKey(itemName)) {
        final existing = sectionItemMap[sectionHeader]![itemName]!;
        existing['sold_qty'] = (existing['sold_qty'] as int) + qty;
        existing['total_revenue'] = (existing['total_revenue'] as double) + rev;
      } else {
        sectionItemMap[sectionHeader]![itemName] = {
          'item_name': itemName,
          'category_type': currentCatType,
          'category_name': currentCatName,
          'sold_qty': qty,
          'total_revenue': rev,
        };
      }
    }

    // Convert Map back to List format for rendering
    final Map<String, List<dynamic>> groupedData = {};
    for (var entry in sectionItemMap.entries) {
      groupedData[entry.key] = entry.value.values.toList();
    }

    final String dateStr = DateFormat('dd-MM-yyyy').format(state.startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(state.endDate);

    double dailyReportGrandTotal = 0.0;
    for (var list in groupedData.values) {
      for (var item in list) {
        dailyReportGrandTotal += double.tryParse(item['total_revenue']?.toString() ?? '0.0') ?? 0.0;
      }
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DAILY SALES BREAKDOWN",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "AUDIT: $dateStr TO $toDateStr",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "TOTAL: ₹${dailyReportGrandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                Expanded(flex: 6, child: Text("ITEM DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              itemCount: groupedData.entries.length,
              itemBuilder: (context, entryIdx) {
                final entry = groupedData.entries.elementAt(entryIdx);
                final String categoryTitle = entry.key;

                double categorySum = entry.value.fold(
                  0.0,
                      (sum, item) => sum + (double.tryParse(item['total_revenue'].toString()) ?? 0.0),
                );

                Color headerBgColor = const Color(0xFFF1F5F9);
                Color headerTextColor = const Color(0xFF0F172A);

                if (categoryTitle == 'LIQUOR') {
                  headerBgColor = const Color(0xFFF3E8FF);
                  headerTextColor = const Color(0xFF581C87);
                } else if (categoryTitle == 'BEER') {
                  headerBgColor = const Color(0xFFFEF3C7);
                  headerTextColor = const Color(0xFFB45309);
                } else if (categoryTitle == 'COLD DRINKS & BEVERAGES') {
                  headerBgColor = const Color(0xFFE0F2FE);
                  headerTextColor = const Color(0xFF0369A1);
                } else if (categoryTitle == 'FOOD') {
                  headerBgColor = const Color(0xFFFFEDD5);
                  headerTextColor = const Color(0xFFC2410C);
                } else if (categoryTitle == 'OTHERS') {
                  headerBgColor = const Color(0xFFE2E8F0);
                  headerTextColor = const Color(0xFF334155);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: headerBgColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              categoryTitle,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: headerTextColor),
                            ),
                            Text("Subtotal: ₹${categorySum.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entry.value.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, itemIdx) {
                          final item = entry.value[itemIdx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(flex: 6, child: Text(item['item_name'].toString().toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Expanded(flex: 2, child: Text("x${item['sold_qty']}", textAlign: TextAlign.center, style: cellTextBold)),
                                Expanded(flex: 3, child: Text("₹${double.parse(item['total_revenue'].toString()).toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: isMobile
                ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                    onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                    icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                    label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                    onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                    icon: const Icon(Icons.analytics_rounded, size: 14, color: Colors.white),
                    label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                      onPressed: () => _executeHardwareSalesPrint(state, groupedData, dailyReportGrandTotal),
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text("PRINT SALES SLIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                      onPressed: () => _openSalesGridDetailedPopupModal(context, state),
                      icon: const Icon(Icons.analytics_rounded, size: 16, color: Colors.white),
                      label: const Text("PREVIEW TABULAR GRID", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // 🌟 TAB 2: BILLWISE ABSTRACT VIEW
  Widget _buildBillwiseAbstractView(ReportState state, bool isMobile) {
    double totalLiquor = 0.0;
    double totalFood = 0.0;
    double totalSoft = 0.0;
    double totalOthers = 0.0;
    double overallGrandTotal = 0.0;

    for (var item in state.reportData) {
      totalLiquor += double.tryParse(item['liquor_total']?.toString() ?? '0.0') ?? 0.0;
      totalFood += double.tryParse(item['food_total']?.toString() ?? '0.0') ?? 0.0;
      totalSoft += double.tryParse(item['soft_total']?.toString() ?? '0.0') ?? 0.0;
      totalOthers += double.tryParse(item['others_total']?.toString() ?? '0.0') ?? 0.0;
      overallGrandTotal += double.tryParse(item['grand_total']?.toString() ?? '0.0') ?? 0.0;
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: isMobile ? 650 : MediaQuery.of(context).size.width - 240),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 32,
                    horizontalMargin: 12,
                    columnSpacing: isMobile ? 12 : 20,
                    showBottomBorder: true,
                    columns: const [
                      DataColumn(label: Text("BILL", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("TABLE", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("LIQUOR", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("FOOD", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("SOFT DRINKS", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("OTHERS", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("SUBTOTAL", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text("GRAND TOTAL", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.w900)), numeric: true),
                    ],
                    rows: state.reportData.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final item = entry.value;
                      final bool isPending = item['bill_no'].toString().toUpperCase().contains('PENDING');

                      final double lVal = double.tryParse(item['liquor_total']?.toString() ?? '0.0') ?? 0.0;
                      final double fVal = double.tryParse(item['food_total']?.toString() ?? '0.0') ?? 0.0;
                      final double sVal = double.tryParse(item['soft_total']?.toString() ?? '0.0') ?? 0.0;
                      final double oVal = double.tryParse(item['others_total']?.toString() ?? '0.0') ?? 0.0;

                      final double subTotalSum = lVal + fVal + sVal + oVal;
                      final double grandTotalVal = double.tryParse(item['grand_total']?.toString() ?? '0.0') ?? subTotalSum;

                      return DataRow(
                        color: WidgetStateProperty.all(
                          isPending ? const Color(0xFFFEF2F2) : (index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
                        ),
                        cells: [
                          DataCell(Text(
                            isPending ? "PENDING" : item['bill_no'].toString(),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPending ? const Color(0xFFE11D48) : const Color(0xFF0F172A)),
                          )),
                          DataCell(Text("${item['table_id']}", style: cellTextNormal)),
                          DataCell(Text("₹${lVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${fVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${sVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${oVal.toStringAsFixed(0)}", style: cellTextNormal)),
                          DataCell(Text("₹${subTotalSum.toStringAsFixed(2)}", style: cellTextNormal)),
                          DataCell(Text("₹${grandTotalVal.toStringAsFixed(2)}", style: cellTextBold)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
            ),
            child: Column(
              children: [
                if (isMobile) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactFooterMetric("LIQ", totalLiquor),
                      _buildCompactFooterMetric("FOOD", totalFood),
                      _buildCompactFooterMetric("SOFT", totalSoft),
                      _buildCompactFooterMetric("OTH", totalOthers),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("GRAND TOTAL:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      Text("₹${overallGrandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                    ],
                  )
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCompactFooterMetric("LIQUOR TOTAL", totalLiquor),
                      _buildCompactFooterMetric("FOOD TOTAL", totalFood),
                      _buildCompactFooterMetric("SOFT DRINKS", totalSoft),
                      _buildCompactFooterMetric("OTHERS TOTAL", totalOthers),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("GRAND TOTAL COLLECTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text("₹${overallGrandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                        ],
                      )
                    ],
                  ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(color: Color(0xFFE2E8F0))),
                isMobile
                    ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                        onPressed: () => _executeHardwareAbstractPrint(state, totalLiquor, totalFood, totalSoft, totalOthers, overallGrandTotal),
                        icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                        label: const Text("PRINT ABSTRACT ROLL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                        onPressed: () => _openTableWiseDetailsModal(context, state),
                        icon: const Icon(Icons.preview_rounded, size: 14, color: Colors.white),
                        label: const Text("PREVIEW DATA BREAKDOWN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0),
                          onPressed: () => _executeHardwareAbstractPrint(state, totalLiquor, totalFood, totalSoft, totalOthers, overallGrandTotal),
                          icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                          label: const Text("PRINT ABSTRACT ROLL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), elevation: 0),
                          onPressed: () => _openTableWiseDetailsModal(context, state),
                          icon: const Icon(Icons.preview_rounded, size: 14, color: Colors.white),
                          label: const Text("PREVIEW DATA BREAKDOWN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCompactFooterMetric(String title, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 1),
        Text("₹${val.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  void _openSalesGridDetailedPopupModal(BuildContext context, ReportState state) {
    final Map<String, List<dynamic>> groupedData = {};
    for (var item in state.reportData) {
      String cat = item['category_type']?.toString().toUpperCase() ?? 'FOOD';
      if (!groupedData.containsKey(cat)) groupedData[cat] = [];
      groupedData[cat]!.add(item);
    }

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: screenWidth > 600 ? 520 : screenWidth * 0.92,
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("DAILY SALES ANALYSIS GRID", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: groupedData.entries.map((entry) {
                        double categorySum = entry.value.fold(0.0, (sum, item) => sum + (double.tryParse(item['total_revenue'].toString()) ?? 0.0));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              child: Text(entry.key, style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(6),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(3),
                              },
                              children: entry.value.map((item) {
                                return TableRow(
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5))),
                                  children: [
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text(item['item_name'].toString().toUpperCase(), style: cellTextNormal)),
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text(item['sold_qty'].toString(), style: cellTextNormal, textAlign: TextAlign.center)),
                                    Padding(padding: const EdgeInsets.all(6.0), child: Text("₹${double.parse(item['total_revenue'].toString()).toStringAsFixed(2)}", style: cellTextNormal, textAlign: TextAlign.right)),
                                  ],
                                );
                              }).toList(),
                            ),
                            Container(
                              height: compactRowHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              color: const Color(0xFFF8FAFC),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("TOTAL ${entry.key}:", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  Text("₹${categorySum.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTableWiseDetailsModal(BuildContext context, ReportState state) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: screenWidth > 650 ? 560 : screenWidth * 0.92,
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("BILL ABSTRACT BREAKDOWN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.reportData.length,
                    itemBuilder: (context, idx) {
                      final item = state.reportData[idx];
                      final List<dynamic> servedItems = item['items_served'] ?? [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              color: const Color(0xFF0F172A),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("BILL NO: ${item['bill_no']}", style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(2)),
                                    child: Text("TABLE: ${item['table_id']}".toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(6),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(3),
                                },
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1.2))),
                                    children: [
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("ITEM", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("QTY", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("RATE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                                      Padding(padding: EdgeInsets.only(bottom: 4), child: Text("AMOUNT", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                                    ],
                                  ),
                                  ...servedItems.map((subItem) {
                                    return TableRow(
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8))),
                                      children: [
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(subItem['name'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(subItem['qty'].toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF334155)), textAlign: TextAlign.center)),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(double.parse(subItem['price'].toString()).toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: Color(0xFF334155)), textAlign: TextAlign.right)),
                                        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text("₹${double.parse(subItem['total'].toString()).toStringAsFixed(2)}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.right)),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              color: const Color(0xFFF8FAFC),
                              child: Column(
                                children: [
                                  _buildBillFooterSplitRow("LIQUOR TOTAL:", double.parse(item['liquor_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("FOOD TOTAL:", double.parse(item['food_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("SOFT DRINKS TOTAL:", double.parse(item['soft_total'].toString())),
                                  const SizedBox(height: 2),
                                  _buildBillFooterSplitRow("OTHERS TOTAL:", double.parse(item['others_total'].toString())),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: Divider(color: Color(0xFFCBD5E1), thickness: 0.8)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("GRAND TOTAL:", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                      Text("₹${double.parse(item['grand_total'].toString()).toStringAsFixed(2)}", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillFooterSplitRow(String label, double val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        Text(val > 0 ? "₹${val.toStringAsFixed(2)}" : "0.00", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: val > 0 ? const Color(0xFF1E293B) : Colors.grey.shade400)),
      ],
    );
  }

  // 🌟 TAB 3: PROFESSIONAL FOOD AUDIT VIEW
  Widget _buildFoodAuditView(ReportState state, bool isMobile) {
    double totalFoodRevenue = 0.0;
    int totalFoodUnits = 0;

    for (var item in state.reportData) {
      totalFoodRevenue += double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      totalFoodUnits += int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FOOD AUDIT LEDGER MATRIX",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | UNITS: $totalFoodUnits",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "TOTAL: ₹${totalFoodRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF1E293B),
            child: const Row(
              children: [
                SizedBox(width: 60, child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("PARTICULARS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final double rateVal = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                final double amountVal = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final int unitVal = int.tryParse(item['unit']?.toString() ?? '0') ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 60, child: Text("#${item['bill_no'] ?? ''}", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      Expanded(flex: 5, child: Text("${item['particulars'] ?? ''}".toUpperCase(), style: cellTextNormal, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text("₹${rateVal.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextNormal)),
                      Expanded(flex: 2, child: Text("x$unitVal", textAlign: TextAlign.center, style: cellTextBold)),
                      Expanded(flex: 3, child: Text("₹${amountVal.toStringAsFixed(2)}", textAlign: TextAlign.right, style: cellTextBold)),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT A4 FOOD AUDIT REPORT (PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printFoodAuditReport(
                    rawRows: List<Map<String, dynamic>>.from(state.reportData),
                    startDate: state.startDate,
                    endDate: state.endDate,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  // 🌟 TAB 4: LIQUOR AUDIT VIEW (WITH BILL NO COLUMN)
  Widget _buildLiquorAuditView(ReportState state, bool isMobile) {
    double totalLiquorRevenue = 0.0;
    int totalLiquorUnits = 0;

    for (var item in state.reportData) {
      totalLiquorRevenue += double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      totalLiquorUnits += int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
    }

    return Container(
      color: const Color(0xFFFAF5FF),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LIQUOR AUDIT SUMMARY REPORT",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF581C87), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RECORDS: ${state.reportData.length} | UNITS: $totalLiquorUnits",
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF581C87),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "EXCISE: ₹${totalLiquorRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            color: const Color(0xFF3B0764),
            child: const Row(
              children: [
                SizedBox(
                    width: 65,
                    child: Text("BILL NO", style: TextStyle(color: Color(0xFF00BCD4), fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 5,
                    child: Text("PARTICULARS", style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 2,
                    child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 2,
                    child: Text("UNITS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
                Expanded(
                    flex: 3,
                    child: Text("REVENUE", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.reportData.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF3E8FF)),
              itemBuilder: (ctx, idx) {
                final item = state.reportData[idx];
                final bool isEven = idx % 2 == 0;

                final String billNo = (item['bill_no'] ?? item['excise_bill_no'] ?? 'N/A').toString();
                final double totalAmt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final int totalUnits = int.tryParse(item['unit']?.toString() ?? '0') ?? 0;
                final double rateVal = double.tryParse(item['rate']?.toString() ?? '0') ?? (totalUnits > 0 ? totalAmt / totalUnits : 0.0);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 65,
                        child: Text(
                          billNo != 'N/A' ? "#$billNo" : "N/A",
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4)),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          "${item['particulars']}".toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B0764)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "₹${rateVal.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "$totalUnits U",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B21A8)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          "₹${totalAmt.toStringAsFixed(2)}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE9D5FF))),
            ),
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E22CE),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                label: const Text(
                  "PRINT A4 LIQUOR AUDIT REPORT (PDF)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                ),
                onPressed: () {
                  AuditPdfPrinter.printLiquorAuditReport(
                    rawRows: List<Map<String, dynamic>>.from(state.reportData),
                    startDate: state.startDate,
                    endDate: state.endDate,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}