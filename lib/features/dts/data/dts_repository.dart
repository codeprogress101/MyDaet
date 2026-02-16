import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/observability_service.dart';
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

class DtsQueuedActionException implements Exception {
  const DtsQueuedActionException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DtsOfflineConflict {
  const DtsOfflineConflict({
    required this.action,
    required this.reason,
    required this.queuedAtEpochMs,
    required this.resolvedAtEpochMs,
    this.docId,
  });

  final String action;
  final String reason;
  final int queuedAtEpochMs;
  final int resolvedAtEpochMs;
  final String? docId;

  factory DtsOfflineConflict.fromMap(Map<String, dynamic> map) {
    return DtsOfflineConflict(
      action: (map['action'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      queuedAtEpochMs: (map['queuedAtEpochMs'] is int)
          ? map['queuedAtEpochMs'] as int
          : int.tryParse('${map['queuedAtEpochMs'] ?? 0}') ?? 0,
      resolvedAtEpochMs: (map['resolvedAtEpochMs'] is int)
          ? map['resolvedAtEpochMs'] as int
          : int.tryParse('${map['resolvedAtEpochMs'] ?? 0}') ?? 0,
      docId: (map['docId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['docId'] ?? '').toString(),
    );
  }
}

class DtsOpsHealthResult {
  const DtsOpsHealthResult({
    required this.backendBuild,
    required this.runtimeNode,
    required this.nowIso,
    required this.driftDetected,
    required this.callableChecks,
  });

  final String backendBuild;
  final String runtimeNode;
  final String nowIso;
  final bool driftDetected;
  final Map<String, bool> callableChecks;
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
  static const String _offlineQueueKey = 'dts_offline_queue_v1';
  static const String _offlineConflictKey = 'dts_offline_conflicts_v1';
  static const String _opsExpectedBackendBuild = '2026.02.16.1';

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
    final pinSalt = _generatePinSalt();
    final pinHash = _hashPin(pin, pinSalt);
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
        'publicPinSalt': pinSalt,
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
      final data = await _callWithRetry<Map<String, dynamic>>(
        'getServerTime',
        const <String, dynamic>{},
      );
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
    await _callCallableOrQueue<void>(
      functionName: 'dtsSetCoverPhoto',
      payload: {'docId': docId, 'actorUid': actorUid, 'coverPhoto': coverPhoto},
      queueActionName: 'dtsSetCoverPhoto',
      maxAttempts: 2,
    );
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
    await _callCallableOrQueue<void>(
      functionName: 'dtsInitiateTransfer',
      payload: {
        'docId': docId,
        'toOfficeId': toOfficeId,
        'toOfficeName': toOfficeName,
        'toUid': toUid,
        'fromOfficeId': fromOfficeId,
        'previousStatus': DtsStatusHelper.normalize(previousStatus),
        'actorUid': actorUid,
      },
      queueActionName: 'dtsInitiateTransfer',
      maxAttempts: 2,
    );
  }

  Future<void> cancelTransfer({
    required String docId,
    required String actorUid,
    required String fallbackOfficeId,
    required String fallbackOfficeName,
  }) async {
    await _callCallableOrQueue<void>(
      functionName: 'dtsCancelTransfer',
      payload: {
        'docId': docId,
        'actorUid': actorUid,
        'fallbackOfficeId': fallbackOfficeId,
        'fallbackOfficeName': fallbackOfficeName,
      },
      queueActionName: 'dtsCancelTransfer',
      maxAttempts: 2,
    );
  }

  Future<void> rejectTransfer({
    required String docId,
    required String actorUid,
    required String reason,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _callCallableOrQueue<void>(
      functionName: 'dtsRejectTransfer',
      payload: {
        'docId': docId,
        'actorUid': actorUid,
        'reason': reason,
        'attachments': attachments,
      },
      queueActionName: 'dtsRejectTransfer',
      maxAttempts: 2,
    );
  }

  Future<void> confirmReceipt({
    required String docId,
    required String toOfficeId,
    required String toOfficeName,
    required String receiverUid,
  }) async {
    await _callCallableOrQueue<void>(
      functionName: 'dtsConfirmReceipt',
      payload: {
        'docId': docId,
        'toOfficeId': toOfficeId,
        'toOfficeName': toOfficeName,
        'receiverUid': receiverUid,
      },
      queueActionName: 'dtsConfirmReceipt',
      maxAttempts: 2,
    );
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
    required String actorUid,
    String? actorName,
  }) async {
    await _callCallableOrQueue<void>(
      functionName: 'dtsUpdateStatus',
      payload: {
        'docId': docId,
        'status': DtsStatusHelper.normalize(status),
        'actorUid': actorUid,
        'actorName': actorName,
      },
      queueActionName: 'dtsUpdateStatus',
      maxAttempts: 2,
    );
  }

  Future<void> addNote({
    required String docId,
    required String actorUid,
    required String notes,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _callCallableOrQueue<void>(
      functionName: 'dtsAddNote',
      payload: {
        'docId': docId,
        'actorUid': actorUid,
        'notes': notes,
        'attachments': attachments,
      },
      queueActionName: 'dtsAddNote',
      maxAttempts: 2,
    );
  }

  Future<DtsTrackingResult> trackByTrackingNo({
    required String trackingNo,
    required String pin,
  }) async {
    final data = await _callWithRetry<Map<String, dynamic>>(
      'dtsTrackByTrackingNo',
      {'trackingNo': trackingNo, 'pin': pin},
    );
    return DtsTrackingResult.fromMap(data);
  }

  Future<DtsTrackingResult> trackByQrAndPin({
    required String qrCode,
    required String pin,
  }) async {
    final data = await _callWithRetry<Map<String, dynamic>>(
      'dtsTrackByQrAndPin',
      {'qrCode': qrCode, 'pin': pin},
    );
    return DtsTrackingResult.fromMap(data);
  }

  Future<DtsTrackingResult> trackBySessionToken({
    required String sessionToken,
  }) async {
    final data = await _callWithRetry<Map<String, dynamic>>('dtsTrackByToken', {
      'sessionToken': sessionToken,
    });
    return DtsTrackingResult.fromMap(data);
  }

  Future<void> saveTrackedDocumentToAccount({
    required String trackingNo,
    String? pin,
    String? sessionToken,
  }) async {
    if ((pin == null || pin.trim().isEmpty) &&
        (sessionToken == null || sessionToken.trim().isEmpty)) {
      throw ArgumentError('Either pin or sessionToken is required.');
    }
    await _callWithRetry<void>('dtsSaveTrackedDocument', {
      'trackingNo': trackingNo,
      if (pin != null && pin.trim().isNotEmpty) 'pin': pin,
      if (sessionToken != null && sessionToken.trim().isNotEmpty)
        'sessionToken': sessionToken,
    }, maxAttempts: 2);
  }

  Future<void> unsaveTrackedDocumentFromAccount({required String docId}) async {
    await _callWithRetry<void>('dtsUnsaveTrackedDocument', {
      'docId': docId,
    }, maxAttempts: 2);
  }

  Future<void> auditAttachmentAccess({
    required String docId,
    required String eventId,
    required String attachmentName,
    required String action,
    String? attachmentPath,
    String? attachmentUrl,
  }) async {
    await _callWithRetry<void>('dtsAuditAttachmentAccess', {
      'docId': docId,
      'eventId': eventId,
      'attachmentName': attachmentName,
      'attachmentPath': attachmentPath,
      'attachmentUrl': attachmentUrl,
      'action': action,
    }, maxAttempts: 2);
  }

  Future<List<String>> generateQrCodes({
    int count = 10,
    String prefix = 'DTS-QR',
  }) async {
    final data = await _callWithRetry<Map<String, dynamic>>(
      'generateDtsQrCodes',
      {'count': count, 'prefix': prefix},
      maxAttempts: 2,
    );
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
    final data = await _callWithRetry<Map<String, dynamic>>('exportDtsQrZip', {
      'codes': codes,
    }, maxAttempts: 2);
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

  String _generatePinSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(8, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> flushOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _decodeActionQueue(prefs.getString(_offlineQueueKey));
    if (pending.isEmpty) return;

    final stillPending = <Map<String, dynamic>>[];
    final conflicts = _decodeActionQueue(prefs.getString(_offlineConflictKey));

    for (final action in pending) {
      final functionName = (action['functionName'] ?? '').toString().trim();
      if (functionName.isEmpty) {
        continue;
      }
      final payload = _restoreFromQueue(
        action['payload'] as Map<String, dynamic>? ?? {},
      );
      try {
        await _callWithRetry<void>(functionName, payload, maxAttempts: 1);
      } on FirebaseFunctionsException catch (e, stack) {
        if (_isTransientOfflineError(e)) {
          stillPending.add(action);
          continue;
        }
        if (_isPermanentConflictError(e)) {
          conflicts.add({
            'action': (action['action'] ?? functionName).toString(),
            'reason': e.message ?? e.code,
            'queuedAtEpochMs': action['queuedAtEpochMs'] ?? 0,
            'resolvedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
            'docId': ((payload['docId'] ?? '')).toString(),
          });
          await ObservabilityService.recordError(
            e,
            stack,
            reason: 'dts_offline_conflict',
            context: {
              'function': functionName,
              'code': e.code,
              'docId': (payload['docId'] ?? '').toString(),
            },
          );
          continue;
        }
        stillPending.add(action);
      } catch (_) {
        stillPending.add(action);
      }
    }

    await prefs.setString(_offlineQueueKey, jsonEncode(stillPending));
    await prefs.setString(_offlineConflictKey, jsonEncode(conflicts));
  }

  Future<List<DtsOfflineConflict>> getOfflineConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    final decoded = _decodeActionQueue(prefs.getString(_offlineConflictKey));
    return decoded.map(DtsOfflineConflict.fromMap).toList()
      ..sort((a, b) => b.resolvedAtEpochMs.compareTo(a.resolvedAtEpochMs));
  }

  Future<void> clearOfflineConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineConflictKey);
  }

  Future<DtsOpsHealthResult> fetchOpsHealth() async {
    final healthRaw = await _callWithRetry<Map<String, dynamic>>(
      'opsRuntimeHealth',
      {'expectedBuild': _opsExpectedBackendBuild},
      maxAttempts: 2,
    );
    final requiredCallables = <String>[
      ...(healthRaw['requiredCallables'] is List
          ? (healthRaw['requiredCallables'] as List)
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
          : const <String>[]),
    ];
    final callableChecks = <String, bool>{};
    for (final callableName in requiredCallables) {
      callableChecks[callableName] = await _isCallableReachable(callableName);
    }
    return DtsOpsHealthResult(
      backendBuild: (healthRaw['functionsBuild'] ?? '').toString(),
      runtimeNode: (healthRaw['runtimeNode'] ?? '').toString(),
      nowIso: (healthRaw['nowIso'] ?? '').toString(),
      driftDetected: healthRaw['driftDetected'] == true,
      callableChecks: callableChecks,
    );
  }

  Future<bool> _isCallableReachable(String functionName) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      await callable.call({'__healthCheck': true});
      return true;
    } on FirebaseFunctionsException catch (e) {
      return e.code != 'not-found';
    } catch (_) {
      return false;
    }
  }

  Future<void> _callCallableOrQueue<T>({
    required String functionName,
    required String queueActionName,
    required Map<String, dynamic> payload,
    int maxAttempts = 2,
  }) async {
    try {
      await _callWithRetry<T>(functionName, payload, maxAttempts: maxAttempts);
    } on FirebaseFunctionsException catch (e) {
      if (!_isTransientOfflineError(e)) rethrow;
      await _enqueueOfflineAction(
        functionName: functionName,
        action: queueActionName,
        payload: payload,
      );
      throw const DtsQueuedActionException(
        'No network or backend unavailable. Action queued and will sync automatically.',
      );
    } on SocketException {
      await _enqueueOfflineAction(
        functionName: functionName,
        action: queueActionName,
        payload: payload,
      );
      throw const DtsQueuedActionException(
        'No network. Action queued and will sync automatically.',
      );
    }
  }

  Future<void> _enqueueOfflineAction({
    required String functionName,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeActionQueue(prefs.getString(_offlineQueueKey));
    queue.add({
      'id': '${DateTime.now().microsecondsSinceEpoch}_$action',
      'functionName': functionName,
      'action': action,
      'queuedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'payload': _sanitizeForQueue(payload),
    });
    await prefs.setString(_offlineQueueKey, jsonEncode(queue));
  }

  List<Map<String, dynamic>> _decodeActionQueue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _sanitizeForQueue(Map<String, dynamic> source) {
    final output = <String, dynamic>{};
    source.forEach((key, value) {
      output[key] = _serializeQueueValue(value);
    });
    return output;
  }

  dynamic _serializeQueueValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestampMs': value.millisecondsSinceEpoch};
    }
    if (value is DateTime) {
      return {'__timestampMs': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, nested) {
        map[key.toString()] = _serializeQueueValue(nested);
      });
      return map;
    }
    if (value is List) {
      return value.map(_serializeQueueValue).toList();
    }
    return value;
  }

  Map<String, dynamic> _restoreFromQueue(Map<String, dynamic> source) {
    final restored = <String, dynamic>{};
    source.forEach((key, value) {
      restored[key] = _restoreQueueValue(value);
    });
    return restored;
  }

  dynamic _restoreQueueValue(dynamic value) {
    if (value is Map) {
      final asMap = Map<String, dynamic>.from(value);
      if (asMap.length == 1 && asMap.containsKey('__timestampMs')) {
        final raw = asMap['__timestampMs'];
        final millis = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        if (millis != null) return millis;
      }
      final restored = <String, dynamic>{};
      asMap.forEach((k, v) => restored[k] = _restoreQueueValue(v));
      return restored;
    }
    if (value is List) {
      return value.map(_restoreQueueValue).toList();
    }
    return value;
  }

  bool _isTransientOfflineError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
      case 'aborted':
        return true;
      default:
        return false;
    }
  }

  bool _isPermanentConflictError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'failed-precondition':
      case 'not-found':
      case 'invalid-argument':
        return true;
      default:
        return false;
    }
  }

  bool _isRetryableFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
      case 'aborted':
        return true;
      default:
        return false;
    }
  }

  Future<T> _callWithRetry<T>(
    String functionName,
    Map<String, dynamic> payload, {
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    FirebaseFunctionsException? lastFunctionsError;
    Object? lastError;

    while (attempt < maxAttempts) {
      attempt += 1;
      try {
        final callable = _functions.httpsCallable(functionName);
        final result = await callable.call(payload);
        if (result.data == null) {
          return null as T;
        }
        if (result.data is Map) {
          return Map<String, dynamic>.from(result.data as Map) as T;
        }
        return result.data as T;
      } on FirebaseFunctionsException catch (e) {
        lastFunctionsError = e;
        await ObservabilityService.recordError(
          e,
          StackTrace.current,
          reason: 'dts_callable_error',
          context: {
            'function': functionName,
            'code': e.code,
            'attempt': attempt,
          },
        );
        if (!_isRetryableFunctionsError(e) || attempt >= maxAttempts) {
          rethrow;
        }
      } catch (e) {
        lastError = e;
        await ObservabilityService.recordError(
          e,
          StackTrace.current,
          reason: 'dts_callable_unknown_error',
          context: {'function': functionName, 'attempt': attempt},
        );
        if (attempt >= maxAttempts) rethrow;
      }

      final waitMs = 200 * (1 << (attempt - 1));
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }

    if (lastFunctionsError != null) throw lastFunctionsError;
    if (lastError != null) throw lastError;
    throw Exception('Callable $functionName failed.');
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
