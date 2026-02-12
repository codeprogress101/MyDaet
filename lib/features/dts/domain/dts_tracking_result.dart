class DtsTrackingResult {
  final String trackingNo;
  final String? title;
  final String status;
  final String? currentOfficeName;
  final DateTime? lastUpdated;
  final String? instructions;

  const DtsTrackingResult({
    required this.trackingNo,
    required this.status,
    this.title,
    this.currentOfficeName,
    this.lastUpdated,
    this.instructions,
  });

  factory DtsTrackingResult.fromMap(Map<String, dynamic> data) {
    DateTime? updated;
    if (data['lastUpdated'] is int) {
      updated = DateTime.fromMillisecondsSinceEpoch(data['lastUpdated'] as int);
    } else if (data['lastUpdated'] is String) {
      updated = DateTime.tryParse(data['lastUpdated'] as String);
    }

    return DtsTrackingResult(
      trackingNo: (data['trackingNo'] ?? '').toString(),
      title:
          (data['title'] ?? '').toString().trim().isEmpty
              ? null
              : (data['title'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      currentOfficeName:
          (data['currentOfficeName'] ?? '').toString().trim().isEmpty
              ? null
              : (data['currentOfficeName'] ?? '').toString(),
      lastUpdated: updated,
      instructions:
          (data['instructions'] ?? '').toString().trim().isEmpty
              ? null
              : (data['instructions'] ?? '').toString(),
    );
  }
}
