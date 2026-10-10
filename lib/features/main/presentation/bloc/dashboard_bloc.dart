import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/network/api_client.dart';
import 'dashboard_event.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  DashboardBloc() : super(const DashboardState()) {
    on<FetchDashboardDataEvent>(_onFetchDashboardData);
  }

  Future<void> _onFetchDashboardData(FetchDashboardDataEvent event, Emitter<DashboardState> emit) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final response = await apiClient.get('/api/v1/pos/dashboard/stats');
      final data = response.data['data'] ?? {};

      final double sales = (data['gross_sales'] ?? 0.0).toDouble();
      final double discounts = (data['total_discounts'] ?? 0.0).toDouble();
      final int activeTables = (data['active_tables'] ?? 0).toInt();
      final int totalTables = (data['total_tables'] ?? 0).toInt();
      final int pendingKots = (data['pending_kot_count'] ?? 0).toInt();
      final int settledBills = (data['settled_vouchers_count'] ?? 0).toInt();
      final List<dynamic> stream = data['live_orders_stream'] ?? [];

      final double lqr = (data['liquor_total'] ?? 0.0).toDouble();
      final double ber = (data['beer_total'] ?? 0.0).toDouble();
      final double fd = (data['food_total'] ?? 0.0).toDouble();

      double totalSum = lqr + ber + fd;
      double lqrRatio = totalSum > 0 ? (lqr / totalSum) : 0.0;
      double berRatio = totalSum > 0 ? (ber / totalSum) : 0.0;
      double fdRatio = totalSum > 0 ? (fd / totalSum) : 0.0;

      emit(state.copyWith(
        status: DashboardStatus.loaded,
        grossSales: sales,
        totalDiscounts: discounts,
        activeTablesCount: activeTables,
        totalTablesCount: totalTables,
        pendingKotCount: pendingKots,
        settledVouchersCount: settledBills,
        liveOrdersStream: stream,
        liquorTotal: lqr,
        beerTotal: ber,
        foodTotal: fd,
        liquorShareRatio: lqrRatio,
        beerShareRatio: berRatio,
        foodShareRatio: fdRatio,
      ));
    } catch (e) {
      emit(state.copyWith(status: DashboardStatus.error, errorMessage: "Live Ops Feed Disconnected"));
    }
  }
}