import 'package:cloud_firestore/cloud_firestore.dart';

class DtsPendingTransfer {
  final String fromOfficeId;
  final String? fromUid;
  final String toOfficeId;
  final String? toOfficeName;
  final String? toUid;
  final String? previousStatus;
  final DateTime? initiatedAt;

  const DtsPendingTransfer({
    required this.fromOfficeId,
    required this.toOfficeId,
    this.toOfficeName,
    this.fromUid,
    this.toUid,
    this.previousStatus,
    this.initiatedAt,
  });

  factory DtsPendingTransfer.fromMap(Map<String, dynamic> data) {
    final initiatedRaw = data['initiatedAt'];
    return DtsPendingTransfer(
      fromOfficeId: (data['fromOfficeId'] ?? '').toString(),
      fromUid: (data['fromUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['fromUid'] ?? '').toString(),
      toOfficeId: (data['toOfficeId'] ?? '').toString(),
      toOfficeName: (data['toOfficeName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['toOfficeName'] ?? '').toString(),
      toUid: (data['toUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['toUid'] ?? '').toString(),
      previousStatus: (data['previousStatus'] ?? '').toString().trim().isEmpty
          ? null
          : (data['previousStatus'] ?? '').toString(),
      initiatedAt: initiatedRaw is Timestamp ? initiatedRaw.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromOfficeId': fromOfficeId,
      'fromUid': fromUid,
      'toOfficeId': toOfficeId,
      'toOfficeName': toOfficeName,
      'toUid': toUid,
      'previousStatus': previousStatus,
      'initiatedAt': initiatedAt == null
          ? null
          : Timestamp.fromDate(initiatedAt!),
    };
  }
}

class DtsDocument {
  final String id;
  final String qrCode;
  final String trackingNo;
  final String? trackingPin;
  final String title;
  final String docType;
  final String? sourceName;
  final String confidentiality;
  final String status;
  final String? createdByUid;
  final String? submittedByUid;
  final String currentOfficeId;
  final String? currentOfficeName;
  final String? currentCustodianUid;
  final Map<String, dynamic>? physicalLocation;
  final Map<String, dynamic>? coverPhoto;
  final DtsPendingTransfer? pendingTransfer;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DtsDocument({
    required this.id,
    required this.qrCode,
    required this.trackingNo,
    this.trackingPin,
    required this.title,
    required this.docType,
    required this.confidentiality,
    required this.status,
    required this.currentOfficeId,
    this.sourceName,
    this.createdByUid,
    this.submittedByUid,
    this.currentOfficeName,
    this.currentCustodianUid,
    this.physicalLocation,
    this.coverPhoto,
    this.pendingTransfer,
    this.createdAt,
    this.updatedAt,
  });

  factory DtsDocument.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DtsDocument(
      id: doc.id,
      qrCode: (data['qrCode'] ?? '').toString(),
      trackingNo: (data['trackingNo'] ?? '').toString(),
      trackingPin: (data['trackingPin'] ?? '').toString().trim().isEmpty
          ? null
          : (data['trackingPin'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled').toString(),
      docType: (data['docType'] ?? '').toString(),
      sourceName: (data['sourceName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['sourceName'] ?? '').toString(),
      confidentiality: (data['confidentiality'] ?? 'public').toString(),
      status: (data['status'] ?? 'RECEIVED').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['createdByUid'] ?? '').toString(),
      submittedByUid: (data['submittedByUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['submittedByUid'] ?? '').toString(),
      currentOfficeId: (data['currentOfficeId'] ?? '').toString(),
      currentOfficeName:
          (data['currentOfficeName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['currentOfficeName'] ?? '').toString(),
      currentCustodianUid:
          (data['currentCustodianUid'] ?? '').toString().trim().isEmpty
          ? null
          : (data['currentCustodianUid'] ?? '').toString(),
      physicalLocation: data['physicalLocation'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              data['physicalLocation'] as Map<String, dynamic>,
            )
          : null,
      coverPhoto: data['coverPhoto'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              data['coverPhoto'] as Map<String, dynamic>,
            )
          : null,
      pendingTransfer: data['pendingTransfer'] is Map<String, dynamic>
          ? DtsPendingTransfer.fromMap(
              Map<String, dynamic>.from(
                data['pendingTransfer'] as Map<String, dynamic>,
              ),
            )
          : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
