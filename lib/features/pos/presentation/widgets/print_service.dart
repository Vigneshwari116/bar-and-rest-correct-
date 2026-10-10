
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrinterService {

  // 🔤 CONSOLAS TTF ASSET LOADER HELPER
  static Future<pw.Font> _loadConsolasFont() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/consolas.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint("🔴 Consolas font load failed, falling back to Courier: $e");
      return pw.Font.courier();
    }
  }

  // 🎯 SMART HARDWARE-AWARE PRINTER RESOLVER
  static Future<String> resolvePhysicalTargetPrinter({
    required List<dynamic> dbPrinters,
    required String preferredType, // 'KOT' ya 'BILL'
  }) async {
    try {
      final onlinePrinters = await Printing.listPrinters();
      if (onlinePrinters.isEmpty) return "";

      String clean(String str) => str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      List<Printer> availablePrinters = onlinePrinters.where((p) => p.isAvailable != false).toList();
      if (availablePrinters.isEmpty) availablePrinters = onlinePrinters;

      String preferredAddress = "";
      for (var p in dbPrinters) {
        final String pType = (p['printer_type'] ?? '').toString().toUpperCase();
        final String isActiveStr = (p['is_active'] ?? '').toString();
        final bool isActive = (isActiveStr == '1' || isActiveStr == 'true');

        if (pType == preferredType.toUpperCase() && isActive) {
          preferredAddress = (p['target_address'] ?? '').toString().trim();
          break;
        }
      }

      if (preferredAddress.isNotEmpty) {
        final String targetClean = clean(preferredAddress);
        for (var printer in availablePrinters) {
          if (clean(printer.name).contains(targetClean) || targetClean.contains(clean(printer.name))) {
            return printer.name;
          }
        }
      }

      for (var p in dbPrinters) {
        final String targetAddr = (p['target_address'] ?? '').toString().trim();
        if (targetAddr.isNotEmpty) {
          final String targetClean = clean(targetAddr);
          for (var printer in availablePrinters) {
            if (clean(printer.name).contains(targetClean) || targetClean.contains(clean(printer.name))) {
              debugPrint("⚡ [Printer Fallback]: $preferredType offline. Rerouting to available printer -> '${printer.name}'");
              return printer.name;
            }
          }
        }
      }

      final defaultPrinter = availablePrinters.firstWhere((p) => p.isDefault, orElse: () => availablePrinters.first);
      return defaultPrinter.name;
    } catch (e) {
      debugPrint("🔴 [Printer Resolution Exception]: $e");
      return "";
    }
  }

  // 🖨️ 1. KITCHEN ORDER TOKEN (FULL BOLD & LARGE QTY)
  static Future<void> printKitchenTokenSilent({
    required String tableId,
    required List<Map<String, dynamic>> foodItems,
    String waiterId = "",
    String waiterName = "",
    String targetPrinterName = "",
  }) async {
    try {
      final pdf = pw.Document();
      final consolasFont = await _loadConsolasFont();

      List<Map<String, dynamic>> consolidatedFood = _groupItems(foodItems);
      double calculatedHeightMm = 75.0 + (consolidatedFood.length * 11.5);

      final pageFormat = PdfPageFormat(
        78 * PdfPageFormat.mm,
        calculatedHeightMm * PdfPageFormat.mm,
        marginLeft: 1.5 * PdfPageFormat.mm,
        marginRight: 6.0 * PdfPageFormat.mm,
        marginTop: 2.5 * PdfPageFormat.mm,
        marginBottom: 4.0 * PdfPageFormat.mm,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: pw.ThemeData.withFont(
            base: consolasFont,
            bold: consolasFont,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TABLE: $tableId", style: pw.TextStyle(fontSize: 11.5, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                    pw.Text("DATE: ${_getFormattedCurrentDate()}", style: pw.TextStyle(fontSize: 10.0, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("STAFF ID: ${waiterId.isNotEmpty ? waiterId : 'NA'}", style: pw.TextStyle(fontSize: 10.0, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                    pw.Text("TIME: ${_formatCurrentTime()}", style: pw.TextStyle(fontSize: 10.0, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 1.0, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 1),

                pw.Row(
                  children: [
                    pw.Expanded(flex: 70, child: pw.Text("ITEM NAME", style: pw.TextStyle(fontSize: 12, font: consolasFont, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 30, child: pw.Text("QTY", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12.0, font: consolasFont, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Divider(thickness: 1.0, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 1),

                ...consolidatedFood.map((item) {
                  int itemQty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                  String itemName = (item['item_name'] ?? 'ITEM').toString().toUpperCase().trim();

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          flex: 70,
                          child: pw.Text(
                            itemName,
                            maxLines: 2,
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: consolasFont,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 30,
                          child: pw.Text(
                            itemQty.toString(),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 15.0, font: consolasFont, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 2),
                pw.Divider(thickness: 1.0, borderStyle: pw.BorderStyle.dashed),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();

      if (bytes.isNotEmpty) {
        await _directPrintToPhysicalPrinter(bytes, "KOT_$tableId", pageFormat, targetPrinterName);
      }
    } catch (e) {
      debugPrint("🔴 [KOT Direct Print Exception]: $e");
    }
  }

  // 🖨️ 2. DIRECT THERMAL RECEIPT BILL PRINTING (USES DB SAVED DATE/TIME)
  static Future<void> printThermalBill({
    required String tableId,
    required String mobile,
    required List<Map<String, dynamic>> foodItems,
    required List<Map<String, dynamic>> liquorItems,
    required double grandTotal,
    String billNo = "",
    String targetPrinterName = "",
    String? billDateTime, // 👈 🌟 DB SE AANE WALA EXACT TIMESTAMP (String/ISO)
  }) async {
    try {
      final pdf = pw.Document();
      final consolasFont = await _loadConsolasFont();

      List<Map<String, dynamic>> consolidatedFood = _groupItems(foodItems);
      List<Map<String, dynamic>> consolidatedLiquor = _groupItems(liquorItems);

      double foodTotalAmount = consolidatedFood.fold(0.0, (sum, item) {
        double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        return sum + (price * qty);
      });

      double liquorTotalAmount = consolidatedLiquor.fold(0.0, (sum, item) {
        double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        return sum + (price * qty);
      });

      int totalItemsCount = consolidatedFood.length + consolidatedLiquor.length;
      double calculatedHeightMm = 110.0 + (totalItemsCount * 11.5);
      if (consolidatedFood.isNotEmpty && consolidatedLiquor.isNotEmpty) {
        calculatedHeightMm += 26.0;
      }

      final pageFormat = PdfPageFormat(
        78 * PdfPageFormat.mm,
        calculatedHeightMm * PdfPageFormat.mm,
        marginLeft: 1.5 * PdfPageFormat.mm,
        marginRight: 6.0 * PdfPageFormat.mm,
        marginTop: 2.5 * PdfPageFormat.mm,
        marginBottom: 5.0 * PdfPageFormat.mm,
      );

      final String displayBillNo = billNo.isEmpty ? "96" : billNo;

      // 🌟 Database Saved Date/Time Resolver (Fallback to now if null)
      final String formattedDateTimeString = _formatDateTime(billDateTime);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: pw.ThemeData.withFont(
            base: consolasFont,
            bold: consolasFont,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("BILL NO : $displayBillNo", style: pw.TextStyle(fontSize: 10.5, font: consolasFont)),
                    pw.Text("TABLE NO : $tableId", style: pw.TextStyle(fontSize: 10.5, font: consolasFont), textAlign: pw.TextAlign.right),
                  ],
                ),
                pw.SizedBox(height: 3),

                pw.Center(
                  child: pw.Text("WELCOME", style: pw.TextStyle(fontSize: 11.0, font: consolasFont)),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text("HOTEL SRI SAI RESTAURANT", style: pw.TextStyle(fontSize: 12.0, font: consolasFont), textAlign: pw.TextAlign.center),
                ),
                pw.Center(
                  child: pw.Text("AND SHANTH BAR", style: pw.TextStyle(fontSize: 11.5, font: consolasFont), textAlign: pw.TextAlign.center),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text("SORAB ROAD , SAGARA", style: pw.TextStyle(fontSize: 10.0, font: consolasFont), textAlign: pw.TextAlign.center),
                ),
                pw.SizedBox(height: 4),

                // ---------------- DB SAVED DATE & TIME PRINT ----------------
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("GST: 29CQNPS6562A1ZE", style: pw.TextStyle(fontSize: 9.0, font: consolasFont)),
                    pw.Text(formattedDateTimeString, style: pw.TextStyle(fontSize: 9.0, font: consolasFont)), // 👈 🌟 Exact DB Timestamp
                  ],
                ),
                pw.SizedBox(height: 2),

                // ---------------- TABLE HEADERS ----------------
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.Row(
                  children: [
                    pw.Expanded(flex: 60, child: pw.Text("PARTICULARS", style: pw.TextStyle(fontSize: 10.0, font: consolasFont))),
                    pw.Expanded(flex: 12, child: pw.Text("QTY", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10.0, font: consolasFont))),
                    pw.Expanded(flex: 28, child: pw.Text("AMOUNT", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10.0, font: consolasFont))),
                  ],
                ),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 1),

                // ---------------- 1. FOOD ITEMS SECTION ----------------
                if (consolidatedFood.isNotEmpty) ...[
                  _buildSimpleItemsTable(consolidatedFood, consolasFont),
                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("FOOD TOTAL:", style: pw.TextStyle(fontSize: 10.5, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                      pw.Text(foodTotalAmount.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10.5, font: consolasFont, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ],
                  ),
                  pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                ],

                // ---------------- 2. LIQUOR ITEMS SECTION ----------------
                if (consolidatedLiquor.isNotEmpty) ...[
                  _buildSimpleItemsTable(consolidatedLiquor, consolasFont),
                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("LIQUOR TOTAL:", style: pw.TextStyle(fontSize: 10.5, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                      pw.Text(liquorTotalAmount.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10.5, font: consolasFont, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                ],

                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                // ---------------- GRAND TOTAL AMOUNT ----------------
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.0),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 12.0, font: consolasFont, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        grandTotal.toStringAsFixed(0),
                        style: pw.TextStyle(fontSize: 15.0, font: consolasFont, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),

                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    "INCLUDING ALL TAXES: 2.5% CGST, 2.5% SGST",
                    style: pw.TextStyle(fontSize: 8, font: consolasFont, fontWeight: pw.FontWeight.normal),
                  ),
                ),

                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // ---------------- FOOTER ----------------
                pw.Center(
                  child: pw.Text("THANK YOU VISIT AGAIN", style: pw.TextStyle(fontSize: 10.5, font: consolasFont)),
                ),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();

      if (bytes.isNotEmpty) {
        await _directPrintToPhysicalPrinter(bytes, "Bill_$tableId", pageFormat, targetPrinterName);
      }
    } catch (e) {
      debugPrint("🔴 [Thermal Bill Exception]: $e");
    }
  }

  // 🔄 UNIVERSAL GROUPING HELPER FUNCTION
  static List<Map<String, dynamic>> _groupItems(List<Map<String, dynamic>> rawItems) {
    Map<String, Map<String, dynamic>> groupedMap = {};

    for (var item in rawItems) {
      String nameKey = (item['item_name'] ?? 'ITEM').toString().trim().toUpperCase();
      int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;

      if (groupedMap.containsKey(nameKey)) {
        int existingQty = int.tryParse(groupedMap[nameKey]!['qty']?.toString() ?? '0') ?? 0;
        groupedMap[nameKey]!['qty'] = existingQty + qty;
      } else {
        groupedMap[nameKey] = Map<String, dynamic>.from(item);
        groupedMap[nameKey]!['qty'] = qty;
      }
    }

    return groupedMap.values.toList();
  }

  // ⚡ HARDWARE DIRECT PRINT ENGINE
  static Future<void> _directPrintToPhysicalPrinter(
      Uint8List bytes,
      String jobName,
      PdfPageFormat pageFormat,
      String targetPrinterName,
      ) async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final printer = await _findTargetPrinter(targetPrinterName);
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => bytes,
          name: jobName,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: jobName,
          format: pageFormat,
        );
      }
    } catch (e) {
      debugPrint("🔴 [Direct Print Exception]: $e");
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: jobName,
        format: pageFormat,
      );
    }
  }

  static Future<Printer> _findTargetPrinter(String targetName) async {
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) throw Exception("No physical printers available");

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

  // ⚡ ITEMS TABLE
  static pw.Widget _buildSimpleItemsTable(List<Map<String, dynamic>> items, pw.Font font) {
    return pw.Column(
      children: items.map((item) {
        double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        int qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        double lineTotal = price * qty;
        String name = (item['item_name'] ?? 'ITEM').toString().toUpperCase().trim();

        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 60,
                child: pw.Text(
                  name,
                  maxLines: 2,
                  style: pw.TextStyle(
                    fontSize: 11,
                    font: font,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 12,
                child: pw.Text(
                  qty.toString(),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 10.0, font: font),
                ),
              ),
              pw.Expanded(
                flex: 28,
                child: pw.Text(
                  lineTotal.toStringAsFixed(0),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 10.0, font: font),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 🌟 SMART DATE-TIME PARSER (Converts ISO/DB String to "DD/MM/YY HH:MM")
  static String _formatDateTime(dynamic dateTimeInput) {
    DateTime dt;
    if (dateTimeInput is DateTime) {
      dt = dateTimeInput;
    } else if (dateTimeInput is String && dateTimeInput.trim().isNotEmpty) {
      try {
        dt = DateTime.parse(dateTimeInput.trim());
      } catch (_) {
        dt = DateTime.now();
      }
    } else {
      dt = DateTime.now();
    }

    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString().substring(2);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return "$day/$month/$year $hour:$minute";
  }

  static String _formatCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  static String _getFormattedCurrentDate() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);
    return "$day/$month/$year";
  }
}