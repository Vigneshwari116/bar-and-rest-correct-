abstract class DashboardEvent {}

class FetchDashboardDataEvent extends DashboardEvent {}

/////////////////////////////////////////////////////////////
enum DashboardStatus { initial, loading, loaded, error }

class DashboardState {
  final DashboardStatus status;
  final double grossSales;
  final double totalDiscounts;
  final int activeTablesCount;
  final int totalTablesCount;
  final int pendingKotCount;
  final int settledVouchersCount;
  final List<dynamic> liveOrdersStream;
  final double liquorShareRatio;
  final double beerShareRatio;
  final double foodShareRatio;
  final double liquorTotal;
  final double beerTotal;
  final double foodTotal;
  final String errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.grossSales = 0.0,
    this.totalDiscounts = 0.0,
    this.activeTablesCount = 0,
    this.totalTablesCount = 0,
    this.pendingKotCount = 0,
    this.settledVouchersCount = 0,
    this.liveOrdersStream = const [],
    this.liquorShareRatio = 0.0,
    this.beerShareRatio = 0.0,
    this.foodShareRatio = 0.0,
    this.liquorTotal = 0.0,
    this.beerTotal = 0.0,
    this.foodTotal = 0.0,
    this.errorMessage = '',
  });

  DashboardState copyWith({
    DashboardStatus? status,
    double? grossSales,
    double? totalDiscounts,
    int? activeTablesCount,
    int? totalTablesCount,
    int? pendingKotCount,
    int? settledVouchersCount,
    List<dynamic>? liveOrdersStream,
    double? liquorShareRatio,
    double? beerShareRatio,
    double? foodShareRatio,
    double? liquorTotal,
    double? beerTotal,
    double? foodTotal,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      grossSales: grossSales ?? this.grossSales,
      totalDiscounts: totalDiscounts ?? this.totalDiscounts,
      activeTablesCount: activeTablesCount ?? this.activeTablesCount,
      totalTablesCount: totalTablesCount ?? this.totalTablesCount,
      pendingKotCount: pendingKotCount ?? this.pendingKotCount,
      settledVouchersCount: settledVouchersCount ?? this.settledVouchersCount,
      liveOrdersStream: liveOrdersStream ?? this.liveOrdersStream,
      liquorShareRatio: liquorShareRatio ?? this.liquorShareRatio,
      beerShareRatio: beerShareRatio ?? this.beerShareRatio,
      foodShareRatio: foodShareRatio ?? this.foodShareRatio,
      liquorTotal: liquorTotal ?? this.liquorTotal,
      beerTotal: beerTotal ?? this.beerTotal,
      foodTotal: foodTotal ?? this.foodTotal,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardState &&
        other.status == status &&
        other.grossSales == grossSales &&
        other.activeTablesCount == activeTablesCount &&
        other.liveOrdersStream.length == liveOrdersStream.length &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => status.hashCode ^ grossSales.hashCode ^ activeTablesCount.hashCode ^ liveOrdersStream.length.hashCode;
}