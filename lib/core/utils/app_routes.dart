import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:svenska/features/main/presentation/pages/config_loader_page.dart';
import 'package:svenska/features/main/presentation/pages/pos_settings_page.dart';
import 'package:svenska/features/main/presentation/pages/settings_page.dart';
import 'package:svenska/features/master/presentation/pages/item_editing_master_page.dart';
import 'package:svenska/features/master/presentation/pages/item_opening_master_page.dart';
import 'package:svenska/features/master/presentation/pages/manual_liquore_item_edit_page.dart';
import 'package:svenska/features/master/presentation/pages/manual_liquore_menu_master_page.dart';
import 'package:svenska/features/pos/presentation/pages/manual_liquor_pos_billing.dart';
import 'package:svenska/features/pos/presentation/pages/manual_pos_billing.dart';
import 'package:svenska/features/pos/presentation/pages/pos_billing_page.dart';
import 'package:svenska/features/reports/presentation/bill_wise_details_report_page.dart';
import 'package:svenska/features/reports/presentation/report_page.dart';
import '../../features/main/presentation/pages/analytical_dashboard_view.dart';
import '../../features/main/presentation/pages/dashboard_page.dart';
import '../../features/main/presentation/pages/user_management_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/main/presentation/pages/login_page.dart';
import '../../features/main/presentation/pages/admin_register_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String registerAdmin = '/register-admin';
  static const String settings = '/settings_page';
  static const String configLoader = '/configLoader';


  // Tab/Sidebar Core Routes
  static const String dashboard = '/dashboard';
  static const String tablesGrid = '/tables_grid';
  static const String kotMonitor = '/kot_monitor';
  static const String billingTerminal = '/billing_terminal';
  static const String manageUser = '/manage_user';
  static const String manageSession = '/manage_session';
  static const String barInventory = '/bar_inventory';
  static const String itemOpeningMaster = '/item_opening_master';
  static const String mrpOpeningMaster = '/mrp_master';
  static const String posBilling = '/pos_billing';
  static const String manualPosBilling = '/manual_pos';
  static const String mrpPosBilling = '/mrp_pos';

  static const String posSettings = '/pos_settings';
  static const String itemEditMaster = '/item_edit_master';
  static const String mrpEditMaster = '/mrp_edit_master';
  static const String report = '/report';
  static const String billWiseReport = '/bill_wise_report';


}


class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // Standalone Screens (Bina Sidebar ke)
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.registerAdmin,
        builder: (_, __) => const AdminRegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.configLoader,
        builder: (_, __) => const ConfigLoaderPage(),
      ),

      // =======================================================================
      // 🏢 SHELL ROUTE ARCHITECTURE (Sidebar Locks & Injects Child Screens)
      // =======================================================================
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return DashboardPage(childContentPanel: child);
        },
        routes: [

          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const MainAnalyticsDashboardPage(), // 🌟 FIX: Page wrapper call karo, direct View nahi!
          ),

          GoRoute(
            path: AppRoutes.manageUser,
            builder: (_, __) => const UserManagementPage(),
          ),

          GoRoute(
            path: AppRoutes.itemOpeningMaster,
            builder: (_, __) => const MenuMasterPage(),
          ),
          GoRoute(
            path: AppRoutes.mrpOpeningMaster,
            builder: (_, __) => const ManualLiquorMenuMasterPage(),
          ),

          GoRoute(
            path: AppRoutes.itemEditMaster,
            builder: (_, __) => const ItemEditingMasterPage(),
          ),
          GoRoute(
            path: AppRoutes.mrpEditMaster,
            builder: (_, __) => const ManualLiquorItemEditingPage(),
          ),
          GoRoute(
            path: AppRoutes.posBilling,
            builder: (_, __) => const PosBillingPage(),
          ),
          GoRoute(
            path: AppRoutes.manualPosBilling,
            builder: (_, __) => const ManualFoodBillingPage(),
          ),
          GoRoute(
            path: AppRoutes.mrpPosBilling,
            builder: (_, __) => const ManualLiquorBillingPage(),
          ),

          GoRoute(
            path: AppRoutes.report,
            builder: (_, __) => const ReportDashboardPage(),
          ),

          GoRoute(
            path: AppRoutes.posSettings,
            builder: (_, __) => PosSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.billWiseReport,
            builder: (_, __) => BillwiseDetailedReportView(),
          ),
        ],
      ),
    ],
  );
}

