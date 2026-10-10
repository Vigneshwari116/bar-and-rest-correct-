
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:printing/printing.dart';
import '../../../../core/network/api_client.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';


class PosSettingsPage extends StatefulWidget {
  const PosSettingsPage({super.key});

  @override
  State<PosSettingsPage> createState() => _PosSettingsPageState();
}

class _PosSettingsPageState extends State<PosSettingsPage> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  int _selectedTabIndex = 0;
  bool _isLoading = false;

  // Printers List State
  List<dynamic> _printersList = [];
  Map<String, String> _customShortcuts = {}; // Dynamic Map loaded from Database

  // Available Billing Actions Dropdown Options
  final List<Map<String, String>> _availableActions = [
    {'key': 'SHORTCUT_FOCUS_TABLE', 'label': 'Focus Table Selector Field'},
    {'key': 'SHORTCUT_BILL', 'label': 'Generate / Checkout Bill'},
    {'key': 'SHORTCUT_KOT', 'label': 'Print KOT (Kitchen Token)'},
    {'key': 'SHORTCUT_CHANGE_TABLE', 'label': 'Change / Shift Table'},
    {'key': 'SHORTCUT_CLEAR', 'label': 'Clear Active Order Grid'},
    {'key': 'SHORTCUT_FOCUS_BARCODE', 'label': 'Focus Barcode Scanner Box'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchSettingsData();
  }

  // 🔄 1. FETCH PRINTERS & SHORTCUTS FROM API / DATABASE
  Future<void> _fetchSettingsData() async {
    setState(() => _isLoading = true);
    try {
      final printersRes = await apiClient.get('/api/v1/pos/settings/printers');
      final configsRes = await apiClient.get('/api/v1/pos/settings/configs');

      print("config data $configsRes");
      print("printer data $printersRes");

      if (printersRes?.data != null) {
        _printersList = printersRes.data['data'] as List<dynamic>? ?? [];
      }

      if (configsRes?.data != null) {
        final configsMap = configsRes.data['data'] as Map<String, dynamic>? ?? {};
        _customShortcuts = configsMap.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      _showSnackBar("Failed to synchronize hardware and config profiles", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 💾 EXECUTE BACKEND DATABASE BACKUP TO D DRIVE
  Future<void> _executeDatabaseBackup() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.get('/api/v1/pos/settings/database/backup');

      if (response != null && response.data['status'] == 'SUCCESS') {
        final String savedFileName = response.data['backup_file'] ?? '';
        _showSnackBar("Backup saved successfully in D:\\DB_BACKUP\\$savedFileName");
      } else {
        _showSnackBar("Failed to create database backup.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Backup Error: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importTablesCsvData() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      final file = File(result.files.single.path!);
      final List<List<dynamic>> fields = Csv().decode(await file.readAsString());

      if (fields.isEmpty) return;

      // First column se table names extract karne ke liye
      int startIndex = fields[0][0].toString().toLowerCase().contains('table') ? 1 : 0;
      List<String> tableNames = [];

      for (int i = startIndex; i < fields.length; i++) {
        if (fields[i].isNotEmpty) {
          final String val = fields[i][0].toString().trim().toUpperCase();
          if (val.isNotEmpty) tableNames.add(val);
        }
      }

      if (tableNames.isEmpty) return;

      await apiClient.post('/api/v1/pos/settings/tables/bulk-import', data: {'tables': tableNames});
      _showSnackBar('Tables CSV Imported!');
      _fetchSettingsData();
    }
  }

  Future<void> _showClearDatabaseDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final double screenWidth = MediaQuery.of(ctx).size.width;

        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "HARD SYSTEM RESET",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: screenWidth > 450 ? 400 : screenWidth * 0.9,
            child: const Text(
              "Are you sure you want to clear the transactional database?\n\n"
                  "• Wipes: All Bills, KOTs, Archives & Live Ledgers.\n"
                  "• Preserves: Items, Categories, Users & Tables.",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                _executeDatabaseWipe();
              },
              child: const Text("YES, WIPE BILLS", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🌟 3. EXECUTE BACKEND DATABASE WIPE
  Future<void> _executeDatabaseWipe() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.post('/api/v1/reports/clear-system-database');

      if (response != null && response.data['status'] == 'SUCCESS') {
        _showSnackBar("Database cleared successfully! Items and Users are safe.");
        await _fetchSettingsData();
      } else {
        _showSnackBar("Failed to reset database.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Wipe Error: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPrinterDialog() async {
    final nameCtrl = TextEditingController();
    String pType = 'KOT';
    String cType = 'USB';

    // 🔍 System se connected sabhi unique printers fetch karein
    List<Printer> installedPrinters = [];
    try {
      installedPrinters = await Printing.listPrinters();
    } catch (e) {
      debugPrint("Printers fetch error: $e");
    }

    // Selected Printer ka Unique Name
    String? selectedDeviceName = installedPrinters.isNotEmpty ? installedPrinters.first.name : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Hardware Printer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),

                  // 1. Label Input (Custom Label jaise Kitchen / Counter)
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDecoration('Printer Nickname (e.g. Kitchen POS)', Icons.label_outline),
                  ),
                  const SizedBox(height: 10),

                  // 2. Purpose Dropdown (KOT vs BILL)
                  DropdownButtonFormField<String>(
                    value: pType,
                    decoration: _inputDecoration('Purpose', Icons.room_service_outlined),
                    items: const [
                      DropdownMenuItem(value: 'KOT', child: Text('KOT (Kitchen)')),
                      DropdownMenuItem(value: 'BILL', child: Text('Bill (Counter)')),
                    ],
                    onChanged: (val) => setDialogState(() => pType = val!),
                  ),
                  const SizedBox(height: 10),

                  // 3. 🎯 UNIQUE USB PRINTER SELECTION DROPDOWN
                  DropdownButtonFormField<String>(
                    value: selectedDeviceName,
                    isExpanded: true,
                    decoration: _inputDecoration('Select System Connected Printer', Icons.print),
                    hint: const Text("Select USB Printer"),
                    items: installedPrinters.map((printer) {
                      return DropdownMenuItem<String>(
                        value: printer.name,
                        child: Text(
                          "${printer.name} ${printer.url.isNotEmpty ? '(${printer.url})' : ''}",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedDeviceName = val),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || selectedDeviceName == null) return;

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);

                          // Save both nickname and unique system name/address to backend
                          await apiClient.post('/api/v1/pos/settings/printers/save', data: {
                            'printer_name': nameCtrl.text.trim(),
                            'printer_type': pType,
                            'connection_type': 'USB',
                            'target_address': selectedDeviceName, // 👈 Windows ka unique name/port mapping save hoga
                            'is_active': 1,
                          });

                          await _fetchSettingsData();
                          setState(() => _isLoading = false);
                        },
                        child: const Text('Save Device'),
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
  // 🗑️ 5. DELETE PRINTER
  Future<void> _deletePrinter(int id) async {
    setState(() => _isLoading = true);
    try {
      await apiClient.post('/api/v1/pos/settings/printers/delete', data: {'id': id});
      _showSnackBar('Device entry purged successfully');
      await _fetchSettingsData();
    } catch (e) {
      _showSnackBar('Failed to remove printer entry', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ➕ 6. ADD NEW DYNAMIC SHORTCUT DIALOG
  Future<void> _addShortcutDialog() async {
    String selectedActionKey = _availableActions.first['key']!;
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double screenWidth = MediaQuery.of(ctx).size.width;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              width: screenWidth > 480 ? 420 : screenWidth * 0.92,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.keyboard_command_key, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add Dynamic Hotkey Binding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Assign sequences like 555, 777 or ALT+C', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedActionKey,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w600),
                    decoration: _inputDecoration('Target POS Event / Action', Icons.touch_app_outlined),
                    items: _availableActions.map((action) {
                      return DropdownMenuItem(
                        value: action['key'],
                        child: Text(action['label']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedActionKey = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: keyController,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDecoration('Shortcut Value (e.g. 555, 777, ALT+C)', Icons.pin_outlined),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 11))),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final String typedKey = keyController.text.trim().toUpperCase();
                          if (typedKey.isEmpty) return;

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);

                          try {
                            await apiClient.post('/api/v1/pos/settings/configs/save', data: {
                              'config_key': selectedActionKey,
                              'config_value': typedKey,
                            });
                            _showSnackBar('New key binding mapped in Database!');
                            await _fetchSettingsData();
                          } catch (e) {
                            _showSnackBar('Failed to save shortcut binding', isError: true);
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                        icon: const Icon(Icons.check, size: 14, color: Colors.white),
                        label: const Text('Save Binding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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

  // 🗑️ 7. DELETE DYNAMIC SHORTCUT
  Future<void> _deleteShortcut(String key) async {
    setState(() => _isLoading = true);
    try {
      await apiClient.post('/api/v1/pos/settings/configs/save', data: {
        'config_key': key,
        'config_value': '',
      });
      _showSnackBar('Shortcut removed from Database');
      await _fetchSettingsData();
    } catch (e) {
      _showSnackBar('Failed to clear shortcut binding', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      prefixIcon: Icon(icon, size: 15, color: const Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text(
              isMobile ? 'POS Preferences' : 'Hardware & POS Preferences',
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [

              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 10.0, bottom: 10.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _importTablesCsvData, // 👈 Directly function call
                  icon: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF2563EB), size: 15),
                  label: const Text(
                    "UPLOAD TABLES CSV",
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(right: 6.0, top: 10.0, bottom: 10.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF0FDF4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFF16A34A), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
                  ),
                  onPressed: _executeDatabaseBackup,
                  icon: const Icon(Icons.backup_rounded, color: Color(0xFF16A34A), size: 15),
                  label: Text(
                    isMobile ? "BACKUP" : "BACKUP DB",
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ),
              ),
/*
              Padding(
                padding: const EdgeInsets.only(right: 10.0, top: 10.0, bottom: 10.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                  ),
                  onPressed: _showClearDatabaseDialog,
                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 15),
                  label: Text(
                    isMobile ? "CLEAR DB" : "CLEAR DATABASE",
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ),
              ),
*/
            ],
            bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2))
              : isMobile
              ? Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(child: _buildMobileTabBtn(0, Icons.print_rounded, 'Printers')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMobileTabBtn(1, Icons.keyboard_command_key_rounded, 'Hotkeys')),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _selectedTabIndex == 0 ? _buildPrintersView(isMobile) : _buildShortcutsView(isMobile),
                ),
              ),
            ],
          )
              : Row(
            children: [
              Container(
                width: 200,
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildNavTile(0, Icons.print_rounded, 'Thermal Printers', 'USB & Network setup'),
                    _buildNavTile(1, Icons.keyboard_command_key_rounded, 'Hotkeys & Shortcuts', 'Dynamic Key Bindings'),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _selectedTabIndex == 0 ? _buildPrintersView(isMobile) : _buildShortcutsView(isMobile),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileTabBtn(int index, IconData icon, String label) {
    final bool isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(int index, IconData icon, String title, String subtitle) {
    final bool isSelected = _selectedTabIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedTabIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  // 🖨️ TAB 1: PRINTERS VIEW
  Widget _buildPrintersView(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Thermal Printers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 1),
                  Text(
                    isMobile ? 'KOT & Counter Print Setup' : 'Configured KOT and Counter Invoice Print Routing',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _addPrinterDialog,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text(isMobile ? 'Add' : 'Add Thermal Device', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.usb_rounded, color: Color(0xFFD97706), size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Direct USB Cable Mode Supported', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 10.5)),
                    Text('Type Windows printer name (e.g., RP3200 or BILL_PRINTER) for direct printing.', style: TextStyle(color: Color(0xFFB45309), fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: _printersList.isEmpty
              ? Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_disabled_outlined, size: 30, color: Color(0xFF94A3B8)),
                  SizedBox(height: 6),
                  Text('No thermal printers mapped', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 11.5)),
                  Text('Click "Add Thermal Device" above to add USB or Network printers.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                ],
              ),
            ),
          )
              : ListView.builder(
            itemCount: _printersList.length,
            itemBuilder: (ctx, i) {
              final p = _printersList[i];
              final bool isKot = p['printer_type'] == 'KOT';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isKot ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      isKot ? Icons.soup_kitchen_rounded : Icons.receipt_long_rounded,
                      color: isKot ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                      size: 15,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(p['printer_name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isKot ? const Color(0xFFFFEDD5) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          p['printer_type'].toString(),
                          style: TextStyle(color: isKot ? const Color(0xFFC2410C) : const Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 8.5),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Interface: ${p['connection_type']} • ${p['target_address']}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                    onPressed: () => _deletePrinter(p['id'] as int),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ⌨️ TAB 2: DYNAMIC SHORTCUTS VIEW
  Widget _buildShortcutsView(bool isMobile) {
    final activeShortcuts = _customShortcuts.entries.where((e) => e.value.trim().isNotEmpty && e.key.startsWith('SHORTCUT_')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dynamic Hotkey Matrix', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 1),
                  Text(
                    isMobile ? 'Map custom sequences' : 'Map custom sequences like 777, 555, 999 or ALT+C for billing operations',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _addShortcutDialog,
              icon: const Icon(Icons.add, size: 14),
              label: Text(isMobile ? 'Add' : 'ADD NEW SHORTCUT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: activeShortcuts.isEmpty
              ? Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_outlined, size: 30, color: Color(0xFF94A3B8)),
                  SizedBox(height: 6),
                  Text('No custom shortcuts mapped yet', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 11.5)),
                  Text('Click "Add" above to create custom bindings.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                ],
              ),
            ),
          )
              : ListView.builder(
            itemCount: activeShortcuts.length,
            itemBuilder: (ctx, i) {
              final item = activeShortcuts[i];
              final String actionKey = item.key;
              final String shortcutValue = item.value;

              final actionObj = _availableActions.firstWhere((a) => a['key'] == actionKey, orElse: () => {'label': actionKey});

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(5)),
                    child: const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 15),
                  ),
                  title: Text(actionObj['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A))),
                  subtitle: Text('Key: $actionKey', style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shortcutValue,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 10.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                        onPressed: () => _deleteShortcut(actionKey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}