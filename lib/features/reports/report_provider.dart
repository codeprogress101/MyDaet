import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'report_model.dart';

final reportsProvider =
    NotifierProvider<ReportsController, List<CitizenReport>>(ReportsController.new);

class ReportsController extends Notifier<List<CitizenReport>> {
  @override
  List<CitizenReport> build() {
    // Demo data for badge (later replace with Firestore)
    return [
      CitizenReport(id: 'R1', status: ReportStatus.submitted),
      CitizenReport(id: 'R2', status: ReportStatus.inProgress),
      CitizenReport(id: 'R3', status: ReportStatus.resolved),
    ];
  }

  int get unresolvedCount =>
      state.where((r) => r.status != ReportStatus.resolved).length;

  // Optional helper for later use:
  void add(CitizenReport report) => state = [...state, report];
}
