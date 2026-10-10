import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AuditPdfPrinter {
  static const String restaurantTitle = "HOTEL SRI SAI RESTAURANT AND SHANTH BAR";

  // 🌟 POS REPLICATE: Find Physical OS Printer Object
  static Future<Printer> _findTargetPrinter(String targetName) async {
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) throw Exception("No physical printers available on system");

    if (targetName.isNotEmpty) {
      String clean(String str) => str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final String searchClean = clean(targetName);

      for (var printer in printers) {
        final String currentClean = clean(printer.name);
        if (currentClean == searchClean || currentClean.contains(searchClean) || searchClean.contains(currentClean)) {
          return printer;
        }
      }
    }
    return printers.firstWhere((p) => p.isDefault, orElse: () => printers.first);
  }

  // 🌟 POS REPLICATE: Direct Hardware Print Engine
  static Future<void> _directPrintToPhysicalPrinter({
    required Uint8List bytes,
    required String jobName,
    required List<dynamic> dbPrinters,
  }) async {
    try {
      String targetPrinterName = resolveBillPrinter(dbPrinters);
      final physicalPrinter = await _findTargetPrinter(targetPrinterName);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        await Printing.directPrintPdf(
          printer: physicalPrinter,
          onLayout: (PdfPageFormat format) async => bytes,
          name: jobName,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: jobName,
        );
      }
    } catch (e) {
      debugPrint("🔴 [Report Direct Print Exception]: $e");
      await _handleCrossPlatformPdfOutput(bytes, jobName);
    }
  }

  static String resolveBillPrinter(List<dynamic> printersList) {
    if (printersList.isEmpty) return "";
    for (var p in printersList) {
      final String pType = (p['printer_type'] ?? '').toString().toUpperCase();
      final String isActiveStr = (p['is_active'] ?? '').toString();
      final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');
      final String targetAddr = (p['target_address'] ?? p['printer_target'] ?? '').toString().trim();

      if (pType == 'BILL' && isActive && targetAddr.isNotEmpty) {
        return targetAddr;
      }
    }
    return "";
  }

  // 🛍️ 1. PRINT DAILY SALES REPORT (Handles Thousands of Items via 300mm Chunking)
  static Future<void> printDailySalesReport({
    required Map<String, List<dynamic>> groupedData,
    required double grandTotal,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> dbPrinters,
    double fontSize = 10.5,
  }) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(endDate);

    // 🌟 300mm Standard Height Chunk: Prevents Driver Truncation and Allows Infinite Pages
    final pageFormat = PdfPageFormat(
      78 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginLeft: 1.5 * PdfPageFormat.mm,
      marginRight: 5.0 * PdfPageFormat.mm,
      marginTop: 2.0 * PdfPageFormat.mm,
      marginBottom: 2.0 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];
          widgets.add(pw.Center(child: pw.Text("DAILY SALES REPORT", style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Center(child: pw.Text("DATE: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Divider(thickness: 1.0));

          for (var entry in groupedData.entries) {
            double categorySum = entry.value.fold(0.0, (sum, item) => sum + (double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0));
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                color: PdfColors.grey300,
                child: pw.Text("CATEGORY: ${entry.key}", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              ),
            );
            widgets.add(pw.SizedBox(height: 3));

            widgets.add(pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(5.0),
                1: pw.FlexColumnWidth(1.3),
                2: pw.FlexColumnWidth(3.7), // Extra space for 5-6 digit amounts
              },
              children: entry.value.map((item) {
                final String name = (item['item_name'] ?? '').toString().toUpperCase();
                final String qty = (item['sold_qty'] ?? '0').toString();
                final double revVal = double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0;

                return pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Text(
                      name,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(fontSize: fontSize),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Text("x$qty", style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1.5, bottom: 1.5, right: 2.0),
                    child: pw.Text(
                      revVal.toStringAsFixed(0),
                      style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ]);
              }).toList(),
            ));

            widgets.add(pw.SizedBox(height: 3));
            widgets.add(pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("SUBTOTAL:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 2.0),
                  child: pw.Text(categorySum.toStringAsFixed(2), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ));
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Divider(thickness: 0.8));
          }

          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("GRAND TOTAL REVENUE:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 2.0),
                child: pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ));
          widgets.add(pw.Divider(thickness: 1.2));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Center(child: pw.Text("*** END OF SALES REPORT ***", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));

          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _directPrintToPhysicalPrinter(bytes: bytes, jobName: "Sales_Report_$dateStr", dbPrinters: dbPrinters);
  }

  // 📊 2. PRINT BILLWISE ABSTRACT REPORT (MultiPage 300mm Chunk)
  static Future<void> printBillwiseAbstractReport({
    required List<dynamic> reportData,
    required double totalLiquor,
    required double totalFood,
    required double totalSoft,
    required double totalOthers,
    required double grandTotal,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> dbPrinters,
    double fontSize = 10.0,
  }) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(endDate);

    final pageFormat = PdfPageFormat(
      78 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginLeft: 1.5 * PdfPageFormat.mm,
      marginRight: 5.0 * PdfPageFormat.mm,
      marginTop: 2.0 * PdfPageFormat.mm,
      marginBottom: 2.0 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];
          widgets.add(pw.Center(child: pw.Text("ABSTRACT REPORT", style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Center(child: pw.Text("DATE: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Divider(thickness: 1.0));

          widgets.add(pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.8),
              5: pw.FlexColumnWidth(1.8),
              6: pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))), children: [
                pw.Text("BILL", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("TAB", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("LIQ", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("FOD", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("SOF", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("OTH", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold)),
                pw.Text("TOTAL", style: pw.TextStyle(fontSize: fontSize - 2, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ]),
              ...reportData.map((item) {
                final String bNo = (item['bill_no'] ?? '0').toString();
                final String tId = (item['table_id'] ?? '1A').toString().toUpperCase();
                final double lVal = double.tryParse(item['liquor_total']?.toString() ?? '0') ?? 0.0;
                final double fVal = double.tryParse(item['food_total']?.toString() ?? '0') ?? 0.0;
                final double sVal = double.tryParse(item['soft_total']?.toString() ?? '0') ?? 0.0;
                final double oVal = double.tryParse(item['others_total']?.toString() ?? '0') ?? 0.0;
                final double subVal = double.tryParse(item['grand_total']?.toString() ?? '0') ?? 0.0;

                return pw.TableRow(children: [
                  pw.Text(bNo, style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Text(tId, style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Text(lVal.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Text(fVal.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Text(sVal.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Text(oVal.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize - 2.5)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 2.0),
                    child: pw.Text(subVal.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize - 2.5), textAlign: pw.TextAlign.right),
                  ),
                ]);
              }),
            ],
          ));

          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Divider(thickness: 1.0));
          widgets.add(_buildThermalSummaryRow("LIQUOR TOTAL:", totalLiquor, fontSize));
          widgets.add(_buildThermalSummaryRow("FOOD TOTAL:", totalFood, fontSize));
          widgets.add(_buildThermalSummaryRow("SOFT DRINKS:", totalSoft, fontSize));
          widgets.add(_buildThermalSummaryRow("OTHERS TOTAL:", totalOthers, fontSize));
          widgets.add(pw.Divider(thickness: 1.0));
          widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("GRAND TOTAL:", style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 2.0),
              child: pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
            ),
          ]));
          widgets.add(pw.Divider(thickness: 1.2));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Center(child: pw.Text("*** END OF ABSTRACT ***", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));

          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _directPrintToPhysicalPrinter(bytes: bytes, jobName: "Abstract_Report_$dateStr", dbPrinters: dbPrinters);
  }

  // 🗑️ 3. DELETED AUDIT SLIP DIRECT PRINT
  static Future<void> printDeletedAuditSlip({
    required List<dynamic> rows,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> dbPrinters,
    double fontSize = 10.5,
  }) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(endDate);

    double totalLostAmount = 0.0;
    int totalLostQty = 0;

    for (var item in rows) {
      totalLostAmount += double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
      totalLostQty += int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    }

    final pageFormat = PdfPageFormat(
      78 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginLeft: 1.5 * PdfPageFormat.mm,
      marginRight: 5.0 * PdfPageFormat.mm,
      marginTop: 2.0 * PdfPageFormat.mm,
      marginBottom: 2.0 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];
          widgets.add(pw.Center(child: pw.Text("DELETED AUDIT REPORT", style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Center(child: pw.Text("DATE: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Divider(thickness: 1.0));

          widgets.add(pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(1.8), 1: pw.FlexColumnWidth(4.8), 2: pw.FlexColumnWidth(1.5), 3: pw.FlexColumnWidth(3.2)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))), children: [
                pw.Text("TBL", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                pw.Text("ITEM", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                pw.Text("QTY", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                pw.Text("AMT", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ]),
              ...rows.map((item) {
                final String tId = (item['table_id'] ?? '1').toString().toUpperCase();
                final String name = (item['item_name'] ?? '').toString().toUpperCase();
                final String qty = (item['qty'] ?? '1').toString();
                final double amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;

                return pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Text(tId, style: pw.TextStyle(fontSize: fontSize - 1))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Text(name, maxLines: 1, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.left)),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Text("x$qty", style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1.5, bottom: 1.5, right: 2.0),
                    child: pw.Text(amt.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                ]);
              }),
            ],
          ));

          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Divider(thickness: 1.0));
          widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("TOTAL DELETED QTY:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            pw.Text("$totalLostQty QTY", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
          ]));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("TOTAL LOST AMOUNT:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 2.0),
              child: pw.Text(totalLostAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
            ),
          ]));
          widgets.add(pw.Divider(thickness: 1.2));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Center(child: pw.Text("*** END OF DELETED AUDIT ***", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));

          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _directPrintToPhysicalPrinter(bytes: bytes, jobName: "Deleted_Audit_$dateStr", dbPrinters: dbPrinters);
  }

  // 👔 4. WAITER INCENTIVE SLIP DIRECT PRINT
  static Future<void> printWaiterIncentiveSlip({
    required String waiterName,
    required String waiterId,
    required List<dynamic> orders,
    required double totalSales,
    required int totalQty,
    required DateTime startDate,
    required DateTime endDate,
    required List<dynamic> dbPrinters,
    double fontSize = 10.5,
  }) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String toDateStr = DateFormat('dd-MM-yyyy').format(endDate);

    final pageFormat = PdfPageFormat(
      78 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginLeft: 1.5 * PdfPageFormat.mm,
      marginRight: 5.0 * PdfPageFormat.mm,
      marginTop: 2.0 * PdfPageFormat.mm,
      marginBottom: 2.0 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];
          widgets.add(pw.Center(child: pw.Text("WAITER PERFORMANCE SLIP", style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Center(child: pw.Text("WAITER: $waiterName (ID: $waiterId)", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.Center(child: pw.Text("PERIOD: $dateStr TO $toDateStr", style: pw.TextStyle(fontSize: fontSize - 1))));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Divider(thickness: 1.0));

          widgets.add(pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(4.8), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(3.7)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))), children: [
                pw.Text("ITEM", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                pw.Text("QTY", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                pw.Text("AMT", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ]),
              ...orders.map((item) {
                final String name = (item['particulars'] ?? item['item_name'] ?? 'ITEM').toString().toUpperCase();
                final int qty = int.tryParse(item['unit']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1;
                final double rate = double.tryParse(item['rate']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
                final double amt = double.tryParse(item['amount']?.toString() ?? (rate * qty).toString()) ?? (rate * qty);

                return pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Text(name, maxLines: 1, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.left)),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Text("$qty", style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1.5, bottom: 1.5, right: 2.0),
                    child: pw.Text(amt.toStringAsFixed(0), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                ]);
              }),
            ],
          ));

          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Divider(thickness: 1.0));
          widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("TOTAL FOOD QTY:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            pw.Text("$totalQty UNITS", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
          ]));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("TOTAL FOOD SALES:", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 2.0),
              child: pw.Text(totalSales.toStringAsFixed(2), style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
            ),
          ]));
          widgets.add(pw.Divider(thickness: 1.2));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Center(child: pw.Text("*** INCENTIVE BASE SLIP ***", style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold))));

          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _directPrintToPhysicalPrinter(bytes: bytes, jobName: "Performance_${waiterId}_$dateStr", dbPrinters: dbPrinters);
  }

  // 📄 5. FOOD AUDIT A4
  static Future<void> printFoodAuditReport({
    required List<Map<String, dynamic>> rawRows,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final NumberFormat currencyFmt = NumberFormat("#,##,##0", "en_IN");
    final String startStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String endStr = DateFormat('dd-MM-yyyy').format(endDate);
    final String dateHeader = startStr == endStr ? startStr : "$startStr TO $endStr";

    double totalAmount = 0.0;
    double foodAmount = 0.0;
    double water1Ltr = 0.0;
    double water2Ltr = 0.0;
    double soft300ml = 0.0;
    double soft500ml = 0.0;
    double soda500ml = 0.0;
    double soda300ml = 0.0;

    for (var row in rawRows) {
      final double amt = double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
      final String name = row['particulars']?.toString().toUpperCase() ?? '';

      totalAmount += amt;

      if (name.contains("MINRAL WATER ILTR") || name.contains("WATER 1LTR")) {
        water1Ltr += amt;
      } else if (name.contains("MINERAL WATER 2LTR") || name.contains("WATER 2LTR")) {
        water2Ltr += amt;
      } else if (name.contains("SOFT DRINKS 300ML")) {
        soft300ml += amt;
      } else if (name.contains("SOFT DINKS 500ML") || name.contains("SOFT DRINKS 500ML")) {
        soft500ml += amt;
      } else if (name.contains("SODA 500ML")) {
        soda500ml += amt;
      } else if (name.contains("KINLEY SODA 300ML") || name.contains("SODA 300ML")) {
        soda300ml += amt;
      } else {
        foodAmount += amt;
      }
    }

    final double cgst = totalAmount * 0.025;
    final double sgst = totalAmount * 0.025;
    final double grandTotal = totalAmount + cgst + sgst;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) => pw.Column(
          children: [
            pw.Center(child: pw.Text(restaurantTitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text("FOOD BILL REPORT", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(dateHeader, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text("Page ${ctx.pageNumber} of ${ctx.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (pw.Context ctx) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(5.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("BILLNO", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("PARTICULARS", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("RATE", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("UNIT", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("AMOUNT", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              ...rawRows.map((row) {
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['bill_no'] ?? ''}", style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['particulars'] ?? ''}", style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['rate'] ?? '0'}", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['unit'] ?? '0'}", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(currencyFmt.format(double.tryParse(row['amount']?.toString() ?? '0') ?? 0), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
            child: pw.Column(
              children: [
                _buildSummaryLine("TOTAL AMOUNT", totalAmount, currencyFmt),
                _buildSummaryLine("CGST 2.5%", cgst, currencyFmt),
                _buildSummaryLine("SGST 2.5%", sgst, currencyFmt),
                pw.Divider(thickness: 0.8),
                _buildSummaryLine("GRAND TOTAL AMOUNT", grandTotal, currencyFmt, isBold: true),
                pw.Divider(thickness: 0.8),
                _buildSummaryLine("FOOD AMOUNT", foodAmount, currencyFmt),
                _buildSummaryLine("WATER 1LTR", water1Ltr, currencyFmt),
                _buildSummaryLine("WATER 2LTR", water2Ltr, currencyFmt),
                _buildSummaryLine("SOFTDRINKS 300ML", soft300ml, currencyFmt),
                _buildSummaryLine("SOFTDRINKS 500ML", soft500ml, currencyFmt),
                _buildSummaryLine("SODA 500ML", soda500ml, currencyFmt),
                _buildSummaryLine("SODA 300ML", soda300ml, currencyFmt),
              ],
            ),
          )
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _handleCrossPlatformPdfOutput(bytes, "Food_Audit_Report_$startStr");
  }

  // 🍷 6. LIQUOR AUDIT A4
  static Future<void> printLiquorAuditReport({
    required List<Map<String, dynamic>> rawRows,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final NumberFormat currencyFmt = NumberFormat("#,##,##0", "en_IN");
    final String startStr = DateFormat('dd-MM-yyyy').format(startDate);
    final String endStr = DateFormat('dd-MM-yyyy').format(endDate);
    final String dateHeader = startStr == endStr ? startStr : "$startStr TO $endStr";

    double grandTotal = 0.0;
    for (var r in rawRows) {
      grandTotal += double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) => pw.Column(
          children: [
            pw.Center(child: pw.Text(restaurantTitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text("LIQUOR BILL REPORT", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(dateHeader, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text("Page ${ctx.pageNumber} of ${ctx.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (pw.Context ctx) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(6),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("PARTICULARS", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("UNIT", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("AMOUNT", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              ...rawRows.map((row) {
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['particulars'] ?? ''}", style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("${row['unit'] ?? '0'}", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(currencyFmt.format(double.tryParse(row['amount']?.toString() ?? '0') ?? 0), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("GRAND TOTAL AMOUNT", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("Rs. ${currencyFmt.format(grandTotal)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    await _handleCrossPlatformPdfOutput(bytes, "Liquor_Audit_Report_$startStr");
  }

  // 🌟 CROSS-PLATFORM FALLBACK ENGINE
  static Future<void> _handleCrossPlatformPdfOutput(Uint8List bytes, String filename) async {
    try {
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
          format: PdfPageFormat.a4,
        );
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File("${tempDir.path}\\$filename.pdf");
        await file.writeAsBytes(bytes, flush: true);

        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else {
          await Printing.layoutPdf(onLayout: (format) async => bytes, name: filename);
        }
      } else {
        await Printing.sharePdf(bytes: bytes, filename: "$filename.pdf");
      }
    } catch (e) {
      await Printing.sharePdf(bytes: bytes, filename: "$filename.pdf");
    }
  }

  static pw.Widget _buildThermalSummaryRow(String label, double amount, double baseFontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: baseFontSize - 1)),
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 2.0),
            child: pw.Text(amount.toStringAsFixed(2), style: pw.TextStyle(fontSize: baseFontSize - 1, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryLine(String label, double value, NumberFormat fmt, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text("Rs. ${fmt.format(value)}", style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}