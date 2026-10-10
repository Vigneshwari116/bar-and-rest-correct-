
import 'report_state.dart';

abstract class ReportEvent {}

class ChangeReportTypeEvent extends ReportEvent {
  final PosReportType reportType;
  ChangeReportTypeEvent(this.reportType);
}

class ChangeDateRangeEvent extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;
  ChangeDateRangeEvent(this.startDate, this.endDate);
}

class LoadReportDataEvent extends ReportEvent {}