import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../services/permissions.dart';
import '../domain/dts_document.dart';
import '../domain/dts_timeline_event.dart';
import '../domain/dts_tracking_result.dart';
import '../presentation/dts_status.dart';

class DtsCreateResult {
  final String docId;
  final String trackingNo;
  final String pin;

  const DtsCreateResult({
    required this.docId,
    required this.trackingNo,
    required this.pin,
  });
}

class DtsQrExportResult {
  final int count;
  final String path;
  final String? downloadUrl;

  const DtsQrExportResult({
    required this.count,
    required this.path,
    this.downloadUrl,
  });
}

class DtsRepository {
  DtsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Future<String?> resolveDocIdForQr(String qrCode) async {
    final snap = await _db.collection('dts_qr_index').doc(qrCode).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return (data['docId'] ?? '').toString().trim().isEmpty
        ? null
        : (data['docId'] ?? '').toString();
  }

  Future<String?> resolveQrImageUrl(String qrCode) async {
    final qrDoc = await _db.collection('dts_qr_codes').doc(qrCode).get();
    if (!qrDoc.exists) return null;
    final data = qrDoc.data();
    if (data == null) return null;
    final imagePath = (data['imagePath'] ?? '').toString().trim();
    if (imagePath.isEmpty) return null;
    try {
      return await _storage.ref(imagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Stream<List<DtsDocument>> watchOfficeQueue(UserContext user) {
    Query<Map<String, dynamic>> query;
    if (user.isSuperAdmin) {
      query = _db
          .collection('dts_documents')
          .orderBy('updatedAt', descending: true);
    } else if (user.officeId != null && user.officeId!.trim().isNotEmpty) {
      query = _db
          .collection('dts_documents')
          .where('currentOfficeId', isEqualTo: user.officeId)
          .orderBy('updatedAt', descending: true);
    } else if (user.officeName != null && user.officeName!.trim().isNotEmpty) {
      query = _db
          .collection('dts_documents')
          .where('currentOfficeName', isEqualTo: user.officeName)
          .orderBy('updatedAt', descending: true);
    } else {
      // Misconfigured staff account fallback: show documents they created only.
      query = _db
          .collection('dts_documents')
          .where('createdByUid', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(DtsDocument.fromDoc).toList(),
    );
  }

  Stream<List<DtsDocument>> watchMyDocuments(String uid) {
    return _db
        .collection('dts_documents')
        .where('submittedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DtsDocument.fromDoc).toList());
  }

  Stream<List<DtsTimelineEvent>> watchTimeline(String docId) {
    return _db
        .collection('dts_documents')
        .doc(docId)
        .collection('timeline')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DtsTimelineEvent.fromDoc).toList());
  }

  Future<DtsCreateResult> createDocument({
    required String qrCode,
    required String title,
    required String docType,
    required String confidentiality,
    required String currentOfficeId,
    required String currentOfficeName,
    required String? sourceName,
    required UserContext userContext,
    DateTime? dueAt,
    String? submittedByUid,
  }) async {
    final docRef = _db.collection('dts_documents').doc();
    final serverNow = await _getServerNowUtc();
    final serverNowTs = Timestamp.fromDate(serverNow);
    final year = serverNow.toUtc().add(const Duration(hours: 8)).year;
    final counterRef = _db.collection('dts_counters').doc(year.toString());
    final qrRef = _db.collection('dts_qr_index').doc(qrCode);
    final qrCodeRef = _db.collection('dts_qr_codes').doc(qrCode);

    final pin = _generatePin();
    final pinHash = _sha256(pin);
    final officeCode = _officeCodeFromName(currentOfficeName);

    late String trackingNo;

    await _db.runTransaction((tx) async {
      final qrCodeSnap = await tx.get(qrCodeRef);
      if (!qrCodeSnap.exists) {
        throw Exception('QR code not found. Generate a QR sticker first.');
      }
      final qrCodeStatus = (qrCodeSnap.data()?['status'] ?? 'unused')
          .toString();
      if (qrCodeStatus.toLowerCase() != 'unused') {
        throw Exception('QR code already used.');
      }

      final qrSnap = await tx.get(qrRef);
      if (qrSnap.exists) {
        throw Exception('QR code already used.');
      }

      final counterSnap = await tx.get(counterRef);
      final currentSeq = counterSnap.data()?['seq'] is int
          ? counterSnap.data()!['seq'] as int
          : 0;
      final nextSeq = currentSeq + 1;
      trackingNo =
          'DTS-$year-$officeCode-${nextSeq.toString().padLeft(4, '0')}';

      tx.set(counterRef, {'seq': nextSeq}, SetOptions(merge: true));
      tx.set(docRef, {
        'qrCode': qrCode,
        'trackingNo': trackingNo,
        'trackingPin': pin,
        'publicPinHash': pinHash,
        'title': title,
        'docType': docType,
        'sourceName': sourceName,
        'confidentiality': confidentiality,
        'status': 'RECEIVED',
        'createdAt': serverNowTs,
        'updatedAt': serverNowTs,
        'createdByUid': userContext.uid,
        'submittedByUid': submittedByUid,
        'saveToResidentAccount': submittedByUid != null,
        'currentOfficeId': currentOfficeId,
        'currentOfficeName': currentOfficeName,
        'currentCustodianUid': userContext.uid,
        'physicalLocation': null,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
        'pendingTransfer': null,
      });

      tx.set(qrRef, {'docId': docRef.id, 'usedAt': serverNowTs});

      tx.set(qrCodeRef, {
        'status': 'used',
        'usedAt': serverNowTs,
        'usedByUid': userContext.uid,
        'docId': docRef.id,
      }, SetOptions(merge: true));

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'RECEIVED',
        'byUid': userContext.uid,
        'notes': 'Document received at Records.',
        'createdAt': serverNowTs,
      });
    });

    return DtsCreateResult(docId: docRef.id, trackingNo: trackingNo, pin: pin);
  }

  Future<DateTime> _getServerNowUtc() async {
    try {
      final callable = _functions.httpsCallable('getServerTime');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final raw = data['epochMs'];
      final epochMs = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (epochMs == null) {
        throw Exception('Invalid server time response.');
      }
      return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Unable to get server time (${e.code}).');
    } catch (e) {
      throw Exception('Unable to get server time: $e');
    }
  }

  Future<DateTime> getServerNowUtc() => _getServerNowUtc();

  Future<Map<String, dynamic>> uploadCoverPhoto({
    required String docId,
    required File file,
  }) async {
    final serverNow = await _getServerNowUtc();
    final ts = serverNow.millisecondsSinceEpoch;
    final path = 'dts/$docId/cover/$ts.jpg';
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return {
      'path': path,
      'url': url,
      'uploadedAt': Timestamp.fromDate(serverNow),
    };
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required String docId,
    required File file,
    required String name,
  }) async {
    final serverNow = await _getServerNowUtc();
    final ts = serverNow.millisecondsSinceEpoch;
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final path = 'dts/$docId/attachments/$ts-$safeName';
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return {
      'name': name,
      'path': path,
      'url': url,
      'uploadedAt': Timestamp.fromDate(serverNow),
      'contentType': task.metadata?.contentType,
    };
  }

