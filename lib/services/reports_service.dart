import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsService {
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Not logged in');
    return u.uid;
  }

  String? get _email => FirebaseAuth.instance.currentUser?.email;

  /// Resident creates a report
  Future<String> createReport({
    required String title,
    required String description,
    String? officeId,
    String? officeName,
  }) async {
    final doc = _db.collection('reports').doc();
    final resolvedOffice = await _resolveOffice(
      officeId: officeId,
      officeName: officeName,
    );

    await doc.set({
      'title': title.trim(),
      'description': description.trim(),
      'status': 'submitted',
      'officeId': resolvedOffice.$1,
      'officeName': resolvedOffice.$2,
      'createdByUid': _uid,
      'createdByEmail': _email,
      'assignedToUid': null,
      'assignedToEmail': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<(String, String)> _resolveOffice({
    String? officeId,
    String? officeName,
  }) async {
    final trimmedId = officeId?.trim() ?? '';
    final trimmedName = officeName?.trim() ?? '';
    if (trimmedId.isNotEmpty && trimmedName.isNotEmpty) {
      return (trimmedId, trimmedName);
    }

    Query<Map<String, dynamic>> query = _db
        .collection('offices')
        .orderBy('name')
        .limit(1);
    final active = await _db
        .collection('offices')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .limit(1)
        .get();
    if (active.docs.isNotEmpty) {
      final data = active.docs.first.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return (active.docs.first.id, name);
      }
    }
    final fallback = await query.get();
    if (fallback.docs.isNotEmpty) {
      final data = fallback.docs.first.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return (fallback.docs.first.id, name);
      }
    }
    throw Exception('No office configured. Ask admin to add offices.');
  }

  /// Resident “My Reports” (only theirs)
  Stream<QuerySnapshot<Map<String, dynamic>>> myReportsStream({int limit = 50}) {
    return _db
        .collection('reports')
        .where('createdByUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Moderator/Admin “Inbox” (all reports)
  Stream<QuerySnapshot<Map<String, dynamic>>> allReportsStream({int limit = 100}) {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Admin/super_admin assigns a report to moderatorUid
  Future<void> assignReport({
    required String reportId,
    required String moderatorUid,
  }) async {
    // You already have a callable for assignment in your smoke screen flow.
    // If your current app uses Firestore direct update, keep it consistent with your rules.
    // Here is direct Firestore update (will be blocked unless rules allow admin+).
    final moderatorDoc = await _db.collection('users').doc(moderatorUid).get();
    final moderatorEmail = moderatorDoc.data()?['email'];

    await _db.collection('reports').doc(reportId).set({
      'assignedToUid': moderatorUid,
      'assignedToEmail': moderatorEmail,
      'status': 'assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Assigned moderator OR admin+ can update status
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    await _db.collection('reports').doc(reportId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
