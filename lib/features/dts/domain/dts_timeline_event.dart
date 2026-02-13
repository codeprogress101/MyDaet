import 'package:cloud_firestore/cloud_firestore.dart';

class DtsTimelineEvent {
  final String id;
  final String type;
  final String? byUid;
  final String? byName;
  final String? notes;
  final String? fromOfficeId;
  final String? toOfficeId;
  final List<Map<String, dynamic>> attachments;
  final DateTime? createdAt;

  const DtsTimelineEvent({
    required this.id,
    required this.type,
    this.byUid,
    this.byName,
    this.notes,
    this.fromOfficeId,
    this.toOfficeId,
    this.attachments = const [],
    this.createdAt,
  });

  factory DtsTimelineEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final attachments = <Map<String, dynamic>>[];
    final rawAttachments = data['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          attachments.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return DtsTimelineEvent(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      byUid: (data['byUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['byUid'] ?? '').toString(),
      byName: (data['byName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['byName'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString().trim().isEmpty
          ? null
          : (data['notes'] ?? '').toString(),
      fromOfficeId: (data['fromOfficeId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['fromOfficeId'] ?? '').toString(),
      toOfficeId: (data['toOfficeId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['toOfficeId'] ?? '').toString(),
      attachments: attachments,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