  Future<void> updateCoverPhoto({
    required String docId,
    required Map<String, dynamic> coverPhoto,
    required String actorUid,
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    return _db.runTransaction((tx) async {
      tx.set(docRef, {
        'coverPhoto': coverPhoto,
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));
      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'NOTE',
        'byUid': actorUid,
        'notes': 'Cover photo uploaded.',
        'attachments': [coverPhoto],
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> initiateTransfer({
    required String docId,
    required String fromOfficeId,
    required String toOfficeId,
    required String? toOfficeName,
    required String? toUid,
    required String previousStatus,
    required String actorUid,
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(docRef, {
        'pendingTransfer': {
          'fromOfficeId': fromOfficeId,
          'fromUid': actorUid,
          'toOfficeId': toOfficeId,
          'toOfficeName': toOfficeName,
          'toUid': toUid,
          'previousStatus': DtsStatusHelper.normalize(previousStatus),
          'initiatedAt': serverNowTs,
        },
        'status': 'IN_TRANSIT',
        'currentCustodianUid': null,
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'TRANSFER_INITIATED',
        'byUid': actorUid,
        'fromOfficeId': fromOfficeId,
        'toOfficeId': toOfficeId,
        'notes': toOfficeName?.trim().isNotEmpty == true
            ? 'Transfer initiated to $toOfficeName.'
            : 'Transfer initiated.',
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> cancelTransfer({
    required String docId,
    required String actorUid,
    required String fallbackOfficeId,
    required String fallbackOfficeName,
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      final docSnap = await tx.get(docRef);
      if (!docSnap.exists) {
        throw Exception('Document not found.');
      }
      final docData = docSnap.data() ?? <String, dynamic>{};
      final pendingRaw = docData['pendingTransfer'];
      if (pendingRaw is! Map<String, dynamic>) {
        throw Exception('No pending transfer to cancel.');
      }
      final pending = Map<String, dynamic>.from(pendingRaw);
      final fromOfficeId = (pending['fromOfficeId'] ?? fallbackOfficeId)
          .toString()
          .trim();
      final previousStatus = DtsStatusHelper.normalize(
        (pending['previousStatus'] ?? 'WITH_OFFICE').toString(),
      );

      tx.set(docRef, {
        'pendingTransfer': null,
        'status': previousStatus,
        'currentOfficeId': fromOfficeId.isEmpty
            ? fallbackOfficeId
            : fromOfficeId,
        'currentOfficeName': fallbackOfficeName,
        'currentCustodianUid': actorUid,
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'RETURNED',
        'byUid': actorUid,
        'fromOfficeId': pending['fromOfficeId'],
        'toOfficeId': pending['toOfficeId'],
        'notes': 'Transfer cancelled while in transit.',
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> rejectTransfer({
    required String docId,
    required String actorUid,
    required String reason,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw Exception('Document not found.');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final pendingRaw = data['pendingTransfer'];
      if (pendingRaw is! Map<String, dynamic>) {
        throw Exception('No pending transfer to reject.');
      }
      final pending = Map<String, dynamic>.from(pendingRaw);
      final fromOfficeId = (pending['fromOfficeId'] ?? '').toString().trim();
      final previousStatus = DtsStatusHelper.normalize(
        (pending['previousStatus'] ?? 'WITH_OFFICE').toString(),
      );

      tx.set(docRef, {
        'pendingTransfer': null,
        'status': previousStatus,
        if (fromOfficeId.isNotEmpty) 'currentOfficeId': fromOfficeId,
        'currentCustodianUid': pending['fromUid'],
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'RETURNED',
        'byUid': actorUid,
        'fromOfficeId': pending['toOfficeId'],
        'toOfficeId': pending['fromOfficeId'],
        'notes': 'Transfer rejected: $reason',
        'attachments': attachments,
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> confirmReceipt({
    required String docId,
    required String toOfficeId,
    required String toOfficeName,
    required String receiverUid,
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(docRef, {
        'currentOfficeId': toOfficeId,
        'currentOfficeName': toOfficeName,
        'currentCustodianUid': receiverUid,
        'pendingTransfer': null,
        'status': 'WITH_OFFICE',
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'TRANSFER_CONFIRMED',
        'byUid': receiverUid,
        'toOfficeId': toOfficeId,
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
    required String actorUid,
    String? actorName,
  }) async {
    final normalized = DtsStatusHelper.normalize(status);
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(docRef, {
        'status': normalized,
        'updatedAt': serverNowTs,
      }, SetOptions(merge: true));
      final timelineRef = docRef.collection('timeline').doc();
      final safeActorName = actorName?.trim();
      final label = DtsStatusHelper.label(normalized);
      tx.set(timelineRef, {
        'type': 'STATUS_CHANGED',
        'byUid': actorUid,
        'notes': safeActorName == null || safeActorName.isEmpty
            ? 'Status updated to $label.'
            : 'Status updated to $label by $safeActorName.',
        if (safeActorName != null && safeActorName.isNotEmpty)
          'byName': safeActorName,
        'status': normalized,
        'createdAt': serverNowTs,
      });
    });
  }

  Future<void> addNote({
    required String docId,
    required String actorUid,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final serverNowTs = Timestamp.fromDate(await _getServerNowUtc());
    final docRef = _db.collection('dts_documents').doc(docId);
    return _db.runTransaction((tx) async {
      tx.set(docRef, {'updatedAt': serverNowTs}, SetOptions(merge: true));
      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'NOTE',
        'byUid': actorUid,
        'notes': notes,
        'attachments': attachments,
        'createdAt': serverNowTs,
      });
    });
  }

  Future<DtsTrackingResult> trackByTrackingNo({
    required String trackingNo,
    required String pin,
  }) async {
    final callable = _functions.httpsCallable('dtsTrackByTrackingNo');
    final result = await callable.call({'trackingNo': trackingNo, 'pin': pin});
    final data = Map<String, dynamic>.from(result.data as Map);
    return DtsTrackingResult.fromMap(data);
  }

  Future<void> saveTrackedDocumentToAccount({
    required String trackingNo,
    required String pin,
  }) async {
    final callable = _functions.httpsCallable('dtsSaveTrackedDocument');
    await callable.call({'trackingNo': trackingNo, 'pin': pin});
  }

  Future<List<String>> generateQrCodes({
    int count = 10,
    String prefix = 'DTS-QR',
  }) async {
    final callable = _functions.httpsCallable('generateDtsQrCodes');
    final result = await callable.call({'count': count, 'prefix': prefix});
    final data = Map<String, dynamic>.from(result.data as Map);
    final codes = <String>[];
    if (data['codes'] is List) {
      for (final item in data['codes'] as List) {
        if (item == null) continue;
        final text = item.toString().trim();
        if (text.isNotEmpty) codes.add(text);
      }
    }
    return codes;
  }

  Future<DtsQrExportResult> exportQrZip({required List<String> codes}) async {
    final callable = _functions.httpsCallable('exportDtsQrZip');
    final result = await callable.call({'codes': codes});
    final data = Map<String, dynamic>.from(result.data as Map);
    final rawUrl = (data['downloadUrl'] ?? '').toString().trim();
    final rawPath = (data['path'] ?? '').toString().trim();
    final rawCount = data['count'];
    final count = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? codes.length;

    return DtsQrExportResult(
      count: count,
      path: rawPath,
      downloadUrl: rawUrl.isEmpty ? null : rawUrl,
    );
  }

  String _generatePin() {
    final rng = Random.secure();
    final value = rng.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _officeCodeFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'OFF';
    final match = RegExp(r'\\(([^)]+)\\)').firstMatch(trimmed);
    if (match != null) {
      final code = match.group(1)?.trim() ?? '';
      if (code.isNotEmpty) return code.toUpperCase();
    }

    const stopwords = {
      'of',
      'the',
      'and',
      'office',
      'unit',
      'municipal',
      'department',
    };
    final words = trimmed
        .replaceAll(RegExp(r'[^A-Za-z\\s]'), ' ')
        .split(RegExp(r'\\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final letters = words
        .where((w) => !stopwords.contains(w.toLowerCase()))
        .map((w) => w[0].toUpperCase())
        .join();
    if (letters.isNotEmpty && letters.length <= 6) return letters;
    if (letters.length > 6) return letters.substring(0, 6);
    return 'OFF';
  }
}
