import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';

class MainAnalyticsDashboardPage extends StatelessWidget {
  const MainAnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc()..add(FetchDashboardDataEvent()),
      child: const MainAnalyticsDashboardView(),
    );
  }
}

class MainAnalyticsDashboardView extends StatelessWidget {
  const MainAnalyticsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkSlateBg = Color(0xFF0F172A);
    const Color cardBorderColor = Color(0xFFE2E8F0);
    const Color cyanPrimary = Color(0xFF00BCD4);
    const Color textMuted = Color(0xFF64748B);

    Widget buildStatCard(String label, String value, String subText, IconData icon, Color markerColor, bool isMobile) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cardBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: isMobile ? 34 : 40,
              decoration: BoxDecoration(color: markerColor, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: isMobile ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w900,
                      color: darkSlateBg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: isMobile ? 8.5 : 9,
                        fontWeight: FontWeight.bold,
                        color: markerColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
            Icon(icon, size: isMobile ? 18 : 22, color: markerColor.withOpacity(0.5)),
          ],
        ),
      );
    }

    Widget buildProgressBarAuditItem(String mode, String amount, double ratio, Color barColor, bool isMobile) {
      final double percentage = ratio * 100;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: barColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          mode,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: darkSlateBg,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 13,
                        fontWeight: FontWeight.w900,
                        color: darkSlateBg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.isNaN || ratio.isInfinite ? 0.0 : ratio,
                minHeight: isMobile ? 6 : 8,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            )
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final bool isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        return BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading) {
              return const Scaffold(
                backgroundColor: Color(0xFFF8FAFC),
                body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: cyanPrimary)),
              );
            }

            double totalDeptSales = state.foodTotal + state.liquorTotal + state.beerTotal;
            double foodRatio = totalDeptSales > 0 ? (state.foodTotal / totalDeptSales) : 0.0;
            double liquorRatio = totalDeptSales > 0 ? (state.liquorTotal / totalDeptSales) : 0.0;
            double beerRatio = totalDeptSales > 0 ? (state.beerTotal / totalDeptSales) : 0.0;

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: RefreshIndicator(
                onRefresh: () async => context.read<DashboardBloc>().add(FetchDashboardDataEvent()),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1️⃣ HEADER SECTION
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.analytics_rounded, color: cyanPrimary, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  "SVENSKA ANALYTICS DASHBOARD",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: darkSlateBg, letterSpacing: 0.3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "SETTLED BILLS & DEPARTMENT REVENUE SUMMARY",
                              style: TextStyle(color: cyanPrimary, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: ElevatedButton.icon(
                                onPressed: () => context.read<DashboardBloc>().add(FetchDashboardDataEvent()),
                                icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                                label: const Text("REFRESH DATA", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkSlateBg,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            )
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.analytics_rounded, color: cyanPrimary, size: 22),
                                    SizedBox(width: 8),
                                    Text("SVENSKA ANALYTICS DASHBOARD", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: darkSlateBg, letterSpacing: 0.5)),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text("SETTLED BILLS & DEPARTMENT REVENUE SUMMARY", style: TextStyle(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                            SizedBox(
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: () => context.read<DashboardBloc>().add(FetchDashboardDataEvent()),
                                icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                                label: const Text("REFRESH DATA", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkSlateBg,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            )
                          ],
                        ),

                      const SizedBox(height: 16),

                      // 2️⃣ STAT CARDS (ADAPTIVE GRID FOR MOBILE / TABLET / DESKTOP)
                      if (isMobile) ...[
                        buildStatCard("GROSS F&B REVENUE", "₹${state.grossSales.toStringAsFixed(2)}", "DAILY SALES", Icons.payments_rounded, const Color(0xFF10B981), isMobile),
                        const SizedBox(height: 10),
                        buildStatCard("SETTLED BILLS", "${state.settledVouchersCount} VOUCHERS", "TOTAL INVOICES", Icons.receipt_long_rounded, const Color(0xFF8B5CF6), isMobile),
                        const SizedBox(height: 10),
                        buildStatCard("ACTIVE TABLES", "${state.activeTablesCount} / ${state.totalTablesCount}", "OCCUPIED TABLES", Icons.table_restaurant_rounded, const Color(0xFF2563EB), isMobile),
                        const SizedBox(height: 10),
                        buildStatCard("PENDING KOT QTY", "${state.pendingKotCount} UNITS", "KITCHEN QUEUE", Icons.soup_kitchen_rounded, const Color(0xFFF59E0B), isMobile),
                      ] else if (isTablet) ...[
                        Row(
                          children: [
                            Expanded(child: buildStatCard("GROSS F&B REVENUE", "₹${state.grossSales.toStringAsFixed(2)}", "DAILY SALES", Icons.payments_rounded, const Color(0xFF10B981), isMobile)),
                            const SizedBox(width: 10),
                            Expanded(child: buildStatCard("SETTLED BILLS", "${state.settledVouchersCount} VOUCHERS", "TOTAL INVOICES", Icons.receipt_long_rounded, const Color(0xFF8B5CF6), isMobile)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: buildStatCard("ACTIVE TABLES", "${state.activeTablesCount} / ${state.totalTablesCount}", "OCCUPIED TABLES", Icons.table_restaurant_rounded, const Color(0xFF2563EB), isMobile)),
                            const SizedBox(width: 10),
                            Expanded(child: buildStatCard("PENDING KOT QTY", "${state.pendingKotCount} UNITS", "KITCHEN QUEUE", Icons.soup_kitchen_rounded, const Color(0xFFF59E0B), isMobile)),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(child: buildStatCard("GROSS F&B REVENUE", "₹${state.grossSales.toStringAsFixed(2)}", "DAILY SALES", Icons.payments_rounded, const Color(0xFF10B981), isMobile)),
                            const SizedBox(width: 10),
                            Expanded(child: buildStatCard("SETTLED BILLS", "${state.settledVouchersCount} VOUCHERS", "TOTAL INVOICES", Icons.receipt_long_rounded, const Color(0xFF8B5CF6), isMobile)),
                            const SizedBox(width: 10),
                            Expanded(child: buildStatCard("ACTIVE TABLES", "${state.activeTablesCount} / ${state.totalTablesCount}", "OCCUPIED TABLES", Icons.table_restaurant_rounded, const Color(0xFF2563EB), isMobile)),
                            const SizedBox(width: 10),
                            Expanded(child: buildStatCard("PENDING KOT QTY", "${state.pendingKotCount} UNITS", "KITCHEN QUEUE", Icons.soup_kitchen_rounded, const Color(0xFFF59E0B), isMobile)),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // 3️⃣ DEPARTMENT REVENUE BREAKDOWN PANEL
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 14 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.pie_chart_rounded, size: isMobile ? 16 : 18, color: cyanPrimary),
                                const SizedBox(width: 8),
                                Text(
                                  "DEPARTMENT REVENUE BREAKDOWN",
                                  style: TextStyle(
                                    fontSize: isMobile ? 11.5 : 13,
                                    fontWeight: FontWeight.w900,
                                    color: darkSlateBg,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "REAL-TIME CONTRIBUTION RATIOS FROM SETTLED AUDIT HISTORY",
                              style: TextStyle(
                                fontSize: isMobile ? 8.5 : 9.5,
                                fontWeight: FontWeight.bold,
                                color: textMuted,
                              ),
                            ),
                            const Divider(height: 20, color: cardBorderColor),

                            buildProgressBarAuditItem("DOMESTIC / IMFL LIQUOR", "₹${state.liquorTotal.toStringAsFixed(2)}", liquorRatio, const Color(0xFF8B5CF6), isMobile),
                            buildProgressBarAuditItem("CRAFT BEER MASTER", "₹${state.beerTotal.toStringAsFixed(2)}", beerRatio, const Color(0xFF3B82F6), isMobile),
                            buildProgressBarAuditItem("MAIN KITCHEN FOOD ITEMS", "₹${state.foodTotal.toStringAsFixed(2)}", foodRatio, const Color(0xFFEA580C), isMobile),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}