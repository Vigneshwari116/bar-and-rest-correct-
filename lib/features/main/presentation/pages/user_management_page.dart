
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_config.dart';

// =============================================================================
// 1. HOSPITALITY CORE SECURITY MODEL
// =============================================================================
class UserTelemetryModel {
  final int userId;
  final String username;
  final String role;
  final bool isOnline;
  final String activeDevice;
  final String lastSeenMetric;

  UserTelemetryModel({
    required this.userId,
    required this.username,
    required this.role,
    required this.isOnline,
    required this.activeDevice,
    required this.lastSeenMetric,
  });
}

// =============================================================================
// 2. MAIN USER MANAGEMENT DESIGN LAYOUT
// =============================================================================
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserTelemetryModel> _staffDirectoryList = [];
  String _searchQuery = "";
  bool _isLoading = true;
  bool _isRightPanelOpen = true;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'waiter';
  final List<String> _rolesList = ['waiter', 'accountant', 'kitchen', 'bar_tender'];

  static const Color darkSlateBg = Color(0xFF1E293B);
  static const Color cyanPrimary = Color(0xFF00BCD4);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _fetchLiveHardwareTelemetry();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🌟 1. FETCH TELEMETRY VIA API
  Future<void> _fetchLiveHardwareTelemetry() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final apiClient = GetIt.I<ApiClient>();
      final response = await apiClient.get('/api/v1/users/telemetry');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];

        List<UserTelemetryModel> synchronizedProfiles = data.map((user) {
          return UserTelemetryModel(
            userId: user['user_id'],
            username: user['username'],
            role: user['role'],
            isOnline: user['is_online'] == 1,
            activeDevice: user['active_device'] ?? "Offline Node",
            lastSeenMetric: user['last_seen_metric'] ?? "Offline",
          );
        }).toList();

        if (mounted) {
          setState(() {
            _staffDirectoryList = synchronizedProfiles;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ [API RENDER ERROR]: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network Fetch Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // 🌟 2. ONBOARD STAFF VIA API
  Future<void> _onboardNewStaffNode() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final apiClient = GetIt.I<ApiClient>();
      final String username = _usernameController.text.trim();
      final tenantId = await AppConfig.getActiveTenantId();

      final response = await apiClient.post('/api/v1/users/create', data: {
        'tenant_id': tenantId,
        'username': username,
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
      });

      if (response.statusCode == 200 && response.data['status'] == 'SUCCESS') {
        _usernameController.clear();
        _passwordController.clear();
        await _fetchLiveHardwareTelemetry();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ New Staff Profile Provisioned!"), backgroundColor: Colors.teal),
          );
        }
      } else {
        throw Exception(response.data['message'] ?? "Unknown Error");
      }
    } catch (e) {
      debugPrint("❌ [API Error]: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _staffDirectoryList.where((stf) {
      return stf.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFB),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildManagementTopHeader(isMobile),
                const SizedBox(height: 16),

                // 📊 LIVE ANALYTICS SUMMARY
                _buildLiveAnalyticsSummaryRow(isMobile),
                const SizedBox(height: 16),

                // 📝 ONBOARDING FORM (STACKED FOR MOBILE/TABLET)
                if (!isDesktop && _isRightPanelOpen) ...[
                  _buildRightOnboardingFormPanel(),
                  const SizedBox(height: 16),
                ],

                // 🔍 SEARCH INPUT BAR
                _buildFilterSearchInputRow(),
                const SizedBox(height: 12),

                // 👥 STAFF DIRECTORY LIST & DESKTOP SIDE PANEL
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildStaffListView(filteredStaff, isMobile),
                      ),
                      if (_isRightPanelOpen) ...[
                        const SizedBox(width: 20),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          width: 350,
                          child: _buildRightOnboardingFormPanel(),
                        ),
                      ],
                    ],
                  )
                else
                  _buildStaffListView(filteredStaff, isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  // 1️⃣ TOP HEADER
  Widget _buildManagementTopHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("STAFF TERMINAL DIRECTORY", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: darkSlateBg)),
          const SizedBox(height: 2),
          const Text("CORE STAFF AUTH SCOPE MAP", style: TextStyle(color: cyanPrimary, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isRightPanelOpen = !_isRightPanelOpen),
              icon: Icon(_isRightPanelOpen ? Icons.keyboard_arrow_up_rounded : Icons.person_add_alt_1_outlined, size: 14),
              label: Text(_isRightPanelOpen ? "HIDE ONBOARDING FORM" : "ONBOARD STAFF PROFILE", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: darkSlateBg, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            ),
          )
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("STAFF TERMINAL SECURITY DIRECTORY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: darkSlateBg)),
            SizedBox(height: 2),
            Text("CORE STAFF AUTH SCOPE MAP • LIVE DEVICE INTERCEPTOR LOCK", style: TextStyle(color: cyanPrimary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isRightPanelOpen = !_isRightPanelOpen),
          icon: Icon(_isRightPanelOpen ? Icons.chevron_right_rounded : Icons.person_add_alt_1_outlined, size: 14),
          label: Text(_isRightPanelOpen ? "HIDE SIDE PANEL" : "ONBOARD STAFF PROFILE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: darkSlateBg, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
        )
      ],
    );
  }

  // 2️⃣ SUMMARY METRICS ROW
  Widget _buildLiveAnalyticsSummaryRow(bool isMobile) {
    final totalCount = _staffDirectoryList.length;
    final activeOnlineCount = _staffDirectoryList.where((u) => u.isOnline).length;
    final offlineCount = totalCount - activeOnlineCount;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricsCellItem("TOTAL ROSTER", totalCount.toString().padLeft(2, '0'), darkSlateBg, isMobile),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          _buildMetricsCellItem("LIVE FLOOR", activeOnlineCount.toString().padLeft(2, '0'), const Color(0xFF10B981), isMobile),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          _buildMetricsCellItem("STANDBY NODES", offlineCount.toString().padLeft(2, '0'), textMuted, isMobile),
        ],
      ),
    );
  }

  Widget _buildMetricsCellItem(String label, String metricValue, Color metricColor, bool isMobile) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(metricValue, style: TextStyle(fontFamily: 'monospace', fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w900, color: metricColor)),
      ],
    );
  }

  // 3️⃣ SEARCH BAR
  Widget _buildFilterSearchInputRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: const InputDecoration(
                hintText: "Search staff name handle...",
                hintStyle: TextStyle(fontSize: 11, color: textMuted),
                prefixIcon: Icon(Icons.search, size: 14, color: cyanPrimary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18, color: cyanPrimary),
          onPressed: _fetchLiveHardwareTelemetry,
          tooltip: "Force Database Sync Track",
        )
      ],
    );
  }

  // 4️⃣ STAFF LIST VIEW
  Widget _buildStaffListView(List<UserTelemetryModel> filteredStaff, bool isMobile) {
    if (_isLoading) {
      return  Container(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: cyanPrimary, strokeWidth: 2)),
      );
    }

    if (filteredStaff.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Text("Zero users found inside database registry.", style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchLiveHardwareTelemetry,
              icon: const Icon(Icons.refresh, size: 14, color: cyanPrimary),
              label: const Text("Force Sync Retry", style: TextStyle(color: cyanPrimary, fontSize: 11)),
            )
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredStaff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildStaffHighDensityRowItem(filteredStaff[index], isMobile),
    );
  }

  // 5️⃣ STAFF ITEM ROW
  Widget _buildStaffHighDensityRowItem(UserTelemetryModel staff, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: isMobile
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: staff.isOnline ? const Color(0xFF10B981) : textMuted),
                  const SizedBox(width: 8),
                  Text(staff.username, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: darkSlateBg)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: Text(staff.role.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.devices_other_rounded, size: 11, color: textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text("HW: ${staff.activeDevice} • ${staff.lastSeenMetric}", style: const TextStyle(fontSize: 10, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (staff.isOnline) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: ElevatedButton.icon(
                onPressed: () => _dispatchForceRemoteLogoutPrompt(context, staff),
                icon: const Icon(Icons.gpp_bad_rounded, size: 12),
                label: const Text("KILL SESSION", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  foregroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Color(0xFFFCA5A5), width: 0.5)),
                ),
              ),
            )
          ]
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: staff.isOnline ? const Color(0xFF10B981) : textMuted),
                    const SizedBox(width: 10),
                    Text(staff.username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkSlateBg)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(staff.role.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.devices_other_rounded, size: 12, color: textMuted),
                    const SizedBox(width: 6),
                    Text("Terminal Hardware: ${staff.activeDevice}", style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic)),
                    const SizedBox(width: 12),
                    Text("•  ${staff.lastSeenMetric}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: staff.isOnline ? const Color(0xFF10B981) : textMuted)),
                  ],
                )
              ],
            ),
          ),
          if (staff.isOnline)
            ElevatedButton.icon(
              onPressed: () => _dispatchForceRemoteLogoutPrompt(context, staff),
              icon: const Icon(Icons.gpp_bad_rounded, size: 12),
              label: const Text("KILL SESSION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFEF4444),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Color(0xFFFCA5A5), width: 0.5)),
              ),
            )
          else
            const Text("DISCONNECTED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // 6️⃣ ONBOARDING FORM PANEL
  Widget _buildRightOnboardingFormPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Onboard Staff Profile", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: darkSlateBg)),
            const SizedBox(height: 2),
            const Text("Safely inject access credentials into local schema matrix.", style: TextStyle(fontSize: 10.5, color: textMuted)),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            _buildLabelText("STAFF ACCOUNT USERNAME"),
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              decoration: _buildFormFieldInputStyle("e.g., rahul_waiter04", Icons.person_outline_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomenclature field required' : null,
            ),
            const SizedBox(height: 14),

            _buildLabelText("CRYPTOGRAPHIC ACCESS PASSKEY"),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              decoration: _buildFormFieldInputStyle("••••••••••••", Icons.lock_outline_rounded),
              validator: (v) => (v == null || v.isEmpty) ? 'Security clearance code required' : null,
            ),
            const SizedBox(height: 14),

            _buildLabelText("FUNCTIONAL OPERATIONAL ROLE TIER"),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              dropdownColor: Colors.white,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkSlateBg),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: cyanPrimary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cyanPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                isDense: true,
              ),
              items: _rolesList.map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.toUpperCase(), style: const TextStyle(overflow: TextOverflow.ellipsis))
              )).toList(),
              onChanged: (val) => setState(() => _selectedRole = val ?? 'waiter'),
            ),
            const SizedBox(height: 22),

            ElevatedButton.icon(
              onPressed: _onboardNewStaffNode,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
              label: const Text("INITIALIZE SYSTEM ACCESS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkSlateBg,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
            )
          ],
        ),
      ),
    );
  }

  void _dispatchForceRemoteLogoutPrompt(BuildContext context, UserTelemetryModel targetStaff) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final double screenWidth = MediaQuery.of(dialogContext).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: screenWidth > 450 ? 400 : screenWidth * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text("CRITICAL ACCESS REVOCATION", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: darkSlateBg)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text("Are you verified to execute an absolute remote session key flush for: ${targetStaff.username}?", style: const TextStyle(fontSize: 11.5, height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text("CANCEL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final apiClient = GetIt.I<ApiClient>();
                          await apiClient.post('/api/v1/users/kill-session', data: {
                            'user_id': targetStaff.userId
                          });

                          if (context.mounted) Navigator.of(dialogContext).pop();
                          _fetchLiveHardwareTelemetry();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("🚨 Purged hardware token node for ${targetStaff.username}"), backgroundColor: Colors.orange.shade900, behavior: SnackBarBehavior.floating),
                            );
                          }
                        } catch (e) {
                          debugPrint("Session Kill Error: $e");
                          if (context.mounted) Navigator.of(dialogContext).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                      child: const Text("YES, PURGE NODE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabelText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
    );
  }

  InputDecoration _buildFormFieldInputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
      prefixIcon: Icon(icon, size: 14, color: cyanPrimary),
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cyanPrimary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      isDense: true,
    );
  }
}