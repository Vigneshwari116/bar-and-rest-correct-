/*
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  ReportBloc() : super(ReportState(startDate: DateTime.now(), endDate: DateTime.now())) {

    on<ChangeReportTypeEvent>((event, emit) {
      final now = DateTime.now();
      emit(state.copyWith(
        activeReport: event.reportType,
        startDate: now,
        endDate: now,
        reportData: [],
      ));
      add(LoadReportDataEvent());
    });

    on<ChangeDateRangeEvent>((event, emit) {
      emit(state.copyWith(
        startDate: event.startDate,
        endDate: event.endDate,
        reportData: [],
      ));
      add(LoadReportDataEvent());
    });

    on<LoadReportDataEvent>(_onLoadReportData);
  }

  Future<void> _onLoadReportData(LoadReportDataEvent event, Emitter<ReportState> emit) async {
    emit(state.copyWith(status: ReportStatus.loading));
    try {
      String targetPath;
      final startStr = DateFormat('yyyy-MM-dd').format(state.startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(state.endDate);

      switch (state.activeReport) {
        case PosReportType.dailySales:
          targetPath = '/api/v1/reports/daily-sales';
          break;
        case PosReportType.billwiseAbstract:
          targetPath = '/api/v1/reports/billwise-abstract';
          break;
        case PosReportType.foodAudit:
          targetPath = '/api/v1/reports/food-audit?start_date=$startStr&end_date=$endStr';
          break;
        case PosReportType.liquorAudit:
          targetPath = '/api/v1/reports/liquor-audit?start_date=$startStr&end_date=$endStr';
          break;

      // 🌟 DEDICATED REGULAR WAITER PERFORMANCE API CALL
        case PosReportType.waiterPerformance:
          targetPath = '/api/v1/reports/waiter-performance?start_date=$startStr&end_date=$endStr';
          break;

        case PosReportType.deletedItemsAudit:
          targetPath = '/api/v1/reports/deleted-items-audit';
          break;
      }

      final response = await apiClient.get(targetPath);
      print("report performance dasta $response");

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final dataset = response.data['data'] as List<dynamic>? ?? [];
        emit(state.copyWith(status: ReportStatus.loaded, reportData: dataset));
      } else {
        emit(state.copyWith(
          status: ReportStatus.error,
          errorMessage: "Failed to extract active reporting matrices.",
        ));
      }
    } catch (e) {
      emit(state.copyWith(status: ReportStatus.error, errorMessage: e.toString()));
    }
  }
}*/


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ApiClient apiClient = GetIt.I<ApiClient>();

  ReportBloc() : super(ReportState(startDate: DateTime.now(), endDate: DateTime.now())) {

    on<ChangeReportTypeEvent>((event, emit) {
      final now = DateTime.now();
      emit(state.copyWith(
        activeReport: event.reportType,
        startDate: now,
        endDate: now,
        reportData: [],
      ));
      add(LoadReportDataEvent());
    });

    on<ChangeDateRangeEvent>((event, emit) {
      emit(state.copyWith(
        startDate: event.startDate,
        endDate: event.endDate,
        reportData: [],
      ));
      add(LoadReportDataEvent());
    });

    on<LoadReportDataEvent>(_onLoadReportData);
  }

  Future<void> _onLoadReportData(LoadReportDataEvent event, Emitter<ReportState> emit) async {
    emit(state.copyWith(status: ReportStatus.loading));
    try {
      // 🌟 1. FETCH PRINTER CONFIGURATIONS IN PARALLEL
      List<dynamic> activePrinters = state.printers;
      try {
        final printerRes = await apiClient.get('/api/v1/pos/printers');
        if (printerRes != null && printerRes.data != null && printerRes.data['status'] == 'SUCCESS') {
          activePrinters = printerRes.data['data'] as List<dynamic>? ?? [];
        }
      } catch (pErr) {
        print("⚠️ [Printer Config Fetch Warning]: $pErr");
      }

      String targetPath;
      final startStr = DateFormat('yyyy-MM-dd').format(state.startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(state.endDate);

      switch (state.activeReport) {
        case PosReportType.dailySales:
          targetPath = '/api/v1/reports/daily-sales';
          break;
        case PosReportType.billwiseAbstract:
          targetPath = '/api/v1/reports/billwise-abstract';
          break;
        case PosReportType.foodAudit:
          targetPath = '/api/v1/reports/food-audit?start_date=$startStr&end_date=$endStr';
          break;
        case PosReportType.liquorAudit:
          targetPath = '/api/v1/reports/liquor-audit?start_date=$startStr&end_date=$endStr';
          break;

      // 🌟 DEDICATED REGULAR WAITER PERFORMANCE API CALL
        case PosReportType.waiterPerformance:
          targetPath = '/api/v1/reports/waiter-performance?start_date=$startStr&end_date=$endStr';
          break;

        case PosReportType.deletedItemsAudit:
          targetPath = '/api/v1/reports/deleted-items-audit';
          break;
      }

      final response = await apiClient.get(targetPath);
      print("report performance dataset $response");

      if (response != null && response.data != null && response.data['status'] == 'SUCCESS') {
        final dataset = response.data['data'] as List<dynamic>? ?? [];
        emit(state.copyWith(
          status: ReportStatus.loaded,
          reportData: dataset,
          printers: activePrinters, // 👈 2. Save Printers into State
        ));
      } else {
        emit(state.copyWith(
          status: ReportStatus.error,
          printers: activePrinters,
          errorMessage: "Failed to extract active reporting matrices.",
        ));
      }
    } catch (e) {
      emit(state.copyWith(status: ReportStatus.error, errorMessage: e.toString()));
    }
  }
}