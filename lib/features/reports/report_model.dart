enum ReportStatus { submitted, inProgress, resolved, rejected }

class CitizenReport {
  final String id;
  final ReportStatus status;

  CitizenReport({
    required this.id,
    required this.status,
  });
}
