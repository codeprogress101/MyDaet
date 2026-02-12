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

class DtsRepository {
  DtsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
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

  Stream<List<DtsDocument>> watchOfficeQueue(UserContext user) {
    Query<Map<String, dynamic>> query =
        _db.collection('dts_documents').orderBy('updatedAt', descending: true);
    if (!user.isSuperAdmin && user.officeId != null) {
      query = _db
          .collection('dts_documents')
          .where('currentOfficeId', isEqualTo: user.officeId)
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
    final year = DateTime.now().year;
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
      final qrCodeStatus =
          (qrCodeSnap.data()?['status'] ?? 'unused').toString();
      if (qrCodeStatus.toLowerCase() != 'unused') {
        throw Exception('QR code already used.');
      }

      final qrSnap = await tx.get(qrRef);
      if (qrSnap.exists) {
        throw Exception('QR code already used.');
      }

      final counterSnap = await tx.get(counterRef);
      final currentSeq =
          counterSnap.data()?['seq'] is int ? counterSnap.data()!['seq'] as int : 0;
      final nextSeq = currentSeq + 1;
      trackingNo =
          'DTS-$year-$officeCode-${nextSeq.toString().padLeft(4, '0')}';

      tx.set(counterRef, {'seq': nextSeq}, SetOptions(merge: true));
      tx.set(docRef, {
        'qrCode': qrCode,
        'trackingNo': trackingNo,
        'publicPinHash': pinHash,
        'title': title,
        'docType': docType,
        'sourceName': sourceName,
        'confidentiality': confidentiality,
        'status': 'RECEIVED',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': userContext.uid,
        'submittedByUid': submittedByUid,
        'currentOfficeId': currentOfficeId,
        'currentOfficeName': currentOfficeName,
        'currentCustodianUid': userContext.uid,
        'physicalLocation': null,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
        'pendingTransfer': null,
      });

      tx.set(qrRef, {
        'docId': docRef.id,
        'usedAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        qrCodeRef,
        {
          'status': 'used',
          'usedAt': FieldValue.serverTimestamp(),
          'usedByUid': userContext.uid,
          'docId': docRef.id,
        },
        SetOptions(merge: true),
      );

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'RECEIVED',
        'byUid': userContext.uid,
        'notes': 'Document received at Records.',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return DtsCreateResult(docId: docRef.id, trackingNo: trackingNo, pin: pin);
  }

  Future<Map<String, dynamic>> uploadCoverPhoto({
    required String docId,
    required File file,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'dts/$docId/cover/$ts.jpg';
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return {
      'path': path,
      'url': url,
      'uploadedAt': Timestamp.now(),
    };
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required String docId,
    required File file,
    required String name,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final path = 'dts/$docId/attachments/$ts-$safeName';
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return {
      'name': name,
      'path': path,
      'url': url,
      'uploadedAt': Timestamp.now(),
      'contentType': task.metadata?.contentType,
    };
  }

  Future<void> updateCoverPhoto({
    required String docId,
    required Map<String, dynamic> coverPhoto,
    required String actorUid,
  }) {
    final docRef = _db.collection('dts_documents').doc(docId);
    return _db.runTransaction((tx) async {
      tx.set(
        docRef,
        {
          'coverPhoto': coverPhoto,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'NOTE',
        'byUid': actorUid,
        'notes': 'Cover photo uploaded.',
        'attachments': [coverPhoto],
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> initiateTransfer({
    required String docId,
    required String fromOfficeId,
    required String toOfficeId,
    required String? toUid,
    required String actorUid,
  }) async {
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(
        docRef,
        {
          'pendingTransfer': {
            'fromOfficeId': fromOfficeId,
            'fromUid': actorUid,
            'toOfficeId': toOfficeId,
            'toUid': toUid,
            'initiatedAt': FieldValue.serverTimestamp(),
          },
          'status': 'IN_TRANSIT',
          'currentCustodianUid': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'TRANSFER_INITIATED',
        'byUid': actorUid,
        'fromOfficeId': fromOfficeId,
        'toOfficeId': toOfficeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmReceipt({
    required String docId,
    required String toOfficeId,
    required String toOfficeName,
    required String receiverUid,
  }) async {
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(
        docRef,
        {
          'currentOfficeId': toOfficeId,
          'currentOfficeName': toOfficeName,
          'currentCustodianUid': receiverUid,
          'pendingTransfer': null,
          'status': 'WITH_OFFICE',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'TRANSFER_CONFIRMED',
        'byUid': receiverUid,
        'toOfficeId': toOfficeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
    required String actorUid,
  }) async {
    final normalized = DtsStatusHelper.normalize(status);
    final docRef = _db.collection('dts_documents').doc(docId);
    await _db.runTransaction((tx) async {
      tx.set(
        docRef,
        {
          'status': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'STATUS_CHANGED',
        'byUid': actorUid,
        'notes': 'Status updated to ${DtsStatusHelper.label(normalized)}.',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addNote({
    required String docId,
    required String actorUid,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) {
    final docRef = _db.collection('dts_documents').doc(docId);
    return _db.runTransaction((tx) async {
      tx.set(
        docRef,
        {'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      final timelineRef = docRef.collection('timeline').doc();
      tx.set(timelineRef, {
        'type': 'NOTE',
        'byUid': actorUid,
        'notes': notes,
        'attachments': attachments,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<DtsTrackingResult> trackByTrackingNo({
    required String trackingNo,
    required String pin,
  }) async {
    final callable = _functions.httpsCallable('dtsTrackByTrackingNo');
    final result = await callable.call({
      'trackingNo': trackingNo,
      'pin': pin,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return DtsTrackingResult.fromMap(data);
  }

  Future<List<String>> generateQrCodes({
    int count = 10,
    String prefix = 'DTS-QR',
  }) async {
    final callable = _functions.httpsCallable('generateDtsQrCodes');
    final result = await callable.call({
      'count': count,
      'prefix': prefix,
    });
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

  Future<String> exportQrZip({
    required List<String> codes,
  }) async {
    final callable = _functions.httpsCallable('exportDtsQrZip');
    final result = await callable.call({
      'codes': codes,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['downloadUrl'] ?? '').toString();
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
