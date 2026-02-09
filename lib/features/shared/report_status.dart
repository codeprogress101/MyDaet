enum ReportStatus {
  submitted,
  inReview,
  assigned,
  resolved,
  rejected,
}

class ReportStatusHelper {
  static const values = [
    "submitted",
    "in_review",
    "assigned",
    "resolved",
    "rejected",
  ];

  static String normalize(String? raw) {
    final v = (raw ?? "submitted").trim().toLowerCase();
    if (values.contains(v)) return v;
    return "submitted";
  }

  static String pretty(String raw) {
    switch (normalize(raw)) {
      case "submitted":
        return "Submitted";
      case "in_review":
        return "In review";
      case "assigned":
        return "Assigned";
      case "resolved":
        return "Resolved";
      case "rejected":
        return "Rejected";
      default:
        return "Submitted";
    }
  }
}
