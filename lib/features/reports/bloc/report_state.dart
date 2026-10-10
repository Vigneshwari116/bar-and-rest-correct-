enum PosReportType {
  dailySales,
  billwiseAbstract,
  liquorAudit,
  foodAudit,
  waiterPerformance,
  deletedItemsAudit,
}

enum ReportStatus { initial, loading, loaded, error }

class ReportState {
  final ReportStatus status;
  final PosReportType activeReport;
  final DateTime startDate;
  final DateTime endDate;
  final List<dynamic> reportData;
  final List<dynamic> printers; // 👈 1. Printers Field Added
  final String errorMessage;

  const ReportState({
    this.status = ReportStatus.initial,
    this.activeReport = PosReportType.dailySales,
    required this.startDate,
    required this.endDate,
    this.reportData = const [],
    this.printers = const [], // 👈 2. Default Empty List
    this.errorMessage = '',
  });

  double get totalGrossVolume {
    return reportData.fold(
      0.0,
          (sum, item) =>
      sum +
          (double.tryParse(
            item['grand_total']?.toString() ??
                item['total_revenue']?.toString() ??
                item['amount']?.toString() ??
                '0',
          ) ??
              0.0),
    );
  }

  double get liquorVolume {
    return reportData.fold(0.0, (sum, item) {
      if (item['category_type']?.toString().toUpperCase() == 'LIQUOR') {
        return sum +
            (double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0);
      }
      return sum +
          (double.tryParse(item['liquor_total']?.toString() ?? '0') ?? 0.0);
    });
  }

  double get foodVolume {
    return reportData.fold(0.0, (sum, item) {
      if (item['category_type']?.toString().toUpperCase() == 'FOOD') {
        return sum +
            (double.tryParse(item['total_revenue']?.toString() ?? '0') ?? 0.0);
      }
      return sum +
          (double.tryParse(item['food_total']?.toString() ?? '0') ?? 0.0);
    });
  }

  ReportState copyWith({
    ReportStatus? status,
    PosReportType? activeReport,
    DateTime? startDate,
    DateTime? endDate,
    List<dynamic>? reportData,
    List<dynamic>? printers, // 👈 3. CopyWith Parameter Added
    String? errorMessage,
  }) {
    return ReportState(
      status: status ?? this.status,
      activeReport: activeReport ?? this.activeReport,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reportData: reportData ?? this.reportData,
      printers: printers ?? this.printers, // 👈 4. Printers Copy
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}