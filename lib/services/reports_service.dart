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
  }) async {
    final doc = _db.collection('reports').doc();

    await doc.set({
      'title': title.trim(),
      'description': description.trim(),
      'status': 'submitted',
      'createdByUid': _uid,
      'createdByEmail': _email,
      'assignedToUid': null,
      'assignedToEmail': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
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
