
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_routes.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/utils/secure_storage_util.dart';
import '../../../../data/database/db_contract.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class DashboardPage extends StatefulWidget {
  final Widget childContentPanel;
  const DashboardPage({super.key, required this.childContentPanel});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _currentSessionUserRole = "waiter";
  String _currentSessionUsername = "FETCHING...";
  bool _isReady = false;

  bool _isSidebarManualCollapsed = false;
  final Map<String, bool> _expandedGroups = {};

  static const Color darkSlateBg = Color(0xFF1E293B);
  static const Color cyanPrimary = Color(0xFF00BCD4);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _loadActiveSessionTelemetry();
  }

  Future<void> _loadActiveSessionTelemetry() async {
    debugPrint("🚀 [Telemetry]: Strict Mode - Validating identity...");

    try {
      final bool isMaster = !kIsWeb && (dotenv.env['IS_MASTER_SERVER']?.toLowerCase() == 'true');

      if (isMaster) {
        final db = GetIt.I<Database>();
        final activeSessions = await db.query(
          DbContracts.tableSessions,
          where: '${DbContracts.columnIsForcefullyLoggedOut} = 0',
          orderBy: '${DbContracts.columnLastActiveAt} DESC',
          limit: 1,
        );

        if (activeSessions.isNotEmpty) {
          final userId = activeSessions.first[DbContracts.columnSessionUserId];
          final userRows = await db.query(
            DbContracts.tableUsers,
            where: '${DbContracts.columnUserId} = ?',
            whereArgs: [userId],
          );

          if (userRows.isNotEmpty && mounted) {
            _updateState(
              userRows.first[DbContracts.columnUsername].toString(),
              userRows.first[DbContracts.columnUserRole].toString(),
            );
            return;
          }
        }
      } else {
        final String? savedUsername = GetIt.I.isRegistered<String>(instanceName: "currentUser")
            ? GetIt.I<String>(instanceName: "currentUser")
            : null;

        if (savedUsername != null) {
          try {
            final response = await GetIt.I<ApiClient>().get(
              '/api/v1/dashboard-data',
              queryParams: {'username': savedUsername},
            ).timeout(const Duration(seconds: 3));

            if (response.statusCode == 200 && response.data != null) {
              _updateState(
                response.data['username'].toString(),
                response.data['role'].toString(),
              );
              return;
            }
          } catch (apiError) {
            debugPrint("⚠️ [Telemetry Fallback]: Remote metrics unavailable.");

            final String userRoleFallback = GetIt.I.isRegistered<String>(instanceName: 'role')
                ? GetIt.I<String>(instanceName: 'role')
                : "admin";

            _updateState(savedUsername, userRoleFallback);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [Telemetry Error]: $e");
    }

    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  void _updateState(String username, String role) {
    if (mounted) {
      setState(() {
        _currentSessionUsername = username.toUpperCase();
        _currentSessionUserRole = role.toLowerCase();
        _isReady = true;
      });
    }
  }

  Future<void> _executeAbsoluteSignOut() async {
    try {
      if (!kIsWeb) {
        final db = GetIt.I<Database>();
        await db.update(DbContracts.tableSessions, {DbContracts.columnIsForcefullyLoggedOut: 1});
      }
      if (GetIt.I.isRegistered<String>(instanceName: "currentUser")) {
        await GetIt.I.unregister<String>(instanceName: "currentUser");
      }
      await SecureStorageUtil.saveToken("");
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      debugPrint("❌ [Session termination track crashed]: $e");
    }
  }

  Widget _buildHardwareNodeIndicator(bool isMobile) {
    final bool isWebClient = kIsWeb;
    final String nodeTitle = isWebClient ? "CLIENT" : "MASTER POS";
    final Color indicatorColor = isWebClient ? const Color(0xFF00BCD4) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: indicatorColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: indicatorColor),
          if (!isMobile) ...[
            const SizedBox(width: 6),
            Text(
              nodeTitle,
              style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.bold, color: indicatorColor, letterSpacing: 0.5),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: darkSlateBg,
        body: Center(child: CircularProgressIndicator(color: cyanPrimary, strokeWidth: 2)),
      );
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is SessionTerminatedState) {
          _executeAbsoluteSignOut();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile check: Screen width less than 750
          final bool isMobile = constraints.maxWidth < 750;

          // ⚡ FIX: Mobile par hamesha collapsed, Desktop/Tablet par user preference (_isSidebarManualCollapsed)
          final bool shouldCollapseSidebar = isMobile ? false : _isSidebarManualCollapsed;

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFB),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              toolbarHeight: 54,
              iconTheme: const IconThemeData(color: darkSlateBg, size: 20),
              leading: isMobile
                  ? null
                  : IconButton(
                tooltip: shouldCollapseSidebar ? "Expand Navigation" : "Collapse Navigation",
                icon: Icon(shouldCollapseSidebar ? Icons.menu_open_rounded : Icons.menu_rounded),
                onPressed: () {
                  setState(() {
                    _isSidebarManualCollapsed = !_isSidebarManualCollapsed;
                  });
                },
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isMobile ? "SVENSKA F&B CORE" : "SVENSKA F&B ENGINE CORE",
                          style: const TextStyle(color: darkSlateBg, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          DateFormat('EEE, dd MMM yyyy').format(DateTime.now()).toUpperCase(),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 8.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildHardwareNodeIndicator(isMobile),
                ],
              ),
              actions: [_buildUserIdentityWidget(isMobile)],
              shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),

            // Drawer for Mobile View
            drawer: isMobile
                ? Drawer(
              backgroundColor: darkSlateBg,
              elevation: 16,
              child: SafeArea(
                child: _buildSidebarContentLayout(false, isMobile),
              ),
            )
                : null,

            body: Row(
              children: [
                if (!isMobile)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: shouldCollapseSidebar ? 64 : 240,
                    color: darkSlateBg,
                    child: _buildSidebarContentLayout(shouldCollapseSidebar, isMobile),
                  ),
                Expanded(child: ClipRRect(child: widget.childContentPanel)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarContentLayout(bool isCollapsed, bool isMobile) {
    final List<MenuModel> accessibleMenus = DashboardMenuRegistry.corporateMenus
        .where((menu) => menu.allowedRoles.contains(_currentSessionUserRole.trim()))
        .toList();

    return Column(
      children: [
        if (!isCollapsed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 14, color: cyanPrimary),
                const SizedBox(width: 10),
                const Text("NAVIGATION MATRIX", style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                if (isMobile) const Spacer(),
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.close, color: textMuted, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  )
              ],
            ),
          )
        else
          const SizedBox(height: 16), // Padding for collapsed mode header

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: accessibleMenus.length,
            itemBuilder: (context, index) {
              final item = accessibleMenus[index];
              if (item.subMenus == null) {
                return _buildRawSingleNavItem(item.icon, item.title, item.route, isCollapsed, isMobile);
              }
              return _buildCompactGroupMenuTree(item.icon, item.title, item.subMenus!, isCollapsed, isMobile);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF0F172A),
          child: _buildFooterLogoutButtonWidget(isCollapsed),
        )
      ],
    );
  }

  Widget _buildRawSingleNavItem(IconData icon, String title, String path, bool isCollapsed, bool isMobile) {
    final String currentPath = GoRouterState.of(context).uri.path;
    final bool isSelected = currentPath == path;

    return Tooltip(
      message: isCollapsed ? title : "",
      child: InkWell(
        onTap: () {
          if (isMobile) Navigator.of(context).pop();
          context.go(path);
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: isSelected ? cyanPrimary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(4)
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: isSelected ? cyanPrimary : textMuted),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: isSelected ? Colors.white : const Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGroupMenuTree(IconData icon, String label, List<Map<String, dynamic>> children, bool isCollapsed, bool isMobile) {
    final String currentPath = GoRouterState.of(context).uri.path;
    final bool hasActiveChild = children.any((element) => element["route"] == currentPath);

    // Auto-expand group if active route belongs to this group
    final bool isOpen = _expandedGroups[label] ?? hasActiveChild;

    // ⚡ FIX: Collapsed state me click karne par Sidebar Auto-Expand hoga aur Menu khulega
    if (isCollapsed) {
      return Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: 18, color: hasActiveChild ? cyanPrimary : textMuted),
          onPressed: () {
            setState(() {
              _isSidebarManualCollapsed = false; // Expand sidebar
              _expandedGroups[label] = true;     // Open dropdown
            });
          },
        ),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedGroups[label] = !isOpen),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: hasActiveChild ? cyanPrimary : textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: hasActiveChild ? Colors.white : const Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 14, color: textMuted),
              ],
            ),
          ),
        ),
        if (isOpen)
          Column(
            children: children.map((sub) {
              final bool isSubSelected = currentPath == sub["route"];
              return InkWell(
                onTap: () {
                  if (isMobile) Navigator.of(context).pop();
                  context.go(sub["route"]!);
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(left: 36, top: 8, bottom: 8, right: 8),
                  child: Row(
                    children: [
                      Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: isSubSelected ? cyanPrimary : textMuted)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sub["title"]!,
                          style: TextStyle(color: isSubSelected ? cyanPrimary : textMuted, fontSize: 11, fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
      ],
    );
  }

  Widget _buildUserIdentityWidget(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Row(
        children: [
          if (!isMobile) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currentSessionUsername, style: const TextStyle(color: darkSlateBg, fontWeight: FontWeight.bold, fontSize: 10.5)),
                const SizedBox(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: cyanPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                  child: Text(_currentSessionUserRole.toUpperCase(), style: const TextStyle(color: cyanPrimary, fontSize: 7.5, fontWeight: FontWeight.w900)),
                )
              ],
            ),
            const SizedBox(width: 8),
          ],
          CircleAvatar(
            radius: 14,
            backgroundColor: darkSlateBg,
            child: Text(_currentSessionUsername.isNotEmpty ? _currentSessionUsername[0] : "U", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLogoutButtonWidget(bool isCollapsed) {
    return InkWell(
      onTap: _executeAbsoluteSignOut,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(Icons.logout, size: 16, color: Colors.redAccent),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              const Text("SIGN OUT ENGINE", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}

class MenuModel {
  final String title;
  final IconData icon;
  final String route;
  final List<String> allowedRoles;
  final List<Map<String, dynamic>>? subMenus;

  MenuModel({required this.title, required this.icon, required this.route, required this.allowedRoles, this.subMenus});
}

class DashboardMenuRegistry {
  static final List<MenuModel> corporateMenus = [
    MenuModel(title: "Operations Floor", icon: Icons.analytics_outlined, route: "/dashboard", allowedRoles: ["admin", "superuser"]),
    MenuModel(title: "POS", icon: Icons.point_of_sale, route: "/pos_billing", allowedRoles: ["admin", "superuser", "accountant"]),
    MenuModel(title: "MANUAL ENTRY", icon: Icons.point_of_sale, route: "/manual_pos", allowedRoles: ["admin", "superuser", "accountant"]),
    MenuModel(title: "MRP POS", icon: Icons.point_of_sale, route: "/mrp_pos", allowedRoles: ["admin", "superuser", "accountant"]),
    MenuModel(title: "Menu & Inventory", icon: Icons.restaurant_menu_rounded, route: "#", allowedRoles: ["admin", "superuser", "accountant"], subMenus: [
      {"title": "Item Opening Master", "route": "/item_opening_master"},
      {"title": "MRP Master", "route": "/mrp_master"},
      {"title": "Item Edit Master", "route": "/item_edit_master"},
      {"title": "MRP Edit Master", "route": "/mrp_edit_master"},
    ]),
    MenuModel(title: "Audit & Reports", icon: Icons.assessment_outlined, route: "#", allowedRoles: ["admin", "superuser", "accountant"], subMenus: [
      {"title": "Daily Sales Summary", "route": "/report"},
      {"title": "Bill Wise Report", "route": "/bill_wise_report"},

    ]),
    MenuModel(title: "Employee Management", icon: Icons.gpp_good_rounded, route: "#", allowedRoles: ["admin", "superuser"], subMenus: [
      {"title": "Staff Credentials", "route": "/manage_user"},
    ]),
    MenuModel(title: "Settings", icon: Icons.settings, route: "/pos_settings", allowedRoles: ["admin", "superuser", "accountant"]),
  ];
}